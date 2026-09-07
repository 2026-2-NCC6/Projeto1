import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/src/app.dart';
import '../lib/src/db/database.dart';

Future<void> main() async {
  final database = await Database.connect();

  final app = buildApp(database);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(app, InternetAddress.anyIPv4, port);

  // ignore: avoid_print
  print('Swing Sense API rodando em http://${server.address.host}:${server.port}');
}
