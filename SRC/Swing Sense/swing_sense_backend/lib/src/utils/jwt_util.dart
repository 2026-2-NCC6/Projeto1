import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtUtil {
  JwtUtil({required this.secret, required this.expiresInHours});

  final String secret;
  final int expiresInHours;

  String generate({required String userId, required String email, required String role}) {
    final jwt = JWT(
      {'sub': userId, 'email': email, 'role': role},
      issuer: 'smart-sense-api',
    );
    return jwt.sign(SecretKey(secret), expiresIn: Duration(hours: expiresInHours));
  }

  /// Retorna o payload decodificado ou `null` se o token for invalido/expirado.
  Map<String, dynamic>? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      return jwt.payload as Map<String, dynamic>;
    } on JWTExpiredException {
      return null;
    } on JWTException {
      return null;
    }
  }
}
