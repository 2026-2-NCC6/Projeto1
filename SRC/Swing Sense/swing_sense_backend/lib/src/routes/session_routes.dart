import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

/// Sessoes de treino. O corpo de POST /:id/events segue o mesmo contrato que
/// a raquete inteligente (ESP32) usara quando estiver pronta: uma lista de
/// eventos com tipo, velocidade da bola (sensor) e angulo/rotacao (giroscopio).
/// Ate la, o app mobile alimenta esta mesma rota com dados gerados pelo
/// MockRacketService, entao trocar o mock pelo hardware real nao muda a API.
Router sessionRoutes(PgStore db) {
  final router = Router();

  const validStatuses = {'in_progress', 'paused', 'completed', 'aborted'};

  // POST /sessions - inicia uma sessao.
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim() ?? 'Treino livre';

    final row = await db.createSession(
      id: PgStore.newId(),
      userId: request.userId,
      trainingId: body['trainingId'] as String?,
      deviceId: body['deviceId'] as String?,
      title: title,
    );
    return ApiResponse.created(sessionToJson(row));
  });

  // GET /sessions/:id
  router.get('/<id>', (Request request, String id) async {
    final session = await db.getSessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.notFound('Sessao nao encontrada');
    }
    return ApiResponse.ok(sessionToJson(session));
  });

  // PATCH /sessions/:id - pausar, retomar, encerrar e atualizar estatisticas.
  router.patch('/<id>', (Request request, String id) async {
    final body = await readJsonBody(request);
    final status = body['status'] as String?;
    if (status != null && !validStatuses.contains(status)) {
      return ApiResponse.error('Status invalido');
    }

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
    final body = await readJsonBody(request);
    final events = body['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) {
      return ApiResponse.error('Envie uma lista "events" com pelo menos um item');
    }

    await db.insertSessionEvents(
      id,
      events.map((rawEvent) {
        final event = rawEvent as Map<String, dynamic>;
        return {
          'eventType': event['eventType'],
          'ballSpeedKmh': toDoubleOrNull(event['ballSpeedKmh']),
          'spinRateRpm': toDoubleOrNull(event['spinRateRpm']),
          'racketAngleDeg': toDoubleOrNull(event['racketAngleDeg']),
        };
      }).toList(),
    );
    return ApiResponse.created({'inserted': events.length});
  });

  // GET /sessions/:id/events
  router.get('/<id>/events', (Request request, String id) async {
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
