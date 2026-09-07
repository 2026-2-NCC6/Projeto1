import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Helpers para respostas JSON padronizadas da API.
class ApiResponse {
  static Response ok(Object? data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response created(Object? data) => ok(data, status: 201);

  static Response noContent() => Response(204);

  static Response error(String message, {int status = 400, Object? details}) {
    return Response(
      status,
      body: jsonEncode({
        'error': message,
        if (details != null) 'details': details,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response notFound([String message = 'Recurso nao encontrado']) =>
      error(message, status: 404);

  static Response unauthorized([String message = 'Nao autenticado']) =>
      error(message, status: 401);

  static Response forbidden([String message = 'Sem permissao para esta acao']) =>
      error(message, status: 403);
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return {};
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw const FormatException('Corpo da requisicao deve ser um objeto JSON');
}
