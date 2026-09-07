import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router userRoutes(MemoryStore db) {
  final router = Router();

  Map<String, dynamic>? fetchUserWithStats(String userId, String? viewerId) {
    final user = db.userById(userId);
    if (user == null) return null;
    return {
      ...userToJson(user),
      'followersCount': db.followersCountOf(userId),
      'followingCount': db.followingCountOf(userId),
      'sessionsCount': db.completedSessionsCountOf(userId),
      'followedByMe': viewerId != null && db.isFollowing(viewerId, userId),
    };
  }

  // GET /users/me
  router.get('/me', (Request request) async {
    final user = fetchUserWithStats(request.userId, request.userId);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    return ApiResponse.ok(user);
  });

  // PUT /users/me
  router.put('/me', (Request request) async {
    final body = await readJsonBody(request);
    final user = db.userById(request.userId);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    if (body['name'] != null) user['name'] = body['name'];
    if (body['bio'] != null) user['bio'] = body['bio'];
    if (body['avatarUrl'] != null) user['avatar_url'] = body['avatarUrl'];
    if (body['level'] != null) user['level'] = body['level'];
    if (body['city'] != null) user['city'] = body['city'];
    return ApiResponse.ok(userToJson(user));
  });

  // GET /users/search?q=
  router.get('/search', (Request request) async {
    final query = request.url.queryParameters['q']?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return ApiResponse.ok([]);
    final results = db.users
        .where((u) => u['id'] != request.userId && (u['name'] as String).toLowerCase().contains(query))
        .take(20)
        .map((u) => userSummaryToJson(u))
        .toList();
    return ApiResponse.ok(results);
  });

  // GET /users/:id
  router.get('/<id>', (Request request, String id) async {
    final user = fetchUserWithStats(id, request.userId);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    return ApiResponse.ok(user);
  });

  // POST /users/:id/follow
  router.post('/<id>/follow', (Request request, String id) async {
    if (id == request.userId) {
      return ApiResponse.error('Voce nao pode seguir a si mesmo');
    }
    if (!db.isFollowing(request.userId, id)) {
      db.follows.add({
        'follower_id': request.userId,
        'following_id': id,
        'created_at': DateTime.now(),
      });
    }
    return ApiResponse.ok({'following': true});
  });

  // DELETE /users/:id/follow
  router.delete('/<id>/follow', (Request request, String id) async {
    db.follows.removeWhere((f) => f['follower_id'] == request.userId && f['following_id'] == id);
    return ApiResponse.ok({'following': false});
  });

  // GET /users/:id/sessions
  router.get('/<id>/sessions', (Request request, String id) async {
    final sessions = db.trainingSessions.where((s) => s['user_id'] == id && s['status'] == 'completed').toList()
      ..sort((a, b) => (b['started_at'] as DateTime).compareTo(a['started_at'] as DateTime));
    final result = sessions
        .take(50)
        .map((s) => sessionToJson(db.hydrateSession(s, viewerId: request.userId, includeEngagement: true)))
        .toList();
    return ApiResponse.ok(result);
  });

  return router;
}
