import '../models/training_session.dart';
import '../models/user.dart';
import 'api_client.dart';

class UserService {
  UserService(this._client);
  final ApiClient _client;

  Future<AppUser> me() async {
    final data = await _client.get('/users/me');
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> getUser(String id) async {
    final data = await _client.get('/users/$id');
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({String? name, String? bio, String? level, String? city, String? avatarUrl}) async {
    final data = await _client.put('/users/me', body: {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (level != null) 'level': level,
      if (city != null) 'city': city,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AppUser>> search(String query) async {
    final data = await _client.get('/users/search', query: {'q': query});
    return (data as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> follow(String userId) => _client.post('/users/$userId/follow');
  Future<void> unfollow(String userId) => _client.delete('/users/$userId/follow');

  Future<List<TrainingSession>> sessionsOf(String userId) async {
    final data = await _client.get('/users/$userId/sessions');
    return (data as List).map((e) => TrainingSession.fromJson(e as Map<String, dynamic>)).toList();
  }
}
