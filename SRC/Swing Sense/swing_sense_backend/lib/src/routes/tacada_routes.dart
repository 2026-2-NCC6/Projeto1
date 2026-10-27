import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

/// Tacadas da raquete real (BLE). Contrato do corpo em `INTEGRACAO_APP_BLE.md`.
///
/// `POST /tacadas` recebe um LOTE: `{"tacadas": [ {...}, {...} ]}`. O usuario
/// vem do token (nunca do corpo). A rota valida tudo e entrega as linhas ja
/// saneadas para `PgStore.insertTacadas`, que deve gravar de forma
/// idempotente (`ON CONFLICT (dispositivo_id, boot, seq) DO NOTHING`).
///
/// Enquanto `insertTacadas` nao estiver implementado, a rota responde 501 e o
/// app mantem as tacadas na fila local (nada se perde).
Router tacadaRoutes(PgStore db) {
  final router = Router();

  const maxPerRequest = 500;
  final deviceIdPattern = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
  const maxUint32 = 4294967295;

  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final list = body['tacadas'];
    if (list is! List || list.isEmpty) {
      return ApiResponse.error('Envie uma lista "tacadas" com pelo menos um item');
    }
    if (list.length > maxPerRequest) {
      return ApiResponse.error('Maximo de $maxPerRequest tacadas por requisicao', status: 413);
    }

    final now = DateTime.now().toUtc();
    final rows = <Map<String, Object?>>[];
    final sessionOwnerChecked = <String>{};

    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map<String, dynamic>) return ApiResponse.error('Tacada $i invalida');
      String bad(String msg) => '$msg (tacada $i)';

      final dispositivoId = item['dispositivoId'];
      if (dispositivoId is! String || !deviceIdPattern.hasMatch(dispositivoId)) {
        return ApiResponse.error(bad('dispositivoId invalido'));
      }
      final boot = item['boot'];
      if (boot is! int || boot < 0 || boot > maxUint32) return ApiResponse.error(bad('boot invalido'));
      final seq = item['seq'];
      if (seq is! int || seq < 0 || seq > 2147483647) return ApiResponse.error(bad('seq invalido'));
      final t = item['t'];
      if (t is! int || t < 0 || t > 9007199254740991) return ApiResponse.error(bad('t invalido'));

      final recebidoEmRaw = item['recebidoEm'];
      final recebidoEm = recebidoEmRaw is String ? DateTime.tryParse(recebidoEmRaw) : null;
      if (recebidoEm == null ||
          recebidoEm.isBefore(DateTime.utc(2020)) ||
          recebidoEm.isAfter(now.add(const Duration(days: 1)))) {
        return ApiResponse.error(bad('recebidoEm invalido'));
      }

      final tipo = item['tipo'];
      if (tipo != 'FH' && tipo != 'BH' && tipo != 'SQ') return ApiResponse.error(bad('tipo deve ser FH, BH ou SQ'));
      final incerto = item['incerto'];
      if (incerto is! bool) return ApiResponse.error(bad('incerto deve ser booleano'));
      final bola = item['bola'];
      if (bola != null && bola is! bool) return ApiResponse.error(bad('bola deve ser booleano ou null'));

      final numberError = [
        item['acel'] is num ? validateNumber(item['acel'], 'acel', min: 0, max: 2000) : 'acel invalido',
        item['giro'] is num ? validateNumber(item['giro'], 'giro', min: 0, max: 1000) : 'giro invalido',
        item['vel'] is num ? validateNumber(item['vel'], 'vel', min: 0, max: 400, integer: true) : 'vel invalido',
        item['accx'] is num ? validateNumber(item['accx'], 'accx', min: -2000, max: 2000) : 'accx invalido',
        item['v'] is num ? validateNumber(item['v'], 'v', min: 1, max: 99, integer: true) : 'v invalido',
      ].firstWhere((e) => e != null, orElse: () => null);
      if (numberError != null) return ApiResponse.error(bad(numberError));

      // Sessao opcional: precisa ser do proprio usuario.
      final sessionId = item['sessionId'];
      if (sessionId != null) {
        if (sessionId is! String || !isUuid(sessionId)) return ApiResponse.error(bad('sessionId invalido'));
        if (sessionOwnerChecked.add(sessionId)) {
          final session = await db.getSessionById(sessionId);
          if (session == null || session['user_id'] != request.userId) {
            return ApiResponse.notFound('Sessao nao encontrada');
          }
        }
      }

      // Campos desconhecidos sao ignorados (versoes futuras do firmware).
      rows.add({
        'sessionId': sessionId,
        'dispositivoId': dispositivoId,
        'boot': boot,
        'seq': seq,
        'tMs': t,
        'recebidoEm': recebidoEm.toUtc(),
        'tipo': tipo,
        'incerto': incerto,
        'bola': bola,
        'acel': (item['acel'] as num).toDouble(),
        'giro': (item['giro'] as num).toDouble(),
        'vel': (item['vel'] as num).toInt(),
        'accx': (item['accx'] as num).toDouble(),
        'versaoFormato': (item['v'] as num).toInt(),
      });
    }

    try {
      final inserted = await db.insertTacadas(request.userId, rows);
      return ApiResponse.created({'received': rows.length, 'inserted': inserted});
    } on UnimplementedError {
      return ApiResponse.error('Persistencia de tacadas ainda nao implementada', status: 501);
    }
  });

  // GET /tacadas?sessionId=&limit=&offset= - tacadas do proprio usuario, da mais
  // antiga para a mais nova (padrao 100, maximo 500 por pagina).
  router.get('/', (Request request) async {
    final params = request.url.queryParameters;

    final sessionId = params['sessionId'];
    if (sessionId != null && !isUuid(sessionId)) return ApiResponse.error('sessionId invalido');

    final limit = int.tryParse(params['limit'] ?? '') ?? 100;
    final offset = int.tryParse(params['offset'] ?? '') ?? 0;
    if (limit < 1 || limit > maxPerRequest) return ApiResponse.error('limit deve ficar entre 1 e $maxPerRequest');
    if (offset < 0) return ApiResponse.error('offset invalido');

    final rows = await db.getTacadas(request.userId, sessionId: sessionId, limit: limit, offset: offset);
    return ApiResponse.ok(rows.map(tacadaToJson).toList());
  });

  // GET /tacadas/summary[?sessionId=] - estatisticas (FH/BH/SQ, incertas, medias e
  // picos). Com sessionId, so daquela sessao; sem ele, de todas as tacadas do usuario.
  router.get('/summary', (Request request) async {
    final sessionId = request.url.queryParameters['sessionId'];
    if (sessionId != null && !isUuid(sessionId)) return ApiResponse.error('sessionId invalido');

    final row = sessionId == null
        ? await db.getTacadaStatsForUser(request.userId)
        : await db.getTacadaStatsForSession(sessionId, request.userId);
    return ApiResponse.ok(row == null ? tacadaStatsToJson(const {}) : tacadaStatsToJson(row));
  });

  return router;
}
