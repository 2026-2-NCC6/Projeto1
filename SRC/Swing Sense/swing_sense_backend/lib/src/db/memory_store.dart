import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Banco de dados 100% em memoria (sem PostgreSQL, sem Docker).
///
/// Cada "tabela" e uma `List<Map<String, dynamic>>` com chaves em snake_case,
/// no mesmo formato que `lib/src/mappers.dart` ja espera (era o formato que o
/// driver do Postgres devolvia). Isso deixa as rotas e os mappers quase
/// identicos ao codigo anterior baseado em SQL - so a forma de ler/escrever
/// os dados muda.
///
/// Os dados existem apenas enquanto o processo do servidor estiver rodando:
/// ao reiniciar `dart run bin/server.dart`, tudo volta ao estado inicial
/// (populado por [MemoryStore.seeded] com os mesmos dados de demonstracao que
/// antes vinham do `bin/seed.dart`).
class MemoryStore {
  final List<Map<String, dynamic>> users = [];
  final List<Map<String, dynamic>> follows = [];
  final List<Map<String, dynamic>> devices = [];
  final List<Map<String, dynamic>> trainings = [];
  final List<Map<String, dynamic>> trainingSessions = [];
  final List<Map<String, dynamic>> sessionEvents = [];
  final List<Map<String, dynamic>> sessionLikes = [];
  final List<Map<String, dynamic>> sessionComments = [];
  final List<Map<String, dynamic>> goals = [];
  final List<Map<String, dynamic>> glossaryTerms = [];

  static String newId() => _uuid.v4();

  Map<String, dynamic>? userById(String? id) {
    if (id == null) return null;
    for (final u in users) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  Map<String, dynamic>? trainingById(String? id) {
    if (id == null) return null;
    for (final t in trainings) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  Map<String, dynamic>? sessionById(String? id) {
    if (id == null) return null;
    for (final s in trainingSessions) {
      if (s['id'] == id) return s;
    }
    return null;
  }

  bool isFollowing(String followerId, String followingId) {
    return follows.any((f) => f['follower_id'] == followerId && f['following_id'] == followingId);
  }

  int followersCountOf(String userId) => follows.where((f) => f['following_id'] == userId).length;

  int followingCountOf(String userId) => follows.where((f) => f['follower_id'] == userId).length;

  int completedSessionsCountOf(String userId) =>
      trainingSessions.where((s) => s['user_id'] == userId && s['status'] == 'completed').length;

  int likeCountOf(String sessionId) => sessionLikes.where((l) => l['session_id'] == sessionId).length;

  int commentCountOf(String sessionId) => sessionComments.where((c) => c['session_id'] == sessionId).length;

  bool likedByMe(String sessionId, String userId) =>
      sessionLikes.any((l) => l['session_id'] == sessionId && l['user_id'] == userId);

  /// Junta uma sessao de treino com os campos derivados que as rotas
  /// devolvem (titulo do treino, dados do autor, curtidas/comentarios),
  /// espelhando os `JOIN`s que existiam nas queries SQL originais.
  Map<String, dynamic> hydrateSession(
    Map<String, dynamic> session, {
    String? viewerId,
    bool includeAuthor = false,
    bool includeEngagement = false,
  }) {
    final training = trainingById(session['training_id'] as String?);
    final row = {
      ...session,
      'training_title': training?['title'],
    };
    if (includeAuthor) {
      final author = userById(session['user_id'] as String?);
      row['user_name'] = author?['name'];
      row['user_avatar_url'] = author?['avatar_url'];
    }
    if (includeEngagement) {
      final sessionId = session['id'] as String;
      row['like_count'] = likeCountOf(sessionId);
      row['comment_count'] = commentCountOf(sessionId);
      row['liked_by_me'] = viewerId != null && likedByMe(sessionId, viewerId);
    }
    return row;
  }
}
