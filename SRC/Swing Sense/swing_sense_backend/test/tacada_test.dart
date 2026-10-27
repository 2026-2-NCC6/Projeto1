// Testes da rota POST /tacadas (raquete real via BLE).
//   dart test test/tacada_test.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/src/app.dart';
import '../lib/src/db/postgres_store.dart';
import '../lib/src/utils/jwt_util.dart';
import '../lib/src/utils/security_config.dart';

const secret = 'k3Y-9fQ2xLr7TnVb0aWm5ZpHs8DuJc1EoGiXy4BtNq6A';
const userId = '11111111-1111-4111-8111-111111111111';
const otherUserId = '22222222-2222-4222-8222-222222222222';
const sessionId = '33333333-3333-4333-8333-333333333333';

class FakeStore implements PgStore {
  FakeStore({this.implemented = true});
  final bool implemented;
  final saved = <Map<String, Object?>>[];
  final keys = <String>{};

  @override
  Future<Map<String, dynamic>?> getSessionById(String id) async =>
      id == sessionId ? {'id': sessionId, 'user_id': userId} : null;

  @override
  Future<int> insertTacadas(String userId, List<Map<String, Object?>> rows) async {
    if (!implemented) throw UnimplementedError('insertTacadas');
    var inserted = 0;
    for (final r in rows) {
      // Mesma regra do banco: UNIQUE (dispositivo_id, boot, seq).
      if (keys.add('${r['dispositivoId']}|${r['boot']}|${r['seq']}')) {
        saved.add({'userId': userId, ...r});
        inserted++;
      }
    }
    return inserted;
  }

  Map<String, Object?>? lastList;
  Map<String, Object?>? lastStats;

  @override
  Future<List<Map<String, dynamic>>> getTacadas(String userId, {String? sessionId, int limit = 100, int offset = 0}) async {
    lastList = {'userId': userId, 'sessionId': sessionId, 'limit': limit, 'offset': offset};
    return [
      {'id': 1, 'session_id': sessionId, 'dispositivo_id': 'SwingSense-A1B2', 'boot': 7, 'seq': 1, 't_ms': 1500,
       'recebido_em': DateTime.utc(2026, 10, 20), 'tipo': 'FH', 'incerto': false, 'bola': null,
       'acel': 30.4, 'giro': 11.9, 'vel': 26, 'accx': 3.0, 'versao_formato': 1},
    ];
  }

  @override
  Future<Map<String, dynamic>?> getTacadaStatsForSession(String sessionId, String userId) async {
    lastStats = {'userId': userId, 'sessionId': sessionId};
    return userId == otherUserId ? null : {'total': 3, 'forehand': 2, 'backhand': 1, 'saque': 0, 'incertas': 1,
      'pct_incertas': '33.3', 'vel_raquete_max': 35};
  }

  @override
  Future<Map<String, dynamic>?> getTacadaStatsForUser(String userId) async =>
      userId == otherUserId ? null : {'total': 3, 'sessoes': 1, 'forehand': 2, 'backhand': 1};

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Map<String, dynamic> tacada({int seq = 37, Object? bola, String tipo = 'FH', Map<String, dynamic>? extra}) => {
      'dispositivoId': 'SwingSense-A1B2',
      'boot': 2891734012,
      'seq': seq,
      't': 152340,
      'recebidoEm': DateTime.now().toUtc().toIso8601String(),
      'tipo': tipo,
      'incerto': false,
      'bola': bola,
      'acel': 80.4,
      'giro': 26.3,
      'vel': 95,
      'accx': 3.2,
      'v': 1,
      ...?extra,
    };

void main() {
  late Handler app;
  late FakeStore db;
  late String token;

  Future<Response> post(Object body, {String? as}) => Future.value(app(Request(
        'POST',
        Uri.parse('http://localhost/tacadas'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer ${as ?? token}'},
        body: jsonEncode(body),
      )));

  void boot({bool implemented = true}) {
    db = FakeStore(implemented: implemented);
    final config = SecurityConfig(
      isProduction: false, jwtSecret: secret, jwtExpiresInHours: 24,
      allowedOrigins: const {}, trustProxy: false, maxBodyBytes: 256 * 1024,
    );
    app = buildHandler(db, config: config);
    token = JwtUtil(secret: secret, expiresInHours: 24).generate(userId: userId, email: 'a@x.com', role: 'player');
  }

  setUp(boot);

  test('exige autenticacao', () async {
    final r = await app(Request('POST', Uri.parse('http://localhost/tacadas'), body: '{}'));
    expect(r.statusCode, 401);
  });

  test('lote valido (incluindo boot uint32 e bola nula) e gravado com o usuario do token', () async {
    final r = await post({'tacadas': [tacada(), tacada(seq: 38, tipo: 'BH', bola: true)]});
    expect(r.statusCode, 201);
    expect(jsonDecode(await r.readAsString()), {'received': 2, 'inserted': 2});
    expect(db.saved, hasLength(2));
    expect(db.saved.first['userId'], userId);
    expect(db.saved.first['boot'], 2891734012);
    expect(db.saved.first['bola'], isNull);
    expect(db.saved.last['bola'], isTrue);
    expect(db.saved.first['recebidoEm'], isA<DateTime>());
  });

  test('reenvio e idempotente: a mesma tacada nao duplica', () async {
    await post({'tacadas': [tacada()]});
    final again = await post({'tacadas': [tacada()]});
    expect(jsonDecode(await again.readAsString()), {'received': 1, 'inserted': 0});
    expect(db.saved, hasLength(1));
  });

  test('campo desconhecido e ignorado; usuario no corpo nao vale', () async {
    final r = await post({
      'tacadas': [tacada(extra: {'novo': 1, 'userId': otherUserId, 'user_id': otherUserId})]
    });
    expect(r.statusCode, 201);
    expect(db.saved.single['userId'], userId);
    expect(db.saved.single.containsKey('novo'), isFalse);
  });

  test('sessao de outro usuario ou inexistente => 404; propria => ok', () async {
    expect((await post({'tacadas': [tacada(extra: {'sessionId': sessionId})]})).statusCode, 201);
    final other = JwtUtil(secret: secret, expiresInHours: 24)
        .generate(userId: otherUserId, email: 'b@x.com', role: 'player');
    expect((await post({'tacadas': [tacada(seq: 99, extra: {'sessionId': sessionId})]}, as: other)).statusCode, 404);
    expect((await post({'tacadas': [tacada(extra: {'sessionId': '44444444-4444-4444-8444-444444444444'})]})).statusCode, 404);
  });

  test('dados invalidos => 400 e nada e gravado', () async {
    final ruins = <Map<String, dynamic>>[
      tacada(tipo: 'XX'),
      tacada(extra: {'boot': 4294967296}),
      tacada(extra: {'boot': -1}),
      tacada(extra: {'vel': 99999}),
      tacada(extra: {'acel': 'alto'}),
      tacada(extra: {'incerto': 'nao'}),
      tacada(extra: {'bola': 'talvez'}),
      tacada(extra: {'recebidoEm': 'ontem'}),
      tacada(extra: {'recebidoEm': '1999-01-01T00:00:00Z'}),
      tacada(extra: {'dispositivoId': "x'; DROP TABLE tacadas;--"}),
      tacada(extra: {'sessionId': 'nao-uuid'}),
    ];
    for (final bad in ruins) {
      expect((await post({'tacadas': [bad]})).statusCode, 400, reason: jsonEncode(bad));
    }
    expect((await post({'tacadas': []})).statusCode, 400);
    expect((await post({'outra': 1})).statusCode, 400);
    expect(db.saved, isEmpty);
  });

  test('lote acima de 500 => 413', () async {
    final r = await post({'tacadas': List.generate(501, (i) => tacada(seq: i))});
    expect(r.statusCode, 413);
  });

  test('banco ainda nao implementado => 501 (o app mantem a fila)', () async {
    boot(implemented: false);
    final r = await post({'tacadas': [tacada()]});
    expect(r.statusCode, 501);
    expect(await r.readAsString(), contains('ainda nao implementada'));
  });

  test('saque (SQ) e aceito', () async {
    final r = await post({'tacadas': [tacada(tipo: 'SQ')]});
    expect(r.statusCode, 201);
    expect(db.saved.single['tipo'], 'SQ');
  });

  group('leitura', () {
    Future<Response> get(String path, {String? as, bool auth = true}) => Future.value(app(Request(
          'GET',
          Uri.parse('http://localhost$path'),
          headers: auth ? {'authorization': 'Bearer ${as ?? token}'} : {},
        )));

    test('exige autenticacao', () async {
      expect((await get('/tacadas', auth: false)).statusCode, 401);
      expect((await get('/tacadas/summary', auth: false)).statusCode, 401);
    });

    test('lista so as tacadas do usuario do token, com paginacao', () async {
      final r = await get('/tacadas?sessionId=$sessionId&limit=10&offset=5');
      expect(r.statusCode, 200);
      expect(db.lastList, {'userId': userId, 'sessionId': sessionId, 'limit': 10, 'offset': 5});
      final body = jsonDecode(await r.readAsString()) as List;
      expect(body.single['tipo'], 'FH');
      expect(body.single['t'], 1500);
    });

    test('parametros invalidos => 400', () async {
      for (final path in ['/tacadas?sessionId=x', '/tacadas?limit=0', '/tacadas?limit=501', '/tacadas?offset=-1', '/tacadas/summary?sessionId=x']) {
        expect((await get(path)).statusCode, 400, reason: path);
      }
    });

    test('resumo da sessao e do usuario; sem dados devolve zeros', () async {
      final s = jsonDecode(await (await get('/tacadas/summary?sessionId=$sessionId')).readAsString()) as Map;
      expect(s['forehand'], 2);
      expect(s['velRaqueteMax'], 35.0);
      expect(db.lastStats, {'userId': userId, 'sessionId': sessionId});
      final u = jsonDecode(await (await get('/tacadas/summary')).readAsString()) as Map;
      expect(u['total'], 3);
      final other = JwtUtil(secret: secret, expiresInHours: 24).generate(userId: otherUserId, email: 'b@x.com', role: 'player');
      final z = jsonDecode(await (await get('/tacadas/summary', as: other)).readAsString()) as Map;
      expect(z['total'], 0);
      expect(z['velRaqueteMax'], isNull);
    });
  });
}
