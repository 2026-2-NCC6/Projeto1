import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Acesso ao PostgreSQL (Supabase) usado pelas rotas. Os nomes das tabelas
/// seguem o schema ja criado no Supabase (em portugues); as colunas usam os
/// mesmos nomes em ingles que `lib/src/mappers.dart` ja espera.
class PgStore {
  PgStore(this.pool);

  final Pool pool;

  static String newId() => _uuid.v4();

  Map<String, dynamic> _row(ResultRow row) => row.toColumnMap();

  List<Map<String, dynamic>> _rows(Result result) => result.map(_row).toList();

  // ---------------------------------------------------------------------
  // usuarios
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final result = await pool.execute(
      Sql.named('SELECT * FROM usuarios WHERE email = @email'),
      parameters: {'email': email},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<Map<String, dynamic>?> getUserById(String? id) async {
    if (id == null) return null;
    final result = await pool.execute(
      Sql.named('SELECT * FROM usuarios WHERE id = @id::uuid'),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<Map<String, dynamic>> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required String level,
    String? birthDate,
    String role = 'player',
  }) async {
    final result = await pool.execute(
      Sql.named('''
        INSERT INTO usuarios (id, name, email, password_hash, avatar_url, bio, level, birth_date, city, role, created_at)
        VALUES (@id::uuid, @name, @email, @passwordHash, NULL, NULL, @level, @birthDate::date, NULL, @role, now())
        RETURNING *
      '''),
      parameters: {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'level': level,
        'birthDate': birthDate,
        'role': role,
      },
    );
    return _row(result.first);
  }

  Future<Map<String, dynamic>?> updateUser(String id, Map<String, Object?> fields) async {
    if (fields.isEmpty) return getUserById(id);
    final setClauses = fields.keys.map((key) => '$key = @$key').join(', ');
    final result = await pool.execute(
      Sql.named('UPDATE usuarios SET $setClauses WHERE id = @id::uuid RETURNING *'),
      parameters: {'id': id, ...fields},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query, String excludeUserId, {int limit = 20}) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT * FROM usuarios
        WHERE id <> @excludeId::uuid AND name ILIKE @pattern
        ORDER BY name
        LIMIT @limit
      '''),
      parameters: {
        'excludeId': excludeUserId,
        'pattern': '%$query%',
        'limit': limit,
      },
    );
    return _rows(result);
  }

  Future<Map<String, dynamic>?> getUserWithStats(String userId, String viewerId) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT u.*,
          (SELECT COUNT(*) FROM seguimentos f WHERE f.following_id = u.id)::int AS followers_count,
          (SELECT COUNT(*) FROM seguimentos f WHERE f.follower_id = u.id)::int AS following_count,
          (SELECT COUNT(*) FROM sessoes_treinamento s WHERE s.user_id = u.id AND s.status = 'completed')::int AS sessions_count,
          EXISTS(
            SELECT 1 FROM seguimentos f WHERE f.follower_id = @viewerId::uuid AND f.following_id = u.id
          ) AS followed_by_me
        FROM usuarios u
        WHERE u.id = @userId::uuid
      '''),
      parameters: {'userId': userId, 'viewerId': viewerId},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  // ---------------------------------------------------------------------
  // seguimentos
  // ---------------------------------------------------------------------

  Future<bool> isFollowing(String followerId, String followingId) async {
    final result = await pool.execute(
      Sql.named('SELECT 1 FROM seguimentos WHERE follower_id = @followerId::uuid AND following_id = @followingId::uuid'),
      parameters: {'followerId': followerId, 'followingId': followingId},
    );
    return result.isNotEmpty;
  }

  Future<void> follow(String followerId, String followingId) async {
    await pool.execute(
      Sql.named('''
        INSERT INTO seguimentos (follower_id, following_id, created_at)
        VALUES (@followerId::uuid, @followingId::uuid, now())
        ON CONFLICT (follower_id, following_id) DO NOTHING
      '''),
      parameters: {'followerId': followerId, 'followingId': followingId},
    );
  }

  Future<void> unfollow(String followerId, String followingId) async {
    await pool.execute(
      Sql.named('DELETE FROM seguimentos WHERE follower_id = @followerId::uuid AND following_id = @followingId::uuid'),
      parameters: {'followerId': followerId, 'followingId': followingId},
    );
  }

  Future<List<String>> followingIdsOf(String userId) async {
    final result = await pool.execute(
      Sql.named('SELECT following_id FROM seguimentos WHERE follower_id = @userId::uuid'),
      parameters: {'userId': userId},
    );
    return result.map((r) => r[0] as String).toList();
  }

  // ---------------------------------------------------------------------
  // dispositivos
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getDevicesForUser(String userId) async {
    final result = await pool.execute(
      Sql.named('SELECT * FROM dispositivos WHERE user_id = @userId::uuid ORDER BY paired_at DESC'),
      parameters: {'userId': userId},
    );
    return _rows(result);
  }

  Future<Map<String, dynamic>> pairDevice({
    required String id,
    required String userId,
    required String deviceName,
    required String deviceIdentifier,
    String? firmwareVersion,
    required bool isSimulated,
  }) async {
    final result = await pool.execute(
      Sql.named('''
        INSERT INTO dispositivos (id, user_id, device_name, device_identifier, firmware_version, is_simulated, paired_at, last_sync_at)
        VALUES (@id::uuid, @userId::uuid, @deviceName, @deviceIdentifier, @firmwareVersion, @isSimulated, now(), NULL)
        RETURNING *
      '''),
      parameters: {
        'id': id,
        'userId': userId,
        'deviceName': deviceName,
        'deviceIdentifier': deviceIdentifier,
        'firmwareVersion': firmwareVersion,
        'isSimulated': isSimulated,
      },
    );
    return _row(result.first);
  }

  Future<Map<String, dynamic>?> syncDevice(String id, String userId) async {
    final result = await pool.execute(
      Sql.named('''
        UPDATE dispositivos SET last_sync_at = now()
        WHERE id = @id::uuid AND user_id = @userId::uuid
        RETURNING *
      '''),
      parameters: {'id': id, 'userId': userId},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  // ---------------------------------------------------------------------
  // treinamentos
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getTrainings({String? difficulty, String? audience, String? focus}) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT t.*, u.name AS author_name
        FROM treinamentos t
        LEFT JOIN usuarios u ON u.id = t.author_id
        WHERE t.is_published = true
          AND (@difficulty::text IS NULL OR t.difficulty = @difficulty)
          AND (@audience::text IS NULL OR t.target_audience = @audience)
          AND (@focus::text IS NULL OR t.focus = @focus)
        ORDER BY t.created_at DESC
      '''),
      parameters: {'difficulty': difficulty, 'audience': audience, 'focus': focus},
    );
    return _rows(result);
  }

  Future<Map<String, dynamic>?> getTrainingById(String id) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT t.*, u.name AS author_name
        FROM treinamentos t
        LEFT JOIN usuarios u ON u.id = t.author_id
        WHERE t.id = @id::uuid
      '''),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<Map<String, dynamic>> createTraining({
    required String id,
    String? authorId,
    required String title,
    String? description,
    required String targetAudience,
    required String difficulty,
    required int durationMinutes,
    String? focus,
    required String coverColor,
  }) async {
    await pool.execute(
      Sql.named('''
        INSERT INTO treinamentos
          (id, author_id, title, description, target_audience, difficulty, duration_minutes, focus, cover_color, is_published, version, created_at)
        VALUES
          (@id::uuid, @authorId::uuid, @title, @description, @targetAudience, @difficulty, @durationMinutes, @focus, @coverColor, true, 1, now())
      '''),
      parameters: {
        'id': id,
        'authorId': authorId,
        'title': title,
        'description': description,
        'targetAudience': targetAudience,
        'difficulty': difficulty,
        'durationMinutes': durationMinutes,
        'focus': focus,
        'coverColor': coverColor,
      },
    );
    return (await getTrainingById(id))!;
  }

  // ---------------------------------------------------------------------
  // sessoes_treinamento
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>?> getSessionById(String id) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT s.*, t.title AS training_title
        FROM sessoes_treinamento s
        LEFT JOIN treinamentos t ON t.id = s.training_id
        WHERE s.id = @id::uuid
      '''),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<Map<String, dynamic>> createSession({
    required String id,
    required String userId,
    String? trainingId,
    String? deviceId,
    required String title,
  }) async {
    await pool.execute(
      Sql.named('''
        INSERT INTO sessoes_treinamento
          (id, user_id, training_id, device_id, title, status, started_at, ended_at,
           duration_seconds, shot_count, ace_count, avg_ball_speed_kmh, max_ball_speed_kmh, calories, notes, created_at)
        VALUES
          (@id::uuid, @userId::uuid, @trainingId::uuid, @deviceId::uuid, @title, 'in_progress', now(), NULL,
           0, 0, 0, NULL, NULL, NULL, NULL, now())
      '''),
      parameters: {
        'id': id,
        'userId': userId,
        'trainingId': trainingId,
        'deviceId': deviceId,
        'title': title,
      },
    );
    return (await getSessionById(id))!;
  }

  Future<Map<String, dynamic>?> updateSession(String id, String userId, Map<String, Object?> fields) async {
    if (fields.isEmpty) {
      final session = await getSessionById(id);
      return session != null && session['user_id'] == userId ? session : null;
    }
    final setClauses = fields.keys.map((key) => '$key = @$key').join(', ');
    final result = await pool.execute(
      Sql.named('''
        UPDATE sessoes_treinamento SET $setClauses
        WHERE id = @id::uuid AND user_id = @userId::uuid
        RETURNING id
      '''),
      parameters: {'id': id, 'userId': userId, ...fields},
    );
    if (result.isEmpty) return null;
    return getSessionById(id);
  }

  Future<void> insertSessionEvents(String sessionId, List<Map<String, Object?>> events) async {
    await pool.runTx((session) async {
      for (final event in events) {
        await session.execute(
          Sql.named('''
            INSERT INTO eventos_sessao (id, session_id, event_type, ball_speed_kmh, spin_rate_rpm, racket_angle_deg, occurred_at)
            VALUES (@id::uuid, @sessionId::uuid, @eventType, @ballSpeedKmh, @spinRateRpm, @racketAngleDeg, now())
          '''),
          parameters: {
            'id': newId(),
            'sessionId': sessionId,
            'eventType': event['eventType'],
            'ballSpeedKmh': event['ballSpeedKmh'],
            'spinRateRpm': event['spinRateRpm'],
            'racketAngleDeg': event['racketAngleDeg'],
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSessionEvents(String sessionId) async {
    final result = await pool.execute(
      Sql.named('SELECT * FROM eventos_sessao WHERE session_id = @sessionId::uuid ORDER BY occurred_at ASC'),
      parameters: {'sessionId': sessionId},
    );
    return _rows(result);
  }

  // ---------------------------------------------------------------------
  // feed: sessoes_treinamento + curtidas_sessao + comentarios_sessao
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFeedSessions(String me) async {
    final followingIds = await followingIdsOf(me);
    final params = <String, Object?>{'me': me};
    final idPlaceholders = <String>['@me::uuid'];
    for (var i = 0; i < followingIds.length; i++) {
      final key = 'f$i';
      params[key] = followingIds[i];
      idPlaceholders.add('@$key::uuid');
    }

    final result = await pool.execute(
      Sql.named('''
        SELECT s.*, t.title AS training_title, u.name AS user_name, u.avatar_url AS user_avatar_url,
          (SELECT COUNT(*) FROM curtidas_sessao cl WHERE cl.session_id = s.id)::int AS like_count,
          (SELECT COUNT(*) FROM comentarios_sessao cm WHERE cm.session_id = s.id)::int AS comment_count,
          EXISTS(SELECT 1 FROM curtidas_sessao cl2 WHERE cl2.session_id = s.id AND cl2.user_id = @me::uuid) AS liked_by_me
        FROM sessoes_treinamento s
        LEFT JOIN treinamentos t ON t.id = s.training_id
        LEFT JOIN usuarios u ON u.id = s.user_id
        WHERE s.status = 'completed' AND s.user_id IN (${idPlaceholders.join(', ')})
        ORDER BY s.started_at DESC
        LIMIT 50
      '''),
      parameters: params,
    );
    return _rows(result);
  }

  Future<List<Map<String, dynamic>>> getUserSessions(String userId, String viewerId) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT s.*, t.title AS training_title,
          (SELECT COUNT(*) FROM curtidas_sessao cl WHERE cl.session_id = s.id)::int AS like_count,
          (SELECT COUNT(*) FROM comentarios_sessao cm WHERE cm.session_id = s.id)::int AS comment_count,
          EXISTS(SELECT 1 FROM curtidas_sessao cl2 WHERE cl2.session_id = s.id AND cl2.user_id = @viewerId::uuid) AS liked_by_me
        FROM sessoes_treinamento s
        LEFT JOIN treinamentos t ON t.id = s.training_id
        WHERE s.user_id = @userId::uuid AND s.status = 'completed'
        ORDER BY s.started_at DESC
        LIMIT 50
      '''),
      parameters: {'userId': userId, 'viewerId': viewerId},
    );
    return _rows(result);
  }

  Future<void> likeSession(String sessionId, String userId) async {
    await pool.execute(
      Sql.named('''
        INSERT INTO curtidas_sessao (session_id, user_id, created_at)
        VALUES (@sessionId::uuid, @userId::uuid, now())
        ON CONFLICT (session_id, user_id) DO NOTHING
      '''),
      parameters: {'sessionId': sessionId, 'userId': userId},
    );
  }

  Future<void> unlikeSession(String sessionId, String userId) async {
    await pool.execute(
      Sql.named('DELETE FROM curtidas_sessao WHERE session_id = @sessionId::uuid AND user_id = @userId::uuid'),
      parameters: {'sessionId': sessionId, 'userId': userId},
    );
  }

  Future<List<Map<String, dynamic>>> getComments(String sessionId) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT c.*, u.name AS user_name, u.avatar_url AS user_avatar_url
        FROM comentarios_sessao c
        LEFT JOIN usuarios u ON u.id = c.user_id
        WHERE c.session_id = @sessionId::uuid
        ORDER BY c.created_at ASC
      '''),
      parameters: {'sessionId': sessionId},
    );
    return _rows(result);
  }

  Future<Map<String, dynamic>> addComment({
    required String id,
    required String sessionId,
    required String userId,
    required String content,
  }) async {
    await pool.execute(
      Sql.named('''
        INSERT INTO comentarios_sessao (id, session_id, user_id, content, created_at)
        VALUES (@id::uuid, @sessionId::uuid, @userId::uuid, @content, now())
      '''),
      parameters: {'id': id, 'sessionId': sessionId, 'userId': userId, 'content': content},
    );
    final result = await pool.execute(
      Sql.named('''
        SELECT c.*, u.name AS user_name, u.avatar_url AS user_avatar_url
        FROM comentarios_sessao c
        LEFT JOIN usuarios u ON u.id = c.user_id
        WHERE c.id = @id::uuid
      '''),
      parameters: {'id': id},
    );
    return _row(result.first);
  }

  // ---------------------------------------------------------------------
  // metas
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getGoalsForUser(String userId) async {
    final result = await pool.execute(
      Sql.named('SELECT * FROM metas WHERE user_id = @userId::uuid ORDER BY created_at DESC'),
      parameters: {'userId': userId},
    );
    return _rows(result);
  }

  Future<Map<String, dynamic>> createGoal({
    required String id,
    required String userId,
    required String type,
    required String title,
    required double targetValue,
    required double currentValue,
    required String unit,
    String? deadline,
  }) async {
    final result = await pool.execute(
      Sql.named('''
        INSERT INTO metas (id, user_id, type, title, target_value, current_value, unit, deadline, status, created_at)
        VALUES (@id::uuid, @userId::uuid, @type, @title, @targetValue, @currentValue, @unit, @deadline::date, 'active', now())
        RETURNING *
      '''),
      parameters: {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'unit': unit,
        'deadline': deadline,
      },
    );
    return _row(result.first);
  }

  Future<Map<String, dynamic>?> getGoalById(String id, String userId) async {
    final result = await pool.execute(
      Sql.named('SELECT * FROM metas WHERE id = @id::uuid AND user_id = @userId::uuid'),
      parameters: {'id': id, 'userId': userId},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<Map<String, dynamic>?> updateGoal(String id, String userId, Map<String, Object?> fields) async {
    if (fields.isEmpty) return getGoalById(id, userId);
    final setClauses = fields.keys.map((key) => '$key = @$key').join(', ');
    final result = await pool.execute(
      Sql.named('''
        UPDATE metas SET $setClauses
        WHERE id = @id::uuid AND user_id = @userId::uuid
        RETURNING *
      '''),
      parameters: {'id': id, 'userId': userId, ...fields},
    );
    return result.isEmpty ? null : _row(result.first);
  }

  Future<void> deleteGoal(String id, String userId) async {
    await pool.execute(
      Sql.named('DELETE FROM metas WHERE id = @id::uuid AND user_id = @userId::uuid'),
      parameters: {'id': id, 'userId': userId},
    );
  }

  // ---------------------------------------------------------------------
  // termos_glossario
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getGlossaryTerms({String? category}) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT * FROM termos_glossario
        WHERE (@category::text IS NULL OR category = @category)
        ORDER BY sort_order ASC, term ASC
      '''),
      parameters: {'category': category},
    );
    return _rows(result);
  }
}
