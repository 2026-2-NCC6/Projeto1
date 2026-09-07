import '../models/training_session.dart';
import 'api_client.dart';

class FeedComment {
  FeedComment({required this.id, required this.userName, required this.content, this.userAvatarUrl});
  final String id;
  final String userName;
  final String? userAvatarUrl;
  final String content;

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
        id: json['id'] as String,
        userName: json['userName'] as String? ?? 'Usuario',
        userAvatarUrl: json['userAvatarUrl'] as String?,
        content: json['content'] as String? ?? '',
      );
}

class FeedService {
  FeedService(this._client);
  final ApiClient _client;

  Future<List<TrainingSession>> feed() async {
    final data = await _client.get('/feed');
    return (data as List).map((e) => TrainingSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> like(String sessionId) => _client.post('/feed/$sessionId/like');
  Future<void> unlike(String sessionId) => _client.delete('/feed/$sessionId/like');

  Future<List<FeedComment>> comments(String sessionId) async {
    final data = await _client.get('/feed/$sessionId/comments');
    return (data as List).map((e) => FeedComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FeedComment> comment(String sessionId, String content) async {
    final data = await _client.post('/feed/$sessionId/comments', body: {'content': content});
    return FeedComment.fromJson(data as Map<String, dynamic>);
  }
}
