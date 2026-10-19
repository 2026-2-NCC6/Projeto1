import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/src/app.dart';
import '../lib/src/db/database.dart';
import '../lib/src/utils/env.dart';
import '../lib/src/utils/security_config.dart';

/// `server --healthcheck`: faz GET /health local e sai com 0/1. Usado pelo
/// HEALTHCHECK do Docker (a imagem final nao tem curl/shell).
Future<void> _healthcheck() async {
  final port = int.tryParse(env('PORT') ?? '8080') ?? 8080;
  final scheme = (env('TLS_CERT_PATH') ?? '').isNotEmpty ? 'https' : 'http';
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..badCertificateCallback = (_, host, __) => host == 'localhost';
  try {
    final request = await client.getUrl(Uri.parse('$scheme://localhost:$port/health'));
    final response = await request.close().timeout(const Duration(seconds: 3));
    exit(response.statusCode == 200 ? 0 : 1);
  } catch (_) {
    exit(1);
  }
}

Future<void> main(List<String> args) async {
  loadDotEnv();

  if (args.contains('--healthcheck')) {
    await _healthcheck();
    return;
  }

  // Falha rapido (antes de abrir o banco) se a configuracao de seguranca for
  // invalida - ex.: JWT_SECRET fraco em producao.
  final config = SecurityConfig.fromEnv();

  final database = await Database.connect();

  final app = buildApp(database, config: config);

  final port = int.parse(env('PORT') ?? '8080');

  // TLS nativo opcional (R-09): defina TLS_CERT_PATH e TLS_KEY_PATH. Em
  // producao e mais comum terminar TLS em um proxy reverso (Caddy/Nginx/
  // plataforma de nuvem) e definir TRUST_PROXY=true.
  final certPath = env('TLS_CERT_PATH');
  final keyPath = env('TLS_KEY_PATH');
  SecurityContext? securityContext;
  if (certPath != null && certPath.isNotEmpty && keyPath != null && keyPath.isNotEmpty) {
    securityContext = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
  } else if (config.isProduction && !config.trustProxy) {
    stderr.writeln(
      '[seguranca] APP_ENV=production sem TLS_CERT_PATH/TLS_KEY_PATH e sem TRUST_PROXY=true: '
      'o trafego chegara em HTTP puro. Use HTTPS (proxy reverso ou TLS nativo).',
    );
  }

  final server = await shelf_io.serve(
    app,
    InternetAddress.anyIPv4,
    port,
    securityContext: securityContext,
  );

  final scheme = securityContext != null ? 'https' : 'http';
  // ignore: avoid_print
  print('Swing Sense API rodando em $scheme://${server.address.host}:${server.port}');
}
