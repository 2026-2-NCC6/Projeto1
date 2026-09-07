import '../models/goal.dart';
import 'api_client.dart';

class GoalService {
  GoalService(this._client);
  final ApiClient _client;

  Future<List<Goal>> list() async {
    final data = await _client.get('/goals');
    return (data as List).map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Goal> create({
    required String type,
    required String title,
    required double targetValue,
    String unit = 'un',
    DateTime? deadline,
  }) async {
    final data = await _client.post('/goals', body: {
      'type': type,
      'title': title,
      'targetValue': targetValue,
      'unit': unit,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return Goal.fromJson(data as Map<String, dynamic>);
  }

  Future<Goal> updateProgress(String id, {double? currentValue, String? status}) async {
    final data = await _client.patch('/goals/$id', body: {
      if (currentValue != null) 'currentValue': currentValue,
      if (status != null) 'status': status,
    });
    return Goal.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.delete('/goals/$id');
}
