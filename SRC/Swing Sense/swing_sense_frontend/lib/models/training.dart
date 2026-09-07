class Training {
  Training({
    required this.id,
    required this.title,
    this.authorId,
    this.authorName,
    this.description,
    this.targetAudience = 'geral',
    this.difficulty = 'iniciante',
    this.durationMinutes = 30,
    this.focus,
    this.coverColor = '1DB954',
  });

  final String id;
  final String? authorId;
  final String? authorName;
  final String title;
  final String? description;
  final String targetAudience;
  final String difficulty;
  final int durationMinutes;
  final String? focus;
  final String coverColor;

  String get difficultyLabel {
    switch (difficulty) {
      case 'iniciante':
        return 'Iniciante';
      case 'intermediario':
        return 'Intermediario';
      case 'avancado':
        return 'Avancado';
      default:
        return difficulty;
    }
  }

  factory Training.fromJson(Map<String, dynamic> json) {
    return Training(
      id: json['id'] as String,
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      title: json['title'] as String? ?? 'Treino',
      description: json['description'] as String?,
      targetAudience: json['targetAudience'] as String? ?? 'geral',
      difficulty: json['difficulty'] as String? ?? 'iniciante',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      focus: json['focus'] as String?,
      coverColor: json['coverColor'] as String? ?? '1DB954',
    );
  }
}
