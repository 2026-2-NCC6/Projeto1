import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

Router trainingRoutes(PgStore db) {
  final router = Router();

  // GET /trainings?difficulty=&audience=&focus=
  router.get('/', (Request request) async {
    final params = request.url.queryParameters;
    final trainings = await db.getTrainings(
      difficulty: params['difficulty'],
      audience: params['audience'],
      focus: params['focus'],
    );
    return ApiResponse.ok(trainings.map((t) => trainingToJson(t)).toList());
  });

  // GET /trainings/:id
  router.get('/<id>', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.notFound('Treino nao encontrado');
    final training = await db.getTrainingById(id);
    if (training == null) return ApiResponse.notFound('Treino nao encontrado');
    return ApiResponse.ok(trainingToJson(training));
  });

  // POST /trainings - qualquer usuario autenticado pode publicar (autor/treinador).
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = body['title'] is String ? (body['title'] as String).trim() : null;
    if (title == null || title.isEmpty) return ApiResponse.error('Titulo e obrigatorio');
    final coverColor = body['coverColor'];
    final error = [
      validateText(title, 'Titulo', max: 120),
      validateText(body['description'], 'Descricao', max: 2000),
      validateText(body['targetAudience'], 'targetAudience', max: 40),
      validateText(body['focus'], 'focus', max: 40),
      (body['difficulty'] == null || validLevels.contains(body['difficulty'])) ? null : 'Dificuldade invalida',
      validateNumber(body['durationMinutes'], 'durationMinutes', min: 1, max: 600, integer: true),
      (coverColor == null || (coverColor is String && isHexColor(coverColor))) ? null : 'coverColor deve ser hexadecimal (RRGGBB)',
    ].firstWhere((e) => e != null, orElse: () => null);
    if (error != null) return ApiResponse.error(error);

    final row = await db.createTraining(
      id: PgStore.newId(),
      authorId: request.userId,
      title: title,
      description: body['description'] as String?,
      targetAudience: body['targetAudience'] as String? ?? 'geral',
      difficulty: body['difficulty'] as String? ?? 'iniciante',
      durationMinutes: toIntOr(body['durationMinutes'], 30),
      focus: body['focus'] as String?,
      coverColor: body['coverColor'] as String? ?? '1DB954',
    );
    return ApiResponse.created(trainingToJson(row));
  });

  return router;
}
