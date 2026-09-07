import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// URL base da API. No emulador Android, `localhost` da maquina host e
  /// acessado via `10.0.2.2`; no simulador iOS e em Web, `localhost` funciona
  /// normalmente. Ajuste aqui se o backend estiver rodando em outra maquina
  /// (ex.: IP da sua rede local) para testar em um aparelho fisico.
  ///
  /// Usa `defaultTargetPlatform` (em vez de `dart:io Platform`) porque este
  /// getter tambem roda em Web, onde `dart:io` nao esta disponivel.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
