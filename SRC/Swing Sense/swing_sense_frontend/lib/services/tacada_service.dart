import 'api_client.dart';

/// Estatisticas das tacadas da raquete real (`GET /tacadas/summary`).
class TacadaStats {
  TacadaStats({
    required this.total,
    required this.forehand,
    required this.backhand,
    required this.saque,
    required this.incertas,
  });

  final int total;
  final int forehand;
  final int backhand;
  final int saque;
  final int incertas;

  factory TacadaStats.fromJson(Map<String, dynamic> json) => TacadaStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        forehand: (json['forehand'] as num?)?.toInt() ?? 0,
        backhand: (json['backhand'] as num?)?.toInt() ?? 0,
        saque: (json['saque'] as num?)?.toInt() ?? 0,
        incertas: (json['incertas'] as num?)?.toInt() ?? 0,
      );
}

class TacadaService {
  TacadaService(this._client);
  final ApiClient _client;

  /// Resumo de uma sessao. `total == 0` quando a sessao nao tem tacadas da raquete real.
  Future<TacadaStats> summaryForSession(String sessionId) async {
    final data = await _client.get('/tacadas/summary', query: {'sessionId': sessionId});
    return TacadaStats.fromJson(data as Map<String, dynamic>);
  }
}
