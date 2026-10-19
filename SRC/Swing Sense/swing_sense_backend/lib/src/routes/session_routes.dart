import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';
import '../utils/validators.dart';

/// Sessoes de treino. O corpo de POST /:id/events segue o mesmo contrato que
/// a raquete inteligente (ESP32) usara quando estiver pronta: uma lista de
/// eventos com tipo, velocidade da bola (sensor) e angulo/rotacao (giroscopio).
/// Ate la, o app mobile alimenta esta mesma rota com dados gerados pelo
/// MockRacketService, entao trocar o mock pelo hardware real nao muda a API.
///
/// Entrega 2: posse da sessao verificada na ingestao de eventos (R-02) e
/// validacao de tipos/faixas/tamanhos (R-11).
Router sessionRoutes(PgStore db) {
  final router = Router();

  const validStatuses = {'in_progress', 'paused', 'completed', 'aborted'};
  const maxEventsPerRequest = 500;

  // POST /sessions - inicia uma sessao.
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final titleRaw = body['title'];
    final titleError = validateText(titleRaw, 'Titulo', max: 120);
    if (titleError != null) return ApiResponse.error(titleError);
    final title = (titleRaw as String?)?.trim();

    final trainingId = body['trainingId'];
    final deviceId = body['deviceId'];
    if (trainingId != null) {
      if (trainingId is! String || !isUuid(trainingId)) return ApiResponse.error('trainingId invalido');
      if (await db.getTrainingById(trainingId) == null) return ApiResponse.notFound('Treino nao encontrado');
    }
    if (deviceId != null) {
      if (deviceId is! String || !isUuid(deviceId)) return ApiResponse.error('deviceId invalido');
      // O dispositivo precisa pertencer ao usuario autenticado.
      final devices = await db.getDevicesForUser(request.userId);
      if (!devices.any((d) => d['id'].toString() == deviceId.toLowerCase())) {
        return ApiResponse.notFound('Dispositivo nao encontrado');
      }
    }

    final row = await db.createSession(
      id: PgStore.newId(),
      userId: request.userId,
      trainingId: trainingId as String?,
      deviceId: deviceId as String?,
      title: (title == null || title.isEmpty) ? 'Treino livre' : title,
    );
    return ApiResponse.created(sessionToJson(row));
  });

  // GET /sessions/:id
  router.get('/<id>', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.notFound('Sessao nao encontrada');
    final session = await db.getSessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.notFound('Sessao nao encontrada');
    }
    return ApiResponse.ok(sessionToJson(session));
  });

  // PATCH /sessions/:id - pausar, retomar, encerrar e atualizar estatisticas.
  router.patch('/<id>', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.notFound('Sessao nao encontrada');
    final body = await readJsonBody(request);
    final status = body['status'];
    if (status != null && (status is! String || !validStatuses.contains(status))) {
      return ApiResponse.error('Status invalido');
    }

    final errors = <String?>[
      validateNumber(body['durationSeconds'], 'durationSeconds', min: 0, max: 86400, integer: true),
      validateNumber(body['shotCount'], 'shotCount', min: 0, max: 100000, integer: true),
      validateNumber(body['aceCount'], 'aceCount', min: 0, max: 100000, integer: true),
      validateNumber(body['avgBallSpeedKmh'], 'avgBallSpeedKmh', min: 0, max: 400),
      validateNumber(body['maxBallSpeedKmh'], 'maxBallSpeedKmh', min: 0, max: 400),
      validateNumber(body['calories'], 'calories', min: 0, max: 20000, integer: true),
      validateText(body['notes'], 'Notas', max: 2000),
    ];
    final firstError = errors.firstWhere((e) => e != null, orElse: () => null);
    if (firstError != null) return ApiResponse.error(firstError);

    final fields = <String, Object?>{};
    if (status != null) fields['status'] = status;
    if (body['durationSeconds'] != null) fields['duration_seconds'] = toIntOr(body['durationSeconds']);
    if (body['shotCount'] != null) fields['shot_count'] = toIntOr(body['shotCount']);
    if (body['aceCount'] != null) fields['ace_count'] = toIntOr(body['aceCount']);
    if (body['avgBallSpeedKmh'] != null) fields['avg_ball_speed_kmh'] = toDoubleOrNull(body['avgBallSpeedKmh']);
    if (body['maxBallSpeedKmh'] != null) fields['max_ball_speed_kmh'] = toDoubleOrNull(body['maxBallSpeedKmh']);
    if (body['calories'] != null) fields['calories'] = toIntOr(body['calories']);
    if (body['notes'] != null) fields['notes'] = body['notes'];
    if (status == 'completed' || status == 'aborted') fields['ended_at'] = DateTime.now();

    final session = await db.updateSession(id, request.userId, fields);
    if (session == null) return ApiResponse.notFound('Sessao nao encontrada');
    return ApiResponse.ok(sessionToJson(session));
  });

  // POST /sessions/:id/events - ingestao de telemetria (mock ou raquete real).
  router.post('/<id>/events', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.notFound('Sessao nao encontrada');

    // R-02: so o dono da sessao grava telemetria nela (mesmo padrao do GET).
    final session = await db.getSessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.notFound('Sessao nao encontrada');
    }

    final body = await readJsonBody(request);
    final events = body['events'];
    if (events is! List || events.isEmpty) {
      return ApiResponse.error('Envie uma lista "events" com pelo menos um item');
    }
    if (events.length > maxEventsPerRequest) {
      return ApiResponse.error('Maximo de $maxEventsPerRequest eventos por requisicao', status: 413);
    }

    final parsed = <Map<String, Object?>>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event is! Map<String, dynamic>) return ApiResponse.error('Evento $i invalido');

      final type = event['eventType'];
      if (type is! String || !isSlug(type)) return ApiResponse.error('eventType invalido no evento $i');

      final eventError = [
        validateNumber(event['ballSpeedKmh'], 'ballSpeedKmh', min: 0, max: 400),
        validateNumber(event['spinRateRpm'], 'spinRateRpm', min: 0, max: 10000),
        validateNumber(event['racketAngleDeg'], 'racketAngleDeg', min: -360, max: 360),
      ].firstWhere((e) => e != null, orElse: () => null);
      if (eventError != null) return ApiResponse.error('$eventError (evento $i)');

      parsed.add({
        'eventType': type,
        'ballSpeedKmh': toDoubleOrNull(event['ballSpeedKmh']),
        'spinRateRpm': toDoubleOrNull(event['spinRateRpm']),
        'racketAngleDeg': toDoubleOrNull(event['racketAngleDeg']),
      });
    }

    await db.insertSessionEvents(id, parsed);
    return ApiResponse.created({'inserted': parsed.length});
  });

  // GET /sessions/:id/events
  router.get('/<id>/events', (Request request, String id) async {
    if (!isUuid(id)) return ApiResponse.ok([]);
    final session = await db.getSessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.ok([]);
    }
    final events = await db.getSessionEvents(id);
    return ApiResponse.ok(events.map((row) {
      return {
        'id': row['id'],
        'eventType': row['event_type'],
        'ballSpeedKmh': toDoubleOrNull(row['ball_speed_kmh']),
        'spinRateRpm': toDoubleOrNull(row['spin_rate_rpm']),
        'racketAngleDeg': toDoubleOrNull(row['racket_angle_deg']),
        'occurredAt': toIsoOrNull(row['occurred_at']),
      };
    }).toList());
  });

  return router;
}
