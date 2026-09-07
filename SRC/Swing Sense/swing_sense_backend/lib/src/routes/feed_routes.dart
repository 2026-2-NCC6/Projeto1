import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router feedRoutes(MemoryStore db) {
  final router = Router();

  // GET /feed - sessoes concluidas de quem o usuario segue + as suas proprias.
  router.get('/', (Request request) async {
    final me = request.userId;
    final followingIds = db.follows.where((f) => f['follower_id'] == me).map((f) => f['following_id']).toSet();

    final sessions = db.trainingSessions
        .where((s) => s['status'] == 'completed' && (s['user_id'] == me || followingIds.contains(s['user_id'])))
        .toList()
      ..sort((a, b) => (b['started_at'] as DateTime).compareTo(a['started_at'] as DateTime));

    final result = sessions
        .take(50)
        .map((s) => sessionToJson(db.hydrateSession(s, viewerId: me, includeAuthor: true, includeEngagement: true)))
        .toList();
    return ApiResponse.ok(result);
  });

  // POST /feed/:sessionId/like
  router.post('/<sessionId>/like', (Request request, String sessionId) async {
    final me = request.userId;
    final alreadyLiked = db.sessionLikes.any((l) => l['session_id'] == sessionId && l['user_id'] == me);
    if (!alreadyLiked) {
      db.sessionLikes.add({'session_id': sessionId, 'user_id': me, 'created_at': DateTime.now()});
    }
    return ApiResponse.ok({'liked': true});
  });

  // DELETE /feed/:sessionId/like
  router.delete('/<sessionId>/like', (Request request, String sessionId) async {
    db.sessionLikes.removeWhere((l) => l['session_id'] == sessionId && l['user_id'] == request.userId);
    return ApiResponse.ok({'liked': false});
  });

  // GET /feed/:sessionId/comments
  router.get('/<sessionId>/comments', (Request request, String sessionId) async {
    final comments = db.sessionComments.where((c) => c['session_id'] == sessionId).toList()
      ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));
    final result = comments.map((c) {
      final author = db.userById(c['user_id'] as String?);
      return commentToJson({
        ...c,
        'user_name': author?['name'],
        'user_avatar_url': author?['avatar_url'],
      });
    }).toList();
    return ApiResponse.ok(result);
  });

  // POST /feed/:sessionId/comments
  router.post('/<sessionId>/comments', (Request request, String sessionId) async {
    final body = await readJsonBody(request);
    final content = (body['content'] as String?)?.trim();
    if (content == null || content.isEmpty) {
      return ApiResponse.error('Comentario nao pode ser vazio');
    }
    final row = {
      'id': MemoryStore.newId(),
      'session_id': sessionId,
      'user_id': request.userId,
      'content': content,
      'created_at': DateTime.now(),
    };
    db.sessionComments.add(row);
    final author = db.userById(request.userId);
    return ApiResponse.created(commentToJson({
      ...row,
      'user_name': author?['name'],
      'user_avatar_url': author?['avatar_url'],
    }));
  });

  return router;
}
