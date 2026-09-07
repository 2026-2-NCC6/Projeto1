class TrainingSession {
  TrainingSession({
    required this.id,
    required this.userId,
    required this.title,
    this.trainingId,
    this.trainingTitle,
    this.status = 'in_progress',
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.shotCount = 0,
    this.aceCount = 0,
    this.avgBallSpeedKmh,
    this.maxBallSpeedKmh,
    this.calories,
    this.notes,
    this.userName,
    this.userAvatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String userId;
  final String? trainingId;
  final String? trainingTitle;
  final String title;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int shotCount;
  final int aceCount;
  final double? avgBallSpeedKmh;
  final double? maxBallSpeedKmh;
  final int? calories;
  final String? notes;
  final String? userName;
  final String? userAvatarUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  Duration get duration => Duration(seconds: durationSeconds);

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      trainingId: json['trainingId'] as String?,
      trainingTitle: json['trainingTitle'] as String?,
      title: json['title'] as String? ?? 'Treino',
      status: json['status'] as String? ?? 'in_progress',
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      shotCount: (json['shotCount'] as num?)?.toInt() ?? 0,
      aceCount: (json['aceCount'] as num?)?.toInt() ?? 0,
      avgBallSpeedKmh: _toDouble(json['avgBallSpeedKmh']),
      maxBallSpeedKmh: _toDouble(json['maxBallSpeedKmh']),
      calories: (json['calories'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
    );
  }
}
