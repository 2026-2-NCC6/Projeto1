import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router userRoutes(PgStore db) {
  final router = Router();

  Future<Map<String, dynamic>?> fetchUserWithStats(String userId, String viewerId) async {
    final row = await db.getUserWithStats(userId, viewerId);
    if (row == null) return null;
    return {
      ...userToJson(row),
      'followersCount': toIntOr(row['followers_count']),
      'followingCount': toIntOr(row['following_count']),
      'sessionsCount': toIntOr(row['sessions_count']),
      'followedByMe': row['followed_by_me'] == true,
    };
  }

  // GET /users/me
  router.get('/me', (Request request) async {
    final user = await fetchUserWithStats(request.userId, request.userId);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    return ApiResponse.ok(user);
  });

  // PUT /users/me
  router.put('/me', (Request request) async {
    final body = await readJsonBody(request);
    final fields = <String, Object?>{};
    if (body['name'] != null) fields['name'] = body['name'];
    if (body['bio'] != null) fields['bio'] = body['bio'];
    if (body['avatarUrl'] != null) fields['avatar_url'] = body['avatarUrl'];
    if (body['level'] != null) fields['level'] = body['level'];
    if (body['city'] != null) fields['city'] = body['city'];

    final user = await db.updateUser(request.userId, fields);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    return ApiResponse.ok(userToJson(user));
  });

  // GET /users/search?q=
  router.get('/search', (Request request) async {
    final query = request.url.queryParameters['q']?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return ApiResponse.ok([]);
    final results = await db.searchUsers(query, request.userId, limit: 20);
    return ApiResponse.ok(results.map((u) => userSummaryToJson(u)).toList());
  });

  // GET /users/:id
  router.get('/<id>', (Request request, String id) async {
    final user = await fetchUserWithStats(id, request.userId);
    if (user == null) return ApiResponse.notFound('Usuario nao encontrado');
    return ApiResponse.ok(user);
  });

  // POST /users/:id/follow
  router.post('/<id>/follow', (Request request, String id) async {
    if (id == request.userId) {
      return ApiResponse.error('Voce nao pode seguir a si mesmo');
    }
    await db.follow(request.userId, id);
    return ApiResponse.ok({'following': true});
  });

  // DELETE /users/:id/follow
  router.delete('/<id>/follow', (Request request, String id) async {
    await db.unfollow(request.userId, id);
    return ApiResponse.ok({'following': false});
  });

  // GET /users/:id/sessions
  router.get('/<id>/sessions', (Request request, String id) async {
    final sessions = await db.getUserSessions(id, request.userId);
    return ApiResponse.ok(sessions.map((s) => sessionToJson(s)).toList());
  });

  return router;
}
