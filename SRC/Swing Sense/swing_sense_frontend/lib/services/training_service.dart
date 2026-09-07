import '../models/training.dart';
import 'api_client.dart';

class TrainingService {
  TrainingService(this._client);
  final ApiClient _client;

  Future<List<Training>> list({String? difficulty, String? audience, String? focus}) async {
    final data = await _client.get('/trainings', query: {
      if (difficulty != null) 'difficulty': difficulty,
      if (audience != null) 'audience': audience,
      if (focus != null) 'focus': focus,
    });
    return (data as List).map((e) => Training.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Training> get(String id) async {
    final data = await _client.get('/trainings/$id');
    return Training.fromJson(data as Map<String, dynamic>);
  }
}
