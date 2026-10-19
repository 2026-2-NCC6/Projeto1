import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

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
    final title = body['title'] is String ? (body['title'] as String).trim() : null;
    final type = body['type'];
    final targetValue = toDoubleOrNull(body['targetValue']);
    if (title == null || title.isEmpty || type is! String || targetValue == null) {
      return ApiResponse.error('title, type e targetValue sao obrigatorios');
    }
    final error = [
      validateText(title, 'Titulo', max: 100),
      isSlug(type) ? null : 'Tipo de meta invalido',
      validateNumber(targetValue, 'targetValue', min: 0, max: 10000000),
      validateText(body['unit'], 'Unidade', max: 20),
      validateDate(body['deadline'], 'Prazo', notBefore: DateTime(2000), notAfter: DateTime(2100)),
    ].firstWhere((e) => e != null, orElse: () => null);
    if (error != null) return ApiResponse.error(error);

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
    if (!isUuid(id)) return ApiResponse.notFound('Meta nao encontrada');
    final status = body['status'];
    if (status != null && (status is! String || !validGoalStatuses.contains(status))) {
      return ApiResponse.error('Status invalido');
    }
    final numberError = validateNumber(body['currentValue'], 'currentValue', min: 0, max: 10000000);
    if (numberError != null) return ApiResponse.error(numberError);

    final fields = <String, Object?>{};
    if (body['currentValue'] != null) fields['current_value'] = toDoubleOrNull(body['currentValue']);
    if (status != null) fields['status'] = status;

    final goal = await db.updateGoal(id, request.userId, fields);
    if (goal == null) return ApiResponse.notFound('Meta nao encontrada');
    return ApiResponse.ok(goalToJson(goal));
  });

  // DELETE /goals/:id
  router.delete('/<id>', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.notFound('Meta nao encontrada');
    await db.deleteGoal(id, request.userId);
    return ApiResponse.noContent();
  });

  return router;
}
