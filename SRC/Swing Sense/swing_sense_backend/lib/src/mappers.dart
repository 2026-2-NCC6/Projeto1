/// Conversoes seguras de valores vindos do driver do Postgres (que podem
/// chegar como int, double ou String dependendo do tipo da coluna) para os
/// tipos que a API expoe no JSON.
double? toDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int toIntOr(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String? toIsoOrNull(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

Map<String, dynamic> userSummaryToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'avatarUrl': row['avatar_url'],
    'level': row['level'],
  };
}

Map<String, dynamic> userToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'email': row['email'],
    'avatarUrl': row['avatar_url'],
    'bio': row['bio'],
    'level': row['level'],
    'birthDate': toIsoOrNull(row['birth_date']),
    'city': row['city'],
    'role': row['role'],
    'createdAt': toIsoOrNull(row['created_at']),
  };
}

Map<String, dynamic> trainingToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'authorId': row['author_id'],
    'authorName': row['author_name'],
    'title': row['title'],
    'description': row['description'],
    'targetAudience': row['target_audience'],
    'difficulty': row['difficulty'],
    'durationMinutes': toIntOr(row['duration_minutes']),
    'focus': row['focus'],
    'coverColor': row['cover_color'],
    'isPublished': row['is_published'],
    'version': row['version'],
    'createdAt': toIsoOrNull(row['created_at']),
  };
}

Map<String, dynamic> sessionToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'userId': row['user_id'],
    'trainingId': row['training_id'],
    'trainingTitle': row['training_title'],
    'deviceId': row['device_id'],
    'title': row['title'],
    'status': row['status'],
    'startedAt': toIsoOrNull(row['started_at']),
    'endedAt': toIsoOrNull(row['ended_at']),
    'durationSeconds': toIntOr(row['duration_seconds']),
    'shotCount': toIntOr(row['shot_count']),
    'aceCount': toIntOr(row['ace_count']),
    'avgBallSpeedKmh': toDoubleOrNull(row['avg_ball_speed_kmh']),
    'maxBallSpeedKmh': toDoubleOrNull(row['max_ball_speed_kmh']),
    'calories': row['calories'] == null ? null : toIntOr(row['calories']),
    'notes': row['notes'],
    if (row.containsKey('user_name')) 'userName': row['user_name'],
    if (row.containsKey('user_avatar_url')) 'userAvatarUrl': row['user_avatar_url'],
    if (row.containsKey('like_count')) 'likeCount': toIntOr(row['like_count']),
    if (row.containsKey('comment_count')) 'commentCount': toIntOr(row['comment_count']),
    if (row.containsKey('liked_by_me')) 'likedByMe': row['liked_by_me'],
  };
}

Map<String, dynamic> goalToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'userId': row['user_id'],
    'type': row['type'],
    'title': row['title'],
    'targetValue': toDoubleOrNull(row['target_value']),
    'currentValue': toDoubleOrNull(row['current_value']),
    'unit': row['unit'],
    'deadline': toIsoOrNull(row['deadline']),
    'status': row['status'],
    'createdAt': toIsoOrNull(row['created_at']),
  };
}

Map<String, dynamic> glossaryToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'term': row['term'],
    'category': row['category'],
    'shortExplanation': row['short_explanation'],
  };
}

Map<String, dynamic> deviceToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'userId': row['user_id'],
    'deviceName': row['device_name'],
    'deviceIdentifier': row['device_identifier'],
    'firmwareVersion': row['firmware_version'],
    'isSimulated': row['is_simulated'],
    'pairedAt': toIsoOrNull(row['paired_at']),
    'lastSyncAt': toIsoOrNull(row['last_sync_at']),
  };
}

Map<String, dynamic> commentToJson(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'sessionId': row['session_id'],
    'userId': row['user_id'],
    'userName': row['user_name'],
    'userAvatarUrl': row['user_avatar_url'],
    'content': row['content'],
    'createdAt': toIsoOrNull(row['created_at']),
  };
}
