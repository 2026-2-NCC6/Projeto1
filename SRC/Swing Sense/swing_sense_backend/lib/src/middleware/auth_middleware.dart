import 'package:shelf/shelf.dart';

import '../utils/jwt_util.dart';
import '../utils/response.dart';

/// Extrai e valida o Bearer token, injetando `userId`, `userEmail` e
/// `userRole` no contexto da requisicao para as rotas protegidas usarem.
Middleware authMiddleware(JwtUtil jwtUtil) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.unauthorized('Envie o token no header Authorization: Bearer <token>');
      }

      final token = authHeader.substring('Bearer '.length).trim();
      final payload = jwtUtil.verify(token);
      if (payload == null) {
        return ApiResponse.unauthorized('Token invalido ou expirado');
      }

      final updatedRequest = request.change(context: {
        'userId': payload['sub'] as String,
        'userEmail': payload['email'] as String,
        'userRole': payload['role'] as String,
      });

      return innerHandler(updatedRequest);
    };
  };
}

extension RequestAuthX on Request {
  String get userId => context['userId'] as String;
  String get userRole => context['userRole'] as String;
}
