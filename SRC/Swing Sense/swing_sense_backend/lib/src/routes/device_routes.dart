import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

/// Pareamento da raquete inteligente. Enquanto o ESP32 nao existe fisicamente,
/// o app cria um device com is_simulated = true e usa o MockRacketService
/// local para gerar telemetria - o contrato da API ja fica pronto para quando
/// o dispositivo real (BLE/Wi-Fi) existir.
Router deviceRoutes(MemoryStore db) {
  final router = Router();

  // GET /devices/me
  router.get('/me', (Request request) async {
    final devices = db.devices.where((d) => d['user_id'] == request.userId).toList()
      ..sort((a, b) => (b['paired_at'] as DateTime).compareTo(a['paired_at'] as DateTime));
    return ApiResponse.ok(devices.map((d) => deviceToJson(d)).toList());
  });

  // POST /devices/pair
  router.post('/pair', (Request request) async {
    final body = await readJsonBody(request);
    final deviceName = (body['deviceName'] as String?)?.trim() ?? 'Smart Racket';
    final row = {
      'id': MemoryStore.newId(),
      'user_id': request.userId,
      'device_name': deviceName,
      'device_identifier': body['deviceIdentifier'] ?? 'SIM-${DateTime.now().millisecondsSinceEpoch}',
      'firmware_version': body['firmwareVersion'] ?? 'mock-1.0.0',
      'is_simulated': body['isSimulated'] ?? true,
      'paired_at': DateTime.now(),
      'last_sync_at': null,
    };
    db.devices.add(row);
    return ApiResponse.created(deviceToJson(row));
  });

  // PATCH /devices/:id/sync
  router.patch('/<id>/sync', (Request request, String id) async {
    Map<String, dynamic>? device;
    for (final d in db.devices) {
      if (d['id'] == id && d['user_id'] == request.userId) {
        device = d;
        break;
      }
    }
    if (device == null) return ApiResponse.notFound('Dispositivo nao encontrado');
    device['last_sync_at'] = DateTime.now();
    return ApiResponse.ok(deviceToJson(device));
  });

  return router;
}
