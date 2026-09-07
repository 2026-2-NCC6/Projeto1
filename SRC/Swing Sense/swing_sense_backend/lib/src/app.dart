import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db/database.dart';
import 'middleware/auth_middleware.dart';
import 'routes/auth_routes.dart';
import 'routes/device_routes.dart';
import 'routes/feed_routes.dart';
import 'routes/glossary_routes.dart';
import 'routes/goal_routes.dart';
import 'routes/session_routes.dart';
import 'routes/training_routes.dart';
import 'routes/user_routes.dart';
import 'utils/jwt_util.dart';
import 'utils/response.dart';

Middleware _corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}

Handler buildApp(Database database) {
  final jwtUtil = JwtUtil(
    secret: Platform.environment['JWT_SECRET'] ?? 'dev-secret-troque-em-producao',
    expiresInHours: int.parse(Platform.environment['JWT_EXPIRES_IN_HOURS'] ?? '168'),
  );

  final db = database.store;

  final publicRouter = Router()
    ..mount('/auth', authRoutes(db, jwtUtil).call)
    ..mount('/glossary', glossaryRoutes(db).call)
    ..get('/health', (Request _) => ApiResponse.ok({'status': 'ok'}));

  final protectedRouter = Router()
    ..mount('/users', userRoutes(db).call)
    ..mount('/feed', feedRoutes(db).call)
    ..mount('/trainings', trainingRoutes(db).call)
    ..mount('/sessions', sessionRoutes(db).call)
    ..mount('/goals', goalRoutes(db).call)
    ..mount('/devices', deviceRoutes(db).call);

  final protectedHandler = const Pipeline()
      .addMiddleware(authMiddleware(jwtUtil))
      .addHandler(protectedRouter.call);

  final rootRouter = Router()
    ..mount('/', publicRouter.call)
    ..mount('/', protectedHandler);

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsHeaders())
      .addHandler(rootRouter.call);
}
