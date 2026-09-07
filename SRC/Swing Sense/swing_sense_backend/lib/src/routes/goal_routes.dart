import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router goalRoutes(MemoryStore db) {
  final router = Router();

  // GET /goals
  router.get('/', (Request request) async {
    final goals = db.goals.where((g) => g['user_id'] == request.userId).toList()
      ..sort((a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
    return ApiResponse.ok(goals.map((g) => goalToJson(g)).toList());
  });

  // POST /goals
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim();
    final type = body['type'] as String?;
    final targetValue = body['targetValue'];
    if (title == null || title.isEmpty || type == null || targetValue == null) {
      return ApiResponse.error('title, type e targetValue sao obrigatorios');
    }

    final row = {
      'id': MemoryStore.newId(),
      'user_id': request.userId,
      'type': type,
      'title': title,
      'target_value': targetValue,
      'current_value': 0.0,
      'unit': body['unit'] ?? 'un',
      'deadline': body['deadline'],
      'status': 'active',
      'created_at': DateTime.now(),
    };
    db.goals.add(row);
    return ApiResponse.created(goalToJson(row));
  });

  // PATCH /goals/:id
  router.patch('/<id>', (Request request, String id) async {
    final body = await readJsonBody(request);
    Map<String, dynamic>? goal;
    for (final g in db.goals) {
      if (g['id'] == id && g['user_id'] == request.userId) {
        goal = g;
        break;
      }
    }
    if (goal == null) return ApiResponse.notFound('Meta nao encontrada');

    if (body['currentValue'] != null) goal['current_value'] = body['currentValue'];
    if (body['status'] != null) goal['status'] = body['status'];

    return ApiResponse.ok(goalToJson(goal));
  });

  // DELETE /goals/:id
  router.delete('/<id>', (Request request, String id) async {
    db.goals.removeWhere((g) => g['id'] == id && g['user_id'] == request.userId);
    return ApiResponse.noContent();
  });

  return router;
}
