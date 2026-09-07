import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../utils/response.dart';

/// Rota publica (nao exige autenticacao) com o glossario de regras e
/// fundamentos do tenis exibido para novos usuarios dentro do app.
Router glossaryRoutes(MemoryStore db) {
  final router = Router();

  router.get('/', (Request request) async {
    final category = request.url.queryParameters['category'];
    final terms = db.glossaryTerms.where((t) => category == null || t['category'] == category).toList()
      ..sort((a, b) {
        final orderCompare = (a['sort_order'] as int).compareTo(b['sort_order'] as int);
        if (orderCompare != 0) return orderCompare;
        return (a['term'] as String).compareTo(b['term'] as String);
      });
    return ApiResponse.ok(terms.map((t) => glossaryToJson(t)).toList());
  });

  return router;
}
