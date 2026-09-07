import '../models/session_event.dart';
import '../models/training_session.dart';
import 'api_client.dart';

class SessionService {
  SessionService(this._client);
  final ApiClient _client;

  Future<TrainingSession> start({String? trainingId, String? deviceId, String title = 'Treino livre'}) async {
    final data = await _client.post('/sessions', body: {
      if (trainingId != null) 'trainingId': trainingId,
      if (deviceId != null) 'deviceId': deviceId,
      'title': title,
    });
    return TrainingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<TrainingSession> update(
    String id, {
    String? status,
    int? durationSeconds,
    int? shotCount,
    int? aceCount,
    double? avgBallSpeedKmh,
    double? maxBallSpeedKmh,
    int? calories,
    String? notes,
  }) async {
    final data = await _client.patch('/sessions/$id', body: {
      if (status != null) 'status': status,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (shotCount != null) 'shotCount': shotCount,
      if (aceCount != null) 'aceCount': aceCount,
      if (avgBallSpeedKmh != null) 'avgBallSpeedKmh': avgBallSpeedKmh,
      if (maxBallSpeedKmh != null) 'maxBallSpeedKmh': maxBallSpeedKmh,
      if (calories != null) 'calories': calories,
      if (notes != null) 'notes': notes,
    });
    return TrainingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<void> sendEvents(String sessionId, List<SessionEvent> events) {
    return _client.post('/sessions/$sessionId/events', body: {
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  Future<TrainingSession> get(String id) async {
    final data = await _client.get('/sessions/$id');
    return TrainingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SessionEvent>> getEvents(String id) async {
    final data = await _client.get('/sessions/$id/events');
    return (data as List).map((e) => SessionEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
}
