import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

Router feedRoutes(PgStore db) {
  final router = Router();

  /// R-03: uma sessao so e visivel (curtir/comentar/ler comentarios) para o
  /// dono ou para quem segue o dono - exatamente a regra do proprio feed
  /// (sessoes concluidas de quem o usuario segue + as suas).
  Future<bool> canInteract(String sessionId, String viewerId) async {
    if (!isUuid(sessionId)) return false;
    final session = await db.getSessionById(sessionId);
    if (session == null) return false;
    final ownerId = session['user_id'].toString();
    if (ownerId == viewerId) return true;
    if (session['status'] != 'completed') return false;
    return db.isFollowing(viewerId, ownerId);
  }

  // GET /feed - sessoes concluidas de quem o usuario segue + as suas proprias.
  router.get('/', (Request request) async {
    final sessions = await db.getFeedSessions(request.userId);
    return ApiResponse.ok(sessions.map((s) => sessionToJson(s)).toList());
  });

  // POST /feed/:sessionId/like
  router.post('/<sessionId>/like', (Request request, String sessionId) async {
    if (!await canInteract(sessionId, request.userId)) return ApiResponse.notFound('Sessao nao encontrada');
    await db.likeSession(sessionId, request.userId);
    return ApiResponse.ok({'liked': true});
  });

  // DELETE /feed/:sessionId/like
  router.delete('/<sessionId>/like', (Request request, String sessionId) async {
    if (!isUuid(sessionId)) return ApiResponse.notFound('Sessao nao encontrada');
    await db.unlikeSession(sessionId, request.userId);
    return ApiResponse.ok({'liked': false});
  });

  // GET /feed/:sessionId/comments
  router.get('/<sessionId>/comments', (Request request, String sessionId) async {
    if (!await canInteract(sessionId, request.userId)) return ApiResponse.notFound('Sessao nao encontrada');
    final comments = await db.getComments(sessionId);
    return ApiResponse.ok(comments.map((c) => commentToJson(c)).toList());
  });

  // POST /feed/:sessionId/comments
  router.post('/<sessionId>/comments', (Request request, String sessionId) async {
    final body = await readJsonBody(request);
    final contentError = validateText(body['content'], 'Comentario', max: 500, required: true);
    if (contentError != null) {
      return ApiResponse.error(contentError == 'Comentario e obrigatorio' ? 'Comentario nao pode ser vazio' : contentError);
    }
    if (!await canInteract(sessionId, request.userId)) return ApiResponse.notFound('Sessao nao encontrada');

    final row = await db.addComment(
      id: PgStore.newId(),
      sessionId: sessionId,
      userId: request.userId,
      content: (body['content'] as String).trim(),
    );
    return ApiResponse.created(commentToJson(row));
  });

  return router;
}
