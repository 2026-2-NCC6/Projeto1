import '../models/glossary_term.dart';
import 'api_client.dart';

class GlossaryService {
  GlossaryService(this._client);
  final ApiClient _client;

  Future<List<GlossaryTerm>> list({String? category}) async {
    final data = await _client.get('/glossary', auth: false, query: {
      if (category != null) 'category': category,
    });
    return (data as List).map((e) => GlossaryTerm.fromJson(e as Map<String, dynamic>)).toList();
  }
}
