import '../models/user.dart';
import 'api_client.dart';
import 'tacada_sync_service.dart';

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

  /// Revoga o token no servidor (R-08) em modo "melhor esforco": se estiver
  /// offline, o logout local acontece mesmo assim.
  Future<void> logout() async {
    // Envia (ou descarta) tacadas pendentes antes de trocar de usuario.
    await TacadaSyncService.instance.flushAndClear();
    try {
      if (await _client.token != null) {
        await _client.post('/auth/logout').timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      // ignorado: o token local e descartado de qualquer forma.
    }
    await _client.clearToken();
  }

  Future<bool> get isLoggedIn async => (await _client.token) != null;
}
