class AppUser {
  AppUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.bio,
    this.level = 'iniciante',
    this.city,
    this.followersCount = 0,
    this.followingCount = 0,
    this.sessionsCount = 0,
    this.followedByMe = false,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String level;
  final String? city;
  final int followersCount;
  final int followingCount;
  final int sessionsCount;
  final bool followedByMe;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String get levelLabel {
    switch (level) {
      case 'iniciante':
        return 'Iniciante';
      case 'intermediario':
        return 'Intermediario';
      case 'avancado':
        return 'Avancado';
      case 'profissional':
        return 'Profissional';
      default:
        return level;
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      level: json['level'] as String? ?? 'iniciante',
      city: json['city'] as String?,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      sessionsCount: (json['sessionsCount'] as num?)?.toInt() ?? 0,
      followedByMe: json['followedByMe'] as bool? ?? false,
    );
  }

  AppUser copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    String? level,
    String? city,
    bool? followedByMe,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      level: level ?? this.level,
      city: city ?? this.city,
      followersCount: followersCount,
      followingCount: followingCount,
      sessionsCount: sessionsCount,
      followedByMe: followedByMe ?? this.followedByMe,
    );
  }
}
