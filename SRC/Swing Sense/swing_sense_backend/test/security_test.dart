// Testes de seguranca (Entrega 2 - Redes de Computadores e Ciberseguranca).
// Cada grupo reproduz o ataque do relatorio da Entrega 1 e comprova que a
// correcao o bloqueia. Rodam sem Postgres, usando um banco em memoria.
//
//   dart test test/security_test.dart
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/src/app.dart';
import '../lib/src/db/postgres_store.dart';
import '../lib/src/routes/auth_routes.dart';
import '../lib/src/utils/password_util.dart';
import '../lib/src/utils/rate_limiter.dart';
import '../lib/src/utils/security_config.dart';
import '../lib/src/utils/validators.dart';

/// Banco em memoria com apenas o que os testes exercitam.
class FakeStore implements PgStore {
  final users = <String, Map<String, dynamic>>{};
  final sessions = <String, Map<String, dynamic>>{};
  final events = <Map<String, dynamic>>[];
  final comments = <Map<String, dynamic>>[];
  final likes = <String>{};
  final follows = <String>{};

  @override
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    for (final u in users.values) {
      if (u['email'] == email) return u;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String? id) async => users[id];

  @override
  Future<Map<String, dynamic>> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required String level,
    String? birthDate,
    String role = 'player',
  }) async {
    final row = {
      'id': id,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      'level': level,
      'birth_date': birthDate,
      'role': role,
      'avatar_url': null,
      'bio': null,
      'city': null,
      'created_at': DateTime.now(),
    };
    users[id] = row;
    return row;
  }

  @override
  Future<Map<String, dynamic>?> getUserWithStats(String userId, String viewerId) async {
    final u = users[userId];
    if (u == null) return null;
    return {...u, 'followers_count': 0, 'following_count': 0, 'sessions_count': 0, 'followed_by_me': false};
  }

  @override
  Future<Map<String, dynamic>?> getSessionById(String id) async => sessions[id];

  @override
  Future<Map<String, dynamic>> createSession({
    required String id,
    required String userId,
    String? trainingId,
    String? deviceId,
    required String title,
  }) async {
    final row = {
      'id': id,
      'user_id': userId,
      'title': title,
      'status': 'in_progress',
      'duration_seconds': 0,
      'shot_count': 0,
      'ace_count': 0,
    };
    sessions[id] = row;
    return row;
  }

  @override
  Future<void> insertSessionEvents(String sessionId, List<Map<String, Object?>> list) async {
    for (final e in list) {
      events.add({'session_id': sessionId, ...e});
    }
  }

  @override
  Future<bool> isFollowing(String followerId, String followingId) async =>
      follows.contains('$followerId>$followingId');

  @override
  Future<void> likeSession(String sessionId, String userId) async => likes.add('$sessionId|$userId');

  @override
  Future<List<Map<String, dynamic>>> getComments(String sessionId) async =>
      comments.where((c) => c['session_id'] == sessionId).toList();

  @override
  Future<Map<String, dynamic>> addComment({
    required String id,
    required String sessionId,
    required String userId,
    required String content,
  }) async {
    final row = {'id': id, 'session_id': sessionId, 'user_id': userId, 'content': content};
    comments.add(row);
    return row;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

const strongSecret = 'k3Y-9fQ2xLr7TnVb0aWm5ZpHs8DuJc1EoGiXy4BtNq6A';

SecurityConfig testConfig({Set<String> origins = const {}, bool production = false, bool trustProxy = false}) =>
    SecurityConfig(
      isProduction: production,
      jwtSecret: strongSecret,
      jwtExpiresInHours: 24,
      allowedOrigins: origins,
      trustProxy: trustProxy,
      maxBodyBytes: 256 * 1024,
    );

Request req(String method, String path, {Object? body, String? token, Map<String, String>? headers, String? rawBody}) {
  final h = <String, String>{
    if (body != null || rawBody != null) 'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
    ...?headers,
  };
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: h,
    body: rawBody ?? (body == null ? null : jsonEncode(body)),
  );
}

Future<Map<String, dynamic>> json(Response r) async {
  final text = await r.readAsString();
  return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  late FakeStore db;
  late Handler app;

  setUp(() {
    db = FakeStore();
    app = buildHandler(db, config: testConfig(), limiters: AuthLimiters());
  });

  Future<String> register(String email, {String password = 'Tenis2026Forte'}) async {
    final r = await app(req('POST', '/auth/register',
        body: {'name': 'Usuario Teste', 'email': email, 'password': password}));
    expect(r.statusCode, 201, reason: 'cadastro de $email');
    return (await json(r))['token'] as String;
  }

  String idOf(String email) => db.users.values.firstWhere((u) => u['email'] == email)['id'] as String;

  group('R-01 segredo JWT', () {
    test('segredos padrao/fracos sao reconhecidos', () {
      expect(SecurityConfig.isWeakSecret(null), isTrue);
      expect(SecurityConfig.isWeakSecret('dev-secret-troque-em-producao'), isTrue);
      expect(SecurityConfig.isWeakSecret('troque-este-segredo-antes-de-ir-para-producao'), isTrue);
      expect(SecurityConfig.isWeakSecret('curto'), isTrue);
      expect(SecurityConfig.isWeakSecret(strongSecret), isFalse);
      expect(SecurityConfig.isWeakSecret(SecurityConfig.generateEphemeralSecret()), isFalse);
    });

    test('token forjado com o segredo antigo do repositorio e rejeitado', () async {
      final victim = await register('vitima@swingsense.app');
      final victimId = idOf('vitima@swingsense.app');
      final forged = JWT({'sub': victimId, 'email': 'vitima@swingsense.app', 'role': 'admin'},
              issuer: 'smart-sense-api')
          .sign(SecretKey('dev-secret-troque-em-producao'), expiresIn: const Duration(hours: 1));
      final r = await app(req('GET', '/users/me', token: forged));
      expect(r.statusCode, 401);
      // O token legitimo continua funcionando.
      expect((await app(req('GET', '/users/me', token: victim))).statusCode, 200);
    });

    test('token sem jti/issuer (assinado com a chave certa) tambem e rejeitado', () async {
      final noIssuer = JWT({'sub': 'x', 'email': 'a@b.c', 'role': 'player'})
          .sign(SecretKey(strongSecret), expiresIn: const Duration(hours: 1));
      expect((await app(req('GET', '/users/me', token: noIssuer))).statusCode, 401);
    });
  });

  group('R-02 IDOR na telemetria', () {
    test('atacante nao grava eventos na sessao da vitima; dono grava', () async {
      final victim = await register('vitima@swingsense.app');
      final attacker = await register('atacante@swingsense.app');
      final s = await json(await app(req('POST', '/sessions', body: {'title': 'Treino'}, token: victim)));
      final sid = s['id'] as String;
      final payload = {
        'events': [
          {'eventType': 'forehand', 'ballSpeedKmh': 99.0}
        ]
      };

      final evil = await app(req('POST', '/sessions/$sid/events', body: payload, token: attacker));
      expect(evil.statusCode, 404);
      expect(db.events, isEmpty);

      final ok = await app(req('POST', '/sessions/$sid/events', body: payload, token: victim));
      expect(ok.statusCode, 201);
      expect(db.events, hasLength(1));
    });
  });

  group('R-03 IDOR em curtidas/comentarios', () {
    test('so dono ou seguidor (sessao concluida) interage', () async {
      final owner = await register('dono@swingsense.app');
      final stranger = await register('estranho@swingsense.app');
      final follower = await register('seguidor@swingsense.app');
      final sid = (await json(await app(req('POST', '/sessions', token: owner))))['id'] as String;
      db.follows.add('${idOf('seguidor@swingsense.app')}>${idOf('dono@swingsense.app')}');

      Future<int> like(String t) async => (await app(req('POST', '/feed/$sid/like', token: t))).statusCode;
      Future<int> comment(String t) async =>
          (await app(req('POST', '/feed/$sid/comments', body: {'content': 'oi'}, token: t))).statusCode;

      // dono interage na propria sessao (mesmo em andamento)
      expect(await like(owner), 200);
      // estranho e seguidor nao enxergam sessao em andamento
      expect(await like(stranger), 404);
      expect(await like(follower), 404);

      db.sessions[sid]!['status'] = 'completed';
      expect(await like(stranger), 404);
      expect(await comment(stranger), 404);
      expect((await app(req('GET', '/feed/$sid/comments', token: stranger))).statusCode, 404);
      expect(await like(follower), 200);
      expect(await comment(follower), 201);
    });

    test('comentario acima de 500 caracteres e recusado', () async {
      final owner = await register('dono@swingsense.app');
      final sid = (await json(await app(req('POST', '/sessions', token: owner))))['id'] as String;
      final r = await app(req('POST', '/feed/$sid/comments', body: {'content': 'a' * 501}, token: owner));
      expect(r.statusCode, 400);
    });
  });

  group('R-04/R-05 forca bruta e abuso', () {
    test('login: 5 falhas do mesmo IP+email => 429 com Retry-After', () async {
      app = buildHandler(db, config: testConfig(trustProxy: true), limiters: AuthLimiters());
      await register('alvo@swingsense.app');
      Future<Response> attempt(String ip, String pass) async => app(req('POST', '/auth/login',
          body: {'email': 'alvo@swingsense.app', 'password': pass}, headers: {'x-forwarded-for': ip}));

      for (var i = 0; i < 5; i++) {
        expect((await attempt('10.0.0.9', 'errada$i')).statusCode, 401);
      }
      final blocked = await attempt('10.0.0.9', 'Tenis2026Forte');
      expect(blocked.statusCode, 429);
      expect(blocked.headers['retry-after'], isNotNull);
      // Outro IP legitimo nao e afetado (sem DoS de conta pela vitima).
      expect((await attempt('10.0.0.77', 'Tenis2026Forte')).statusCode, 200);
    });

    test('login bem sucedido zera o contador de falhas', () async {
      app = buildHandler(db, config: testConfig(trustProxy: true), limiters: AuthLimiters());
      await register('alvo@swingsense.app');
      Future<Response> attempt(String pass) async => app(req('POST', '/auth/login',
          body: {'email': 'alvo@swingsense.app', 'password': pass}, headers: {'x-forwarded-for': '10.1.1.1'}));
      for (var i = 0; i < 4; i++) {
        await attempt('errada');
      }
      expect((await attempt('Tenis2026Forte')).statusCode, 200);
      for (var i = 0; i < 4; i++) {
        expect((await attempt('errada')).statusCode, 401);
      }
    });

    test('cadastro: limite por IP', () async {
      app = buildHandler(db,
          config: testConfig(trustProxy: true),
          limiters: AuthLimiters(
              registerPerIp: SlidingWindowLimiter(maxAttempts: 3, window: const Duration(hours: 1))));
      Future<int> reg(int i) async => (await app(req('POST', '/auth/register',
              body: {'name': 'Nome $i', 'email': 'u$i@x.com', 'password': 'Tenis2026Forte'},
              headers: {'x-forwarded-for': '10.2.2.2'})))
          .statusCode;
      expect(await reg(1), 201);
      expect(await reg(2), 201);
      expect(await reg(3), 201);
      expect(await reg(4), 429);
    });

    test('injecao de SQL no login continua falhando de forma segura', () async {
      final r = await app(req('POST', '/auth/login', body: {'email': "' OR '1'='1", 'password': 'x'}));
      expect(r.statusCode, 401);
    });

    test('janela deslizante libera apos o prazo', () {
      var now = DateTime(2026, 1, 1);
      final l = SlidingWindowLimiter(maxAttempts: 2, window: const Duration(minutes: 1), now: () => now);
      expect(l.hit('k'), isNull);
      expect(l.hit('k'), isNull);
      expect(l.hit('k'), isNotNull);
      now = now.add(const Duration(minutes: 2));
      expect(l.hit('k'), isNull);
    });
  });

  group('R-06 politica de senha', () {
    test('senhas fracas sao recusadas no cadastro', () async {
      for (final weak in ['123456', '12345678', 'abcdefgh', 'password1', 'Ab1', 'a' * 129 + '1']) {
        final r = await app(req('POST', '/auth/register',
            body: {'name': 'Fulano', 'email': 'f${weak.length}@x.com', 'password': weak}));
        expect(r.statusCode, 400, reason: weak.length > 20 ? 'senha longa' : weak);
      }
    });

    test('senha forte e aceita e login antigo (6+ caracteres) segue possivel', () async {
      await register('atleta@x.com');
      // Conta legada criada antes da nova politica:
      db.users['legado'] = {
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'Legado',
        'email': 'legado@x.com',
        'password_hash': PasswordUtil.hash('123456'),
        'role': 'player',
        'level': 'iniciante',
      };
      final r = await app(req('POST', '/auth/login', body: {'email': 'legado@x.com', 'password': '123456'}));
      expect(r.statusCode, 200);
    });

    test('validatePassword', () {
      expect(validatePassword('Tenis2026Forte'), isNull);
      expect(validatePassword('semnumeros'), isNotNull);
      expect(validatePassword('12345678901'), isNotNull);
      expect(validatePassword('joaosilva123', email: 'joaosilva@x.com'), isNotNull);
    });
  });

  group('R-07 CORS', () {
    test('origem desconhecida nao recebe Access-Control-Allow-Origin', () async {
      final r = await app(req('GET', '/health', headers: {'origin': 'https://site-malicioso.com'}));
      expect(r.headers['access-control-allow-origin'], isNull);
    });

    test('origem da allowlist e refletida; preflight de origem invalida = 403', () async {
      app = buildHandler(db,
          config: testConfig(origins: {'https://app.swingsense.app'}, production: true), limiters: AuthLimiters());
      final ok = await app(req('GET', '/health', headers: {'origin': 'https://app.swingsense.app'}));
      expect(ok.headers['access-control-allow-origin'], 'https://app.swingsense.app');
      final bad = await app(req('OPTIONS', '/auth/login', headers: {'origin': 'https://evil.com'}));
      expect(bad.statusCode, 403);
      // localhost so e liberado fora de producao
      final local = await app(req('GET', '/health', headers: {'origin': 'http://localhost:5555'}));
      expect(local.headers['access-control-allow-origin'], isNull);
    });

    test('em desenvolvimento localhost continua liberado (flutter run -d chrome)', () async {
      final r = await app(req('GET', '/health', headers: {'origin': 'http://localhost:5555'}));
      expect(r.headers['access-control-allow-origin'], 'http://localhost:5555');
    });
  });

  group('R-08 vida e revogacao do token', () {
    test('exp - iat <= 24h e logout invalida o token', () async {
      final token = await register('sessao@x.com');
      final payload = JWT.decode(token).payload as Map<String, dynamic>;
      expect((payload['exp'] as int) - (payload['iat'] as int), lessThanOrEqualTo(24 * 3600));
      expect(payload['jti'], isNotNull);

      expect((await app(req('GET', '/users/me', token: token))).statusCode, 200);
      expect((await app(req('POST', '/auth/logout', token: token))).statusCode, 200);
      expect((await app(req('GET', '/users/me', token: token))).statusCode, 401);
    });
  });

  group('R-09 cabecalhos / TLS', () {
    test('cabecalhos de seguranca presentes', () async {
      final r = await app(req('GET', '/health'));
      expect(r.headers['x-content-type-options'], 'nosniff');
      expect(r.headers['x-frame-options'], 'DENY');
      expect(r.headers['cache-control'], 'no-store');
      expect(r.headers['strict-transport-security'], isNull); // dev em HTTP
    });

    test('HSTS em producao', () async {
      app = buildHandler(db, config: testConfig(production: true), limiters: AuthLimiters());
      final r = await app(req('GET', '/health'));
      expect(r.headers['strict-transport-security'], contains('max-age='));
    });
  });

  group('R-11 limites e validacao', () {
    test('mais de 500 eventos => 413', () async {
      final t = await register('limite@x.com');
      final sid = (await json(await app(req('POST', '/sessions', token: t))))['id'] as String;
      final events = List.generate(501, (_) => {'eventType': 'shot', 'ballSpeedKmh': 80});
      final r = await app(req('POST', '/sessions/$sid/events', body: {'events': events}, token: t));
      expect(r.statusCode, 413);
      expect(db.events, isEmpty);
    });

    test('corpo gigante => 413 (Content-Length e streaming)', () async {
      final big = jsonEncode({'content': 'x' * (300 * 1024)});
      final r = await app(req('POST', '/auth/login', rawBody: big));
      expect(r.statusCode, 413);
    });

    test('valores fora de faixa / tipos errados / JSON invalido => 400 (nunca 500)', () async {
      final t = await register('valida@x.com');
      final sid = (await json(await app(req('POST', '/sessions', token: t))))['id'] as String;
      Future<int> post(Object e) async =>
          (await app(req('POST', '/sessions/$sid/events', body: {'events': [e]}, token: t))).statusCode;
      expect(await post({'eventType': 'shot', 'ballSpeedKmh': 99999}), 400);
      expect(await post({'eventType': 'shot', 'ballSpeedKmh': 'rapida'}), 400);
      expect(await post({'eventType': "x'; DROP TABLE usuarios;--"}), 400);
      expect(await post('nao-e-objeto'), 400);
      expect(await post({'eventType': 'shot', 'ballSpeedKmh': 80.5}), 201);

      expect((await app(req('POST', '/auth/login', rawBody: '{nao-e-json'))).statusCode, 400);
      expect((await app(req('POST', '/auth/login', rawBody: '[1,2]'))).statusCode, 400);
      expect((await app(req('PATCH', '/sessions/$sid', body: {'shotCount': -5}, token: t))).statusCode, 400);
      expect((await app(req('PATCH', '/sessions/nao-uuid', body: {'status': 'paused'}, token: t))).statusCode, 404);
    });
  });

  group('Privacidade do perfil publico', () {
    test('perfil de terceiros nao expoe email, nascimento nem role', () async {
      final a = await register('a@x.com');
      await register('b@x.com');
      final other = await json(await app(req('GET', '/users/${idOf('b@x.com')}', token: a)));
      expect(other.containsKey('email'), isFalse);
      expect(other.containsKey('birthDate'), isFalse);
      expect(other.containsKey('role'), isFalse);
      expect(other['name'], isNotNull);
      final me = await json(await app(req('GET', '/users/me', token: a)));
      expect(me['email'], 'a@x.com');
    });
  });

  test('erros internos nao vazam detalhes', () async {
    final t = await register('erro@x.com');
    // /trainings usa um metodo nao implementado no FakeStore => erro inesperado.
    final r = await app(req('GET', '/trainings', token: t));
    expect(r.statusCode, 500);
    final body = await r.readAsString();
    expect(body, contains('Erro interno'));
    expect(body, isNot(contains('Unimplemented')));
  });
}
