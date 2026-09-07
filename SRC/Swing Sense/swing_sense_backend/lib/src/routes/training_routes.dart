import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router trainingRoutes(MemoryStore db) {
  final router = Router();

  Map<String, dynamic> hydrate(Map<String, dynamic> training) {
    final author = db.userById(training['author_id'] as String?);
    return {...training, 'author_name': author?['name']};
  }

  // GET /trainings?difficulty=&audience=&focus=
  router.get('/', (Request request) async {
    final params = request.url.queryParameters;
    final difficulty = params['difficulty'];
    final audience = params['audience'];
    final focus = params['focus'];

    final trainings = db.trainings.where((t) {
      if (t['is_published'] != true) return false;
      if (difficulty != null && t['difficulty'] != difficulty) return false;
      if (audience != null && t['target_audience'] != audience) return false;
      if (focus != null && t['focus'] != focus) return false;
      return true;
    }).toList()
      ..sort((a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));

    return ApiResponse.ok(trainings.map((t) => trainingToJson(hydrate(t))).toList());
  });

  // GET /trainings/:id
  router.get('/<id>', (Request request, String id) async {
    final training = db.trainingById(id);
    if (training == null) return ApiResponse.notFound('Treino nao encontrado');
    return ApiResponse.ok(trainingToJson(hydrate(training)));
  });

  // POST /trainings - qualquer usuario autenticado pode publicar (autor/treinador).
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return ApiResponse.error('Titulo e obrigatorio');

    final row = {
      'id': MemoryStore.newId(),
      'author_id': request.userId,
      'title': title,
      'description': body['description'],
      'target_audience': body['targetAudience'] ?? 'geral',
      'difficulty': body['difficulty'] ?? 'iniciante',
      'duration_minutes': body['durationMinutes'] ?? 30,
      'focus': body['focus'],
      'cover_color': body['coverColor'] ?? '1DB954',
      'is_published': true,
      'version': 1,
      'created_at': DateTime.now(),
    };
    db.trainings.add(row);
    return ApiResponse.created(trainingToJson(hydrate(row)));
  });

  return router;
}
