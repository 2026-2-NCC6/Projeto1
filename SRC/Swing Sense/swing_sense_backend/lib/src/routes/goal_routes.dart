import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router goalRoutes(PgStore db) {
  final router = Router();

  // GET /goals
  router.get('/', (Request request) async {
    final goals = await db.getGoalsForUser(request.userId);
    return ApiResponse.ok(goals.map((g) => goalToJson(g)).toList());
  });

  // POST /goals
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim();
    final type = body['type'] as String?;
    final targetValue = toDoubleOrNull(body['targetValue']);
    if (title == null || title.isEmpty || type == null || targetValue == null) {
      return ApiResponse.error('title, type e targetValue sao obrigatorios');
    }

    final row = await db.createGoal(
      id: PgStore.newId(),
      userId: request.userId,
      type: type,
      title: title,
      targetValue: targetValue,
      currentValue: 0.0,
      unit: body['unit'] as String? ?? 'un',
      deadline: body['deadline'] as String?,
    );
    return ApiResponse.created(goalToJson(row));
  });

  // PATCH /goals/:id
  router.patch('/<id>', (Request request, String id) async {
    final body = await readJsonBody(request);
    final fields = <String, Object?>{};
    if (body['currentValue'] != null) fields['current_value'] = toDoubleOrNull(body['currentValue']);
    if (body['status'] != null) fields['status'] = body['status'];

    final goal = await db.updateGoal(id, request.userId, fields);
    if (goal == null) return ApiResponse.notFound('Meta nao encontrada');
    return ApiResponse.ok(goalToJson(goal));
  });

  // DELETE /goals/:id
  router.delete('/<id>', (Request request, String id) async {
    await db.deleteGoal(id, request.userId);
    return ApiResponse.noContent();
  });

  return router;
}
