import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

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
    final training = await db.getTrainingById(id);
    if (training == null) return ApiResponse.notFound('Treino nao encontrado');
    return ApiResponse.ok(trainingToJson(training));
  });

  // POST /trainings - qualquer usuario autenticado pode publicar (autor/treinador).
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return ApiResponse.error('Titulo e obrigatorio');

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
