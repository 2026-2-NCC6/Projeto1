import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP fino sobre a API do Swing Sense. Guarda o token JWT em
/// SharedPreferences e o injeta automaticamente nas chamadas autenticadas.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'smart_sense_token';
  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${AppConfig.apiBaseUrl}$cleanPath').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = 'Erro inesperado (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) message = decoded['error'] as String;
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final response = await http
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final response = await http
        .post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final response = await http
        .put(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    final response = await http
        .patch(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final response =
        await http.delete(_uri(path), headers: await _headers(auth: auth)).timeout(const Duration(seconds: 15));
    return _decode(response);
  }
}
