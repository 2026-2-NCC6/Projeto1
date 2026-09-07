import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/memory_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

/// Sessoes de treino. O corpo de POST /:id/events segue o mesmo contrato que
/// a raquete inteligente (ESP32) usara quando estiver pronta: uma lista de
/// eventos com tipo, velocidade da bola (sensor) e angulo/rotacao (giroscopio).
/// Ate la, o app mobile alimenta esta mesma rota com dados gerados pelo
/// MockRacketService, entao trocar o mock pelo hardware real nao muda a API.
Router sessionRoutes(MemoryStore db) {
  final router = Router();

  const validStatuses = {'in_progress', 'paused', 'completed', 'aborted'};

  // POST /sessions - inicia uma sessao.
  router.post('/', (Request request) async {
    final body = await readJsonBody(request);
    final title = (body['title'] as String?)?.trim() ?? 'Treino livre';

    final row = {
      'id': MemoryStore.newId(),
      'user_id': request.userId,
      'training_id': body['trainingId'],
      'device_id': body['deviceId'],
      'title': title,
      'status': 'in_progress',
      'started_at': DateTime.now(),
      'ended_at': null,
      'duration_seconds': 0,
      'shot_count': 0,
      'ace_count': 0,
      'avg_ball_speed_kmh': null,
      'max_ball_speed_kmh': null,
      'calories': null,
      'notes': null,
      'created_at': DateTime.now(),
    };
    db.trainingSessions.add(row);
    return ApiResponse.created(sessionToJson(db.hydrateSession(row)));
  });

  // GET /sessions/:id
  router.get('/<id>', (Request request, String id) async {
    final session = db.sessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.notFound('Sessao nao encontrada');
    }
    return ApiResponse.ok(sessionToJson(db.hydrateSession(session)));
  });

  // PATCH /sessions/:id - pausar, retomar, encerrar e atualizar estatisticas.
  router.patch('/<id>', (Request request, String id) async {
    final body = await readJsonBody(request);
    final status = body['status'] as String?;
    if (status != null && !validStatuses.contains(status)) {
      return ApiResponse.error('Status invalido');
    }

    final session = db.sessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.notFound('Sessao nao encontrada');
    }

    if (status != null) session['status'] = status;
    if (body['durationSeconds'] != null) session['duration_seconds'] = body['durationSeconds'];
    if (body['shotCount'] != null) session['shot_count'] = body['shotCount'];
    if (body['aceCount'] != null) session['ace_count'] = body['aceCount'];
    if (body['avgBallSpeedKmh'] != null) session['avg_ball_speed_kmh'] = body['avgBallSpeedKmh'];
    if (body['maxBallSpeedKmh'] != null) session['max_ball_speed_kmh'] = body['maxBallSpeedKmh'];
    if (body['calories'] != null) session['calories'] = body['calories'];
    if (body['notes'] != null) session['notes'] = body['notes'];
    if (status == 'completed' || status == 'aborted') session['ended_at'] = DateTime.now();

    return ApiResponse.ok(sessionToJson(db.hydrateSession(session)));
  });

  // POST /sessions/:id/events - ingestao de telemetria (mock ou raquete real).
  router.post('/<id>/events', (Request request, String id) async {
    final body = await readJsonBody(request);
    final events = body['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) {
      return ApiResponse.error('Envie uma lista "events" com pelo menos um item');
    }

    for (final rawEvent in events) {
      final event = rawEvent as Map<String, dynamic>;
      db.sessionEvents.add({
        'id': MemoryStore.newId(),
        'session_id': id,
        'event_type': event['eventType'],
        'ball_speed_kmh': event['ballSpeedKmh'],
        'spin_rate_rpm': event['spinRateRpm'],
        'racket_angle_deg': event['racketAngleDeg'],
        'occurred_at': DateTime.now(),
      });
    }
    return ApiResponse.created({'inserted': events.length});
  });

  // GET /sessions/:id/events
  router.get('/<id>/events', (Request request, String id) async {
    final session = db.sessionById(id);
    if (session == null || session['user_id'] != request.userId) {
      return ApiResponse.ok([]);
    }
    final events = db.sessionEvents.where((e) => e['session_id'] == id).toList()
      ..sort((a, b) => (a['occurred_at'] as DateTime).compareTo(b['occurred_at'] as DateTime));
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
