import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../utils/response.dart';
import '../utils/security_config.dart';

/// Lancada quando o corpo da requisicao excede o limite configurado.
class PayloadTooLargeException implements Exception {
  const PayloadTooLargeException();
}

/// Endereco do cliente. So confia em `X-Forwarded-For` quando `TRUST_PROXY=true`
/// (API atras de proxy reverso/TLS); caso contrario um atacante forjaria o
/// header para fugir do rate limit.
String clientIp(Request request, {bool trustProxy = false}) {
  if (trustProxy) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      // O ultimo valor e o adicionado pelo proxy confiavel mais proximo.
      return forwarded.split(',').last.trim();
    }
  }
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return 'unknown';
}

bool _isSecureRequest(Request request, bool trustProxy) {
  if (request.requestedUri.scheme == 'https') return true;
  return trustProxy && request.headers['x-forwarded-proto'] == 'https';
}

/// R-09 / hardening: cabecalhos de seguranca em todas as respostas.
Middleware securityHeaders(SecurityConfig config) {
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      final headers = <String, String>{
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'Referrer-Policy': 'no-referrer',
        'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
        'Cache-Control': 'no-store',
        'Cross-Origin-Resource-Policy': 'same-site',
      };
      if (config.isProduction || _isSecureRequest(request, config.trustProxy)) {
        headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains';
      }
      return response.change(headers: headers);
    };
  };
}

bool _isLocalDevOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  return (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '[::1]' || uri.host == '::1');
}

/// R-07: CORS com allowlist (`CORS_ALLOWED_ORIGINS`). Clientes nativos
/// (Android/iOS) nao enviam `Origin` e nao sao afetados. Em desenvolvimento,
/// `localhost` continua liberado para o `flutter run -d chrome`.
Middleware corsAllowlist(SecurityConfig config) {
  const allowedMethods = 'GET, POST, PUT, PATCH, DELETE, OPTIONS';
  const allowedHeaders = 'Content-Type, Authorization';

  bool isAllowed(String origin) =>
      config.allowedOrigins.contains(origin) || (!config.isProduction && _isLocalDevOrigin(origin));

  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];

      if (request.method == 'OPTIONS') {
        if (origin == null || !isAllowed(origin)) {
          return Response(403, body: '', headers: {'Vary': 'Origin'});
        }
        return Response(204, headers: {
          'Access-Control-Allow-Origin': origin,
          'Access-Control-Allow-Methods': allowedMethods,
          'Access-Control-Allow-Headers': allowedHeaders,
          'Access-Control-Max-Age': '600',
          'Vary': 'Origin',
        });
      }

      final response = await inner(request);
      if (origin != null && isAllowed(origin)) {
        return response.change(headers: {
          'Access-Control-Allow-Origin': origin,
          'Vary': 'Origin',
        });
      }
      return response.change(headers: {'Vary': 'Origin'});
    };
  };
}

/// R-11: limita o tamanho do corpo (cabecalho `Content-Length` e leitura em
/// streaming, para cobrir `Transfer-Encoding: chunked`).
Middleware bodyLimit(int maxBytes) {
  return (Handler inner) {
    return (Request request) {
      final declared = request.contentLength;
      if (declared != null && declared > maxBytes) {
        return ApiResponse.error('Corpo da requisicao muito grande', status: 413);
      }
      var total = 0;
      final limited = request.read().map((chunk) {
        total += chunk.length;
        if (total > maxBytes) throw const PayloadTooLargeException();
        return chunk;
      });
      return inner(request.change(body: limited));
    };
  };
}

/// Converte excecoes em respostas JSON seguras: nunca devolve stack trace,
/// SQL ou detalhes internos ao cliente (A05/A09).
Middleware errorHandler() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on PayloadTooLargeException {
        return ApiResponse.error('Corpo da requisicao muito grande', status: 413);
      } on FormatException {
        return ApiResponse.error('Corpo da requisicao invalido (JSON malformado)');
      } on TypeError {
        return ApiResponse.error('Campos com tipo invalido');
      } on ServerException catch (e) {
        // 22P02 texto invalido p/ tipo (ex.: UUID), 22003 fora de faixa,
        // 22001 texto longo demais, 23503 chave estrangeira inexistente.
        const clientErrors = {'22P02', '22003', '22001', '22007', '22008', '23503', '23514'};
        if (e.code != null && clientErrors.contains(e.code)) {
          return ApiResponse.error('Dados invalidos');
        }
        stderr.writeln('[erro-db] ${e.code}: ${e.message}');
        return ApiResponse.error('Erro interno', status: 500);
      } on HijackException {
        rethrow;
      } catch (e, st) {
        stderr.writeln('[erro] ${request.method} ${request.requestedUri.path}: $e\n$st');
        return ApiResponse.error('Erro interno', status: 500);
      }
    };
  };
}
