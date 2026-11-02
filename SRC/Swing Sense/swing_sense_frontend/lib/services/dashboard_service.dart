import '../models/dashboard.dart';
import 'api_client.dart';

class DashboardService {
  DashboardService(this._client);
  final ApiClient _client;

  /// Metricas do proprio usuario no periodo, opcionalmente so de um golpe.
  Future<DashboardData> mine(DashboardFilter filter) async {
    final data = await _client.get('/dashboard/me', query: {
      ...filter.periodQuery(),
      if (filter.tipo != null) 'tipo': filter.tipo,
    });
    return DashboardData.fromJson(data as Map<String, dynamic>);
  }

  /// O usuario e quem ele segue, com todas as metricas do periodo.
  Future<List<LeaderboardEntry>> leaderboard(DashboardFilter filter) async {
    final data = await _client.get('/dashboard/leaderboard', query: filter.periodQuery());
    final entries = (data as Map<String, dynamic>)['entries'] as List;
    return entries.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}
