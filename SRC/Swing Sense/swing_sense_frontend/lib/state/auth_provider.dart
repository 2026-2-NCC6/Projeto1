import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider()
      : _authService = AuthService(ApiClient.instance),
        _userService = UserService(ApiClient.instance);

  final AuthService _authService;
  final UserService _userService;

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  Future<void> bootstrap() async {
    final loggedIn = await _authService.isLoggedIn;
    if (!loggedIn) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      currentUser = await _userService.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      await _authService.logout();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    return _runAuthAction(() async {
      currentUser = await _authService.login(email: email, password: password);
    });
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String level,
  }) async {
    return _runAuthAction(() async {
      currentUser = await _authService.register(name: name, email: email, password: password, level: level);
    });
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      status = AuthStatus.authenticated;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('ApiException: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      currentUser = await _userService.me();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
