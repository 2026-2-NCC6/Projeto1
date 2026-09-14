import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../utils/jwt_util.dart';
import '../utils/password_util.dart';
import '../utils/response.dart';

Router authRoutes(PgStore db, JwtUtil jwtUtil) {
  final router = Router();

  // POST /auth/register
  router.post('/register', (request) async {
    final body = await readJsonBody(request);
    final name = (body['name'] as String?)?.trim();
    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;

    if (name == null || name.isEmpty) return ApiResponse.error('Nome e obrigatorio');
    if (email == null || !email.contains('@')) return ApiResponse.error('Email invalido');
    if (password == null || password.length < 6) {
      return ApiResponse.error('Senha deve ter pelo menos 6 caracteres');
    }

    final existing = await db.findUserByEmail(email);
    if (existing != null) {
      return ApiResponse.error('Ja existe uma conta com este email', status: 409);
    }

    final hash = PasswordUtil.hash(password);
    final level = (body['level'] as String?) ?? 'iniciante';
    final birthDate = body['birthDate'] as String?;

    Map<String, dynamic> row;
    try {
      row = await db.createUser(
        id: PgStore.newId(),
        name: name,
        email: email,
        passwordHash: hash,
        level: level,
        birthDate: birthDate,
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
  router.post('/login', (request) async {
    final body = await readJsonBody(request);
    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return ApiResponse.error('Email e senha sao obrigatorios');
    }

    final row = await db.findUserByEmail(email);
    if (row == null) {
      return ApiResponse.error('Email ou senha incorretos', status: 401);
    }

    final passwordHash = row['password_hash'] as String?;
    if (passwordHash == null || !PasswordUtil.verify(password, passwordHash)) {
      return ApiResponse.error('Email ou senha incorretos', status: 401);
    }

    final token = jwtUtil.generate(
      userId: row['id'] as String,
      email: row['email'] as String,
      role: row['role'] as String,
    );

    return ApiResponse.ok({'token': token, 'user': userToJson(row)});
  });

  return router;
}
