import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

/// Pareamento da raquete inteligente. Enquanto o ESP32 nao existe fisicamente,
/// o app cria um device com is_simulated = true e usa o MockRacketService
/// local para gerar telemetria - o contrato da API ja fica pronto para quando
/// o dispositivo real (BLE/Wi-Fi) existir.
Router deviceRoutes(PgStore db) {
  final router = Router();

  // GET /devices/me
  router.get('/me', (Request request) async {
    final devices = await db.getDevicesForUser(request.userId);
    return ApiResponse.ok(devices.map((d) => deviceToJson(d)).toList());
  });

  // POST /devices/pair
  router.post('/pair', (Request request) async {
    final body = await readJsonBody(request);
    final deviceName = (body['deviceName'] as String?)?.trim() ?? 'Smart Racket';
    final row = await db.pairDevice(
      id: PgStore.newId(),
      userId: request.userId,
      deviceName: deviceName,
      deviceIdentifier: body['deviceIdentifier'] as String? ?? 'SIM-${DateTime.now().millisecondsSinceEpoch}',
      firmwareVersion: body['firmwareVersion'] as String? ?? 'mock-1.0.0',
      isSimulated: body['isSimulated'] as bool? ?? true,
    );
    return ApiResponse.created(deviceToJson(row));
  });

  // PATCH /devices/:id/sync
  router.patch('/<id>/sync', (Request request, String id) async {
    final device = await db.syncDevice(id, request.userId);
    if (device == null) return ApiResponse.notFound('Dispositivo nao encontrado');
    return ApiResponse.ok(deviceToJson(device));
  });

  return router;
}
