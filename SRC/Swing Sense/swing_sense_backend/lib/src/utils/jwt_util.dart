import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

/// Emissao/validacao de JWT (HS256).
///
/// Entrega 2 (R-08): cada token carrega um `jti` unico e a API mantem uma
/// lista de revogacao em memoria (`revoke`), usada por `POST /auth/logout`.
/// A lista guarda cada `jti` apenas ate o `exp` do token, entao nao cresce
/// indefinidamente. Ela e perdida ao reiniciar a API - o que, como o tempo de
/// vida do token agora e curto (padrao 24 h), limita a janela de exposicao.
class JwtUtil {
  JwtUtil({required this.secret, required this.expiresInHours, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const issuer = 'smart-sense-api';
  static const _uuid = Uuid();

  final String secret;
  final int expiresInHours;
  final DateTime Function() _now;

  /// jti -> instante (epoch seconds) em que o token expira naturalmente.
  final Map<String, int> _revoked = {};

  String generate({required String userId, required String email, required String role}) {
    final jwt = JWT(
      {'sub': userId, 'email': email, 'role': role},
      issuer: issuer,
      jwtId: _uuid.v4(),
    );
    return jwt.sign(SecretKey(secret), expiresIn: Duration(hours: expiresInHours));
  }

  /// Retorna o payload decodificado ou `null` se o token for invalido,
  /// expirado, de outro emissor ou revogado.
  Map<String, dynamic>? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret), issuer: issuer);
      final payload = jwt.payload;
      if (payload is! Map<String, dynamic>) return null;
      if (payload['sub'] is! String || payload['email'] is! String || payload['role'] is! String) {
        return null;
      }
      final jti = payload['jti'];
      if (jti is! String) return null;
      _purgeExpired();
      if (_revoked.containsKey(jti)) return null;
      return payload;
    } on JWTException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Invalida o token (logout). Idempotente; tokens invalidos sao ignorados.
  bool revoke(String token) {
    final payload = verify(token);
    if (payload == null) return false;
    final exp = payload['exp'];
    _revoked[payload['jti'] as String] = exp is int ? exp : _now().millisecondsSinceEpoch ~/ 1000 + expiresInHours * 3600;
    return true;
  }

  void _purgeExpired() {
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    _revoked.removeWhere((_, exp) => exp <= nowSeconds);
  }
}
