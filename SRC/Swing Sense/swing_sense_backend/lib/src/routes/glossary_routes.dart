import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../utils/response.dart';

/// Rota publica (nao exige autenticacao) com o glossario de regras e
/// fundamentos do tenis exibido para novos usuarios dentro do app.
Router glossaryRoutes(PgStore db) {
  final router = Router();

  router.get('/', (Request request) async {
    final category = request.url.queryParameters['category'];
    final terms = await db.getGlossaryTerms(category: category);
    return ApiResponse.ok(terms.map((t) => glossaryToJson(t)).toList());
  });

  return router;
}
