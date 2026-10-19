import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/security_middleware.dart';
import '../utils/jwt_util.dart';
import '../utils/password_util.dart';
import '../utils/rate_limiter.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

/// Limitadores usados pelas rotas de autenticacao (R-05 e R-04).
class AuthLimiters {
  AuthLimiters({
    SlidingWindowLimiter? loginPerIp,
    SlidingWindowLimiter? loginFailuresPerIpEmail,
    SlidingWindowLimiter? loginFailuresPerEmail,
    SlidingWindowLimiter? registerPerIp,
  })  : loginPerIp = loginPerIp ?? SlidingWindowLimiter(maxAttempts: 30, window: const Duration(minutes: 15)),
        loginFailuresPerIpEmail =
            loginFailuresPerIpEmail ?? SlidingWindowLimiter(maxAttempts: 5, window: const Duration(minutes: 15)),
        loginFailuresPerEmail =
            loginFailuresPerEmail ?? SlidingWindowLimiter(maxAttempts: 20, window: const Duration(minutes: 15)),
        registerPerIp = registerPerIp ?? SlidingWindowLimiter(maxAttempts: 10, window: const Duration(hours: 1));

  /// Todas as tentativas de login vindas de um IP.
  final SlidingWindowLimiter loginPerIp;

  /// Falhas para o par IP+email (bloqueio rapido sem permitir que um atacante
  /// trave o login da vitima a partir de outro IP).
  final SlidingWindowLimiter loginFailuresPerIpEmail;

  /// Falhas por email vindas de qualquer IP (limite alto: barra ataque
  /// distribuido sem facilitar DoS de conta).
  final SlidingWindowLimiter loginFailuresPerEmail;

  /// Cadastros por IP (mitiga enumeracao de emails e criacao em massa).
  final SlidingWindowLimiter registerPerIp;
}

Response _tooManyRequests(Duration wait) {
  final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds + 1;
  final response = ApiResponse.error(
    'Muitas tentativas. Tente novamente em alguns minutos.',
    status: 429,
  );
  return response.change(headers: {'Retry-After': '$seconds'});
}

Router authRoutes(
  PgStore db,
  JwtUtil jwtUtil, {
  AuthLimiters? limiters,
  bool trustProxy = false,
}) {
  final router = Router();
  final limits = limiters ?? AuthLimiters();

  // Hash descartavel: quando o email nao existe ainda executamos um bcrypt
  // para que o tempo de resposta nao revele se a conta existe (timing attack).
  final dummyHash = PasswordUtil.hash('senha-descartavel-timing-0');

  // POST /auth/register
  router.post('/register', (Request request) async {
    final ip = clientIp(request, trustProxy: trustProxy);
    final blocked = limits.registerPerIp.hit(ip);
    if (blocked != null) return _tooManyRequests(blocked);

    final body = await readJsonBody(request);
    final name = (body['name'] is String) ? (body['name'] as String).trim() : null;
    final email = (body['email'] is String) ? (body['email'] as String).trim().toLowerCase() : null;
    final password = body['password'] is String ? body['password'] as String : null;

    final nameError = validateText(name, 'Nome', min: 2, max: 80, required: true);
    if (nameError != null) return ApiResponse.error(nameError);
    if (email == null || !isValidEmail(email)) return ApiResponse.error('Email invalido');
    if (password == null) return ApiResponse.error('Senha e obrigatoria');
    final passwordError = validatePassword(password, email: email, name: name);
    if (passwordError != null) return ApiResponse.error(passwordError);

    final level = (body['level'] as String?) ?? 'iniciante';
    if (!validLevels.contains(level)) return ApiResponse.error('Nivel invalido');
    final birthDate = body['birthDate'];
    final birthError = validateDate(birthDate, 'Data de nascimento',
        notAfter: DateTime.now(), notBefore: DateTime(1900));
    if (birthError != null) return ApiResponse.error(birthError);

    // Mantemos o 409 (o app depende dele para orientar o usuario); a
    // enumeracao em massa e contida pelo rate limit por IP acima.
    final existing = await db.findUserByEmail(email);
    if (existing != null) {
      return ApiResponse.error('Ja existe uma conta com este email', status: 409);
    }

    final hash = PasswordUtil.hash(password);

    Map<String, dynamic> row;
    try {
      row = await db.createUser(
        id: PgStore.newId(),
        name: name!,
        email: email,
        passwordHash: hash,
        level: level,
        birthDate: birthDate as String?,
      );
    } on ServerException catch (e) {
      if (e.code == '23505') {
        return ApiResponse.error('Ja existe uma conta com este email', status: 409);
      }
      rethrow;
    }

    final token = jwtUtil.generate(
      userId: row['id'] as String,
      email: row['email'] as String,
      role: row['role'] as String,
    );

    return ApiResponse.created({'token': token, 'user': userToJson(row)});
  });

  // POST /auth/login
  router.post('/login', (Request request) async {
    final ip = clientIp(request, trustProxy: trustProxy);
    final ipBlocked = limits.loginPerIp.hit(ip);
    if (ipBlocked != null) return _tooManyRequests(ipBlocked);

    final body = await readJsonBody(request);
    final email = (body['email'] is String) ? (body['email'] as String).trim().toLowerCase() : null;
    final password = body['password'] is String ? body['password'] as String : null;

    if (email == null || password == null || email.length > 254 || password.length > 1024) {
      return ApiResponse.error('Email e senha sao obrigatorios');
    }

    final pairKey = '$ip|$email';
    final lockedPair = limits.loginFailuresPerIpEmail.blockedFor(pairKey);
    if (lockedPair != null) return _tooManyRequests(lockedPair);
    final lockedEmail = limits.loginFailuresPerEmail.blockedFor(email);
    if (lockedEmail != null) return _tooManyRequests(lockedEmail);

    Response fail() {
      limits.loginFailuresPerIpEmail.record(pairKey);
      limits.loginFailuresPerEmail.record(email);
      return ApiResponse.error('Email ou senha incorretos', status: 401);
    }

    final row = await db.findUserByEmail(email);
    if (row == null) {
      PasswordUtil.verify(password, dummyHash);
      return fail();
    }

    final passwordHash = row['password_hash'] as String?;
    if (passwordHash == null || !PasswordUtil.verify(password, passwordHash)) {
      return fail();
    }

    limits.loginFailuresPerIpEmail.reset(pairKey);

    final token = jwtUtil.generate(
      userId: row['id'] as String,
      email: row['email'] as String,
      role: row['role'] as String,
    );

    return ApiResponse.ok({'token': token, 'user': userToJson(row)});
  });

  // POST /auth/logout - revoga o token atual (R-08). Sempre 200 (idempotente).
  router.post('/logout', (Request request) async {
    final header = request.headers['authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      jwtUtil.revoke(header.substring('Bearer '.length).trim());
    }
    return ApiResponse.ok({'loggedOut': true});
  });

  return router;
}
