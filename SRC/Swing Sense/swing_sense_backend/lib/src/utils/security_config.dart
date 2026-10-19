import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'env.dart';

/// Configuracao de seguranca lida das variaveis de ambiente (veja `.env.example`).
///
/// Decisoes principais (Entrega 2 - Redes e Ciberseguranca):
/// * R-01: o segredo JWT nunca tem valor padrao conhecido. Em producao a API
///   se recusa a subir sem um segredo forte; em desenvolvimento gera um segredo
///   aleatorio efemero (tokens deixam de valer ao reiniciar), entao o
///   "plug and play" local continua funcionando sem expor nenhuma chave fixa.
/// * R-07: CORS usa allowlist de origens.
/// * R-08: validade do token limitada (padrao 24 h, maximo 72 h).
class SecurityConfig {
  SecurityConfig({
    required this.isProduction,
    required this.jwtSecret,
    required this.jwtExpiresInHours,
    required this.allowedOrigins,
    required this.trustProxy,
    required this.maxBodyBytes,
  });

  final bool isProduction;
  final String jwtSecret;
  final int jwtExpiresInHours;
  final Set<String> allowedOrigins;
  final bool trustProxy;
  final int maxBodyBytes;

  static const minSecretLength = 32;
  static const maxTokenHours = 72;
  static const defaultTokenHours = 24;

  /// Valores que ja apareceram no repositorio / `.env.example` e portanto
  /// sao publicos: jamais podem ser usados para assinar tokens.
  static const _knownWeakSecrets = {
    'dev-secret-troque-em-producao',
    'troque-este-segredo-antes-de-ir-para-producao',
    'troque-este-segredo',
    'secret',
    'changeme',
  };

  static bool isWeakSecret(String? secret) {
    if (secret == null) return true;
    final s = secret.trim();
    if (s.length < minSecretLength) return true;
    final lower = s.toLowerCase();
    if (_knownWeakSecrets.contains(lower)) return true;
    if (lower.contains('troque') || lower.contains('changeme') || lower.contains('dev-secret')) return true;
    // Todos os caracteres iguais (ex.: "aaaa...") ou muito pouca variedade.
    if (s.split('').toSet().length < 8) return true;
    return false;
  }

  static String generateEphemeralSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static SecurityConfig fromEnv() {
    final appEnv = (env('APP_ENV') ?? 'development').trim().toLowerCase();
    final isProduction = appEnv == 'production' || appEnv == 'prod';

    var secret = env('JWT_SECRET')?.trim();
    if (isWeakSecret(secret)) {
      if (isProduction) {
        throw StateError(
          'JWT_SECRET ausente ou fraco (minimo $minSecretLength caracteres e diferente dos exemplos). '
          'Gere um segredo forte com: openssl rand -base64 48',
        );
      }
      secret = generateEphemeralSecret();
      stderr.writeln(
        '[seguranca] JWT_SECRET ausente/fraco: usando segredo aleatorio TEMPORARIO '
        '(os logins serao invalidados ao reiniciar a API). Defina um segredo forte no .env '
        '(openssl rand -base64 48).',
      );
    }

    var hours = int.tryParse(env('JWT_EXPIRES_IN_HOURS') ?? '') ?? defaultTokenHours;
    if (hours < 1) hours = defaultTokenHours;
    if (hours > maxTokenHours) {
      stderr.writeln('[seguranca] JWT_EXPIRES_IN_HOURS=$hours excede o maximo; usando $maxTokenHours h.');
      hours = maxTokenHours;
    }

    final origins = (env('CORS_ALLOWED_ORIGINS') ?? '')
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty && o != '*')
        .toSet();

    final maxBody = int.tryParse(env('MAX_BODY_BYTES') ?? '') ?? 256 * 1024;

    return SecurityConfig(
      isProduction: isProduction,
      jwtSecret: secret!,
      jwtExpiresInHours: hours,
      allowedOrigins: origins,
      trustProxy: (env('TRUST_PROXY') ?? 'false').toLowerCase() == 'true',
      maxBodyBytes: maxBody,
    );
  }
}
