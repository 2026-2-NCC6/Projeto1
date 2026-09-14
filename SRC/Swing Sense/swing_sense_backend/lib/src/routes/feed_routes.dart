import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router feedRoutes(PgStore db) {
  final router = Router();

  // GET /feed - sessoes concluidas de quem o usuario segue + as suas proprias.
  router.get('/', (Request request) async {
    final sessions = await db.getFeedSessions(request.userId);
    return ApiResponse.ok(sessions.map((s) => sessionToJson(s)).toList());
  });

  // POST /feed/:sessionId/like
  router.post('/<sessionId>/like', (Request request, String sessionId) async {
    await db.likeSession(sessionId, request.userId);
    return ApiResponse.ok({'liked': true});
  });

  // DELETE /feed/:sessionId/like
  router.delete('/<sessionId>/like', (Request request, String sessionId) async {
    await db.unlikeSession(sessionId, request.userId);
    return ApiResponse.ok({'liked': false});
  });

  // GET /feed/:sessionId/comments
  router.get('/<sessionId>/comments', (Request request, String sessionId) async {
    final comments = await db.getComments(sessionId);
    return ApiResponse.ok(comments.map((c) => commentToJson(c)).toList());
  });

  // POST /feed/:sessionId/comments
  router.post('/<sessionId>/comments', (Request request, String sessionId) async {
    final body = await readJsonBody(request);
    final content = (body['content'] as String?)?.trim();
    if (content == null || content.isEmpty) {
      return ApiResponse.error('Comentario nao pode ser vazio');
    }
    final row = await db.addComment(
      id: PgStore.newId(),
      sessionId: sessionId,
      userId: request.userId,
      content: content,
    );
    return ApiResponse.created(commentToJson(row));
  });

  return router;
}
