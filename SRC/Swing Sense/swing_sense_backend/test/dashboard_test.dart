// Testes das rotas GET /dashboard/me e /dashboard/leaderboard (banco simulado).
//   dart test test/dashboard_test.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/src/app.dart';
import '../lib/src/db/postgres_store.dart';
import '../lib/src/utils/jwt_util.dart';
import '../lib/src/utils/security_config.dart';

const secret = 'k3Y-9fQ2xLr7TnVb0aWm5ZpHs8DuJc1EoGiXy4BtNq6A';
const userId = '11111111-1111-4111-8111-111111111111';
const amigoId = '22222222-2222-4222-8222-222222222222';

class FakeStore implements PgStore {
  final calls = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> getDashboardTotals(String userId, DateTime from, DateTime to, {String? tipo}) async {
    calls.add({'fn': 'totals', 'from': from, 'to': to, 'tipo': tipo});
    return {
      'tacadas': 10, 'forehand': 6, 'backhand': 3, 'saque': 1, 'incertas': 2,
      'vel_media': 31.5, 'vel_max': 48, 'sessoes': 2, 'dias_ativos': 2, 'tempo_segundos': 3600,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getDashboardDaily(String userId, DateTime from, DateTime to, {String? tipo}) async => [
        // 2026-10-26 e segunda-feira; 2026-10-28 e quarta-feira.
        {'dia': '2026-10-26', 'tacadas': 4, 'vel_media': 30.0},
        {'dia': '2026-10-28', 'tacadas': 6, 'vel_media': 32.5},
      ];

  @override
  Future<List<Map<String, dynamic>>> getDashboardSessions(String userId, DateTime from, DateTime to,
          {String? tipo, int limit = 20}) async =>
      [
        {'id': 's1', 'title': 'Rally', 'started_at': DateTime.utc(2026, 10, 28, 15), 'tacadas': 6,
         'forehand': 4, 'backhand': 2, 'saque': 0, 'vel_media': 32.5, 'vel_max': 48},
      ];

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard(String me, DateTime from, DateTime to, {DateTime? prevFrom}) async {
    calls.add({'fn': 'leaderboard', 'from': from, 'to': to, 'prevFrom': prevFrom});
    return [
      {'id': userId, 'name': 'Eu', 'avatar_url': null, 'level': 'iniciante', 'tacadas': 10, 'dias_ativos': 2,
       'vel_media': 33.0, 'vel_media_anterior': 30.0, 'tempo_segundos': 3600},
      {'id': amigoId, 'name': 'Amigo', 'avatar_url': null, 'level': 'avancado', 'tacadas': 0, 'dias_ativos': 0,
       'vel_media': null, 'vel_media_anterior': null, 'tempo_segundos': 0},
    ];
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late Handler app;
  late FakeStore db;
  late String token;

  Future<Response> get(String path, {bool auth = true}) => Future.value(app(Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: auth ? {'authorization': 'Bearer $token'} : {},
      )));

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  setUp(() {
    db = FakeStore();
    app = buildHandler(
      db,
      config: SecurityConfig(
        isProduction: false, jwtSecret: secret, jwtExpiresInHours: 24,
        allowedOrigins: const {}, trustProxy: false, maxBodyBytes: 256 * 1024,
      ),
    );
    token = JwtUtil(secret: secret, expiresInHours: 24).generate(userId: userId, email: 'a@x.com', role: 'player');
  });

  group('GET /dashboard/me', () {
    test('exige autenticacao', () async {
      expect((await get('/dashboard/me', auth: false)).statusCode, 401);
    });

    test('devolve kpis, anterior, golpes, confianca, dias e sessoes', () async {
      final r = await get('/dashboard/me?range=7d');
      expect(r.statusCode, 200);
      final d = await json(r);
      expect(d['kpis'], containsPair('tacadas', 10));
      expect(d['kpis'], containsPair('velMax', 48));
      expect(d['previous'], isNotNull);
      expect(d['porTipo'], {'FH': 6, 'BH': 3, 'SQ': 1});
      expect(d['confianca'], {'certas': 8, 'incertas': 2});
      expect((d['porDia'] as List).length, 2);
      expect((d['sessoes'] as List).first['title'], 'Rally');
      // segunda = indice 0, quarta = indice 2.
      expect(d['porDiaSemana'], [4, 0, 6, 0, 0, 0, 0]);
      expect(d['period']['range'], '7d');
      expect(d['period']['days'], 7);
    });

    test('periodo padrao e 30 dias e o anterior tem a mesma duracao', () async {
      final d = await json(await get('/dashboard/me'));
      expect(d['period']['days'], 30);
      final atual = db.calls.firstWhere((c) => c['fn'] == 'totals');
      final anterior = db.calls.where((c) => c['fn'] == 'totals').last;
      expect(anterior['to'], atual['from']);
      expect((anterior['to'] as DateTime).difference(anterior['from'] as DateTime).inDays, 30);
    });

    test('"all" nao tem periodo anterior', () async {
      final d = await json(await get('/dashboard/me?range=all'));
      expect(d['previous'], isNull);
      expect(db.calls.where((c) => c['fn'] == 'totals').length, 1);
    });

    test('periodo personalizado: from/to inclusivos, meia-noite de Brasilia', () async {
      final d = await json(await get('/dashboard/me?from=2026-10-01&to=2026-10-07'));
      expect(d['period']['days'], 7);
      expect(d['period']['range'], 'custom');
      final c = db.calls.firstWhere((c) => c['fn'] == 'totals');
      expect(c['from'], DateTime.utc(2026, 10, 1, 3));
      expect(c['to'], DateTime.utc(2026, 10, 8, 3));
    });

    test('filtro de golpe e repassado; valor desconhecido vira "todos"', () async {
      await get('/dashboard/me?tipo=BH');
      expect(db.calls.first['tipo'], 'BH');
      db.calls.clear();
      await get('/dashboard/me?tipo=xx');
      expect(db.calls.first['tipo'], isNull);
    });

    for (final query in [
      'range=1y',
      'from=2026-10-01',
      'from=abc&to=2026-10-02',
      'from=2026-02-31&to=2026-03-02',
      'from=2026-10-10&to=2026-10-01',
      'from=2024-01-01&to=2026-01-01',
    ]) {
      test('rejeita periodo invalido ($query)', () async {
        expect((await get('/dashboard/me?$query')).statusCode, 400);
      });
    }
  });

  group('GET /dashboard/leaderboard', () {
    test('exige autenticacao', () async {
      expect((await get('/dashboard/leaderboard', auth: false)).statusCode, 401);
    });

    test('marca o proprio usuario e calcula a evolucao da velocidade', () async {
      final d = await json(await get('/dashboard/leaderboard?range=30d'));
      final entries = (d['entries'] as List).cast<Map<String, dynamic>>();
      final eu = entries.firstWhere((e) => e['isMe'] == true);
      expect(eu['userId'], userId);
      expect(eu['evolucaoPct'], 10.0); // 30 -> 33
      final amigo = entries.firstWhere((e) => e['isMe'] == false);
      expect(amigo['evolucaoPct'], isNull);
      expect(amigo['velMedia'], isNull);
    });

    test('periodo invalido vira 400', () async {
      expect((await get('/dashboard/leaderboard?range=zzz')).statusCode, 400);
    });
  });
}
