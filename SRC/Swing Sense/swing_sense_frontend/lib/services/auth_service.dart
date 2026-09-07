import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String level = 'iniciante',
  }) async {
    final data = await _client.post('/auth/register', auth: false, body: {
      'name': name,
      'email': email,
      'password': password,
      'level': level,
    });
    await _client.saveToken(data['token'] as String);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final data = await _client.post('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
    });
    await _client.saveToken(data['token'] as String);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => _client.clearToken();

  Future<bool> get isLoggedIn async => (await _client.token) != null;
}
