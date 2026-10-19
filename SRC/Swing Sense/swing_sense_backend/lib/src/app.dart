import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db/database.dart';
import 'db/postgres_store.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/security_middleware.dart';
import 'routes/auth_routes.dart';
import 'routes/device_routes.dart';
import 'routes/feed_routes.dart';
import 'routes/glossary_routes.dart';
import 'routes/goal_routes.dart';
import 'routes/session_routes.dart';
import 'routes/tacada_routes.dart';
import 'routes/training_routes.dart';
import 'routes/user_routes.dart';
import 'utils/jwt_util.dart';
import 'utils/response.dart';
import 'utils/security_config.dart';

Handler buildApp(Database database, {SecurityConfig? config}) {
  return buildHandler(database.store, config: config ?? SecurityConfig.fromEnv());
}

/// Monta o pipeline completo a partir de um `PgStore` (separado de `buildApp`
/// para permitir testes automatizados com um banco em memoria).
Handler buildHandler(PgStore db, {required SecurityConfig config, AuthLimiters? limiters}) {
  final jwtUtil = JwtUtil(
    secret: config.jwtSecret,
    expiresInHours: config.jwtExpiresInHours,
  );

  final publicRouter = Router()
    ..mount('/auth', authRoutes(db, jwtUtil, limiters: limiters, trustProxy: config.trustProxy).call)
    ..mount('/glossary', glossaryRoutes(db).call)
    ..get('/health', (Request _) => ApiResponse.ok({'status': 'ok'}));

  final protectedRouter = Router()
    ..mount('/users', userRoutes(db).call)
    ..mount('/feed', feedRoutes(db).call)
    ..mount('/trainings', trainingRoutes(db).call)
    ..mount('/sessions', sessionRoutes(db).call)
    ..mount('/goals', goalRoutes(db).call)
    ..mount('/devices', deviceRoutes(db).call)
    ..mount('/tacadas', tacadaRoutes(db).call);

  final protectedHandler = const Pipeline()
      .addMiddleware(authMiddleware(jwtUtil))
      .addHandler(protectedRouter.call);

  final rootRouter = Router()
    ..mount('/', publicRouter.call)
    ..mount('/', protectedHandler);

  // Ordem (de fora para dentro): log -> cabecalhos de seguranca -> CORS ->
  // tratamento de erros -> limite de corpo -> rotas.
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(securityHeaders(config))
      .addMiddleware(corsAllowlist(config))
      .addMiddleware(errorHandler())
      .addMiddleware(bodyLimit(config.maxBodyBytes))
      .addHandler(rootRouter.call);
}
