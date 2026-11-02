import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/postgres_store.dart';
import '../mappers.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

/// Brasilia nao tem horario de verao desde 2019, entao um deslocamento fixo de
/// 3 horas basta para achar a meia-noite local (00:00 BRT = 03:00 UTC).
const _brtOffsetHours = 3;
const _maxCustomDays = 366;

class _Periodo {
  _Periodo(this.from, this.to, this.prevFrom, this.label);

  /// Inicio (inclusivo) e fim (exclusivo) do periodo, em UTC.
  final DateTime from;
  final DateTime to;

  /// Inicio do periodo anterior de mesma duracao; null quando o periodo e "tudo".
  final DateTime? prevFrom;
  final String label;

  int get days => to.difference(from).inDays;
}

DateTime _meiaNoiteBrt(int y, int m, int d) => DateTime.utc(y, m, d, _brtOffsetHours);

DateTime? _parseDia(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, d);
  // Rejeita datas que o DateTime "corrigiria" (ex.: 2026-02-31).
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

/// Le `from`/`to` (yyyy-MM-dd, ambos inclusivos) ou `range` (7d, 30d, 90d, all).
/// Devolve uma mensagem de erro (String) quando algo e invalido.
Object _lerPeriodo(Map<String, String> q, {DateTime? now}) {
  final agora = (now ?? DateTime.now()).toUtc().subtract(const Duration(hours: _brtOffsetHours));
  final amanha = _meiaNoiteBrt(agora.year, agora.month, agora.day).add(const Duration(days: 1));

  final fromRaw = q['from'], toRaw = q['to'];
  if (fromRaw != null || toRaw != null) {
    final de = _parseDia(fromRaw), ate = _parseDia(toRaw);
    if (de == null || ate == null) return 'from e to devem estar no formato yyyy-MM-dd';
    if (ate.isBefore(de)) return 'to deve ser igual ou posterior a from';
    final dias = ate.difference(de).inDays + 1;
    if (dias > _maxCustomDays) return 'O periodo maximo e de $_maxCustomDays dias';
    final from = _meiaNoiteBrt(de.year, de.month, de.day);
    final to = _meiaNoiteBrt(ate.year, ate.month, ate.day).add(const Duration(days: 1));
    return _Periodo(from, to, from.subtract(Duration(days: dias)), 'custom');
  }

  final range = q['range'] ?? '30d';
  if (range == 'all') return _Periodo(_meiaNoiteBrt(2020, 1, 1), amanha, null, 'all');
  final dias = switch (range) { '7d' => 7, '30d' => 30, '90d' => 90, _ => 0 };
  if (dias == 0) return 'range deve ser 7d, 30d, 90d ou all';
  final from = amanha.subtract(Duration(days: dias));
  return _Periodo(from, amanha, from.subtract(Duration(days: dias)), range);
}

/// `null` = todos os golpes.
String? _lerTipo(String? raw) => (raw == 'FH' || raw == 'BH' || raw == 'SQ') ? raw : null;

Map<String, dynamic> _totaisToJson(Map<String, dynamic> r) => {
      'tacadas': toIntOr(r['tacadas']),
      'sessoes': toIntOr(r['sessoes']),
      'tempoSegundos': toIntOr(r['tempo_segundos']),
      'diasAtivos': toIntOr(r['dias_ativos']),
      'velMedia': toDoubleOrNull(r['vel_media']),
      'velMax': r['vel_max'] == null ? null : toIntOr(r['vel_max']),
    };

Router dashboardRoutes(PgStore db) {
  final router = Router();

  // GET /dashboard/me?range=7d|30d|90d|all | from=&to=  &tipo=FH|BH|SQ
  //
  // Tudo vem das tacadas da raquete real do proprio usuario (sessoes de
  // demonstracao ficam de fora). `previous` traz os mesmos totais do periodo
  // anterior de mesma duracao, para o app mostrar a variacao.
  router.get('/me', (Request request) async {
    final q = request.url.queryParameters;
    final periodo = _lerPeriodo(q);
    if (periodo is String) return ApiResponse.error(periodo);
    periodo as _Periodo;
    final tipo = _lerTipo(q['tipo']);

    final totals = await db.getDashboardTotals(request.userId, periodo.from, periodo.to, tipo: tipo);
    final previous = periodo.prevFrom == null
        ? null
        : await db.getDashboardTotals(request.userId, periodo.prevFrom!, periodo.from, tipo: tipo);
    final daily = await db.getDashboardDaily(request.userId, periodo.from, periodo.to, tipo: tipo);
    final sessions = await db.getDashboardSessions(request.userId, periodo.from, periodo.to, tipo: tipo);

    // Tacadas por dia da semana (segunda = 0 ... domingo = 6).
    final porDiaSemana = List<int>.filled(7, 0);
    for (final d in daily) {
      final date = _parseDia(d['dia']?.toString());
      if (date != null) porDiaSemana[date.weekday - 1] += toIntOr(d['tacadas']);
    }

    final tacadas = toIntOr(totals['tacadas']);
    return ApiResponse.ok({
      'period': {
        'range': periodo.label,
        'from': periodo.from.toIso8601String(),
        'to': periodo.to.toIso8601String(),
        'days': periodo.days,
        'tipo': tipo,
      },
      'kpis': _totaisToJson(totals),
      'previous': previous == null ? null : _totaisToJson(previous),
      'porTipo': {
        'FH': toIntOr(totals['forehand']),
        'BH': toIntOr(totals['backhand']),
        'SQ': toIntOr(totals['saque']),
      },
      'confianca': {
        'certas': tacadas - toIntOr(totals['incertas']),
        'incertas': toIntOr(totals['incertas']),
      },
      'porDia': [
        for (final d in daily)
          {'date': d['dia'], 'tacadas': toIntOr(d['tacadas']), 'velMedia': toDoubleOrNull(d['vel_media'])},
      ],
      'porDiaSemana': porDiaSemana,
      'sessoes': [
        for (final s in sessions)
          {
            'id': s['id'].toString(),
            'title': s['title'],
            'startedAt': toIsoOrNull(s['started_at']),
            'tacadas': toIntOr(s['tacadas']),
            'forehand': toIntOr(s['forehand']),
            'backhand': toIntOr(s['backhand']),
            'saque': toIntOr(s['saque']),
            'velMedia': toDoubleOrNull(s['vel_media']),
            'velMax': s['vel_max'] == null ? null : toIntOr(s['vel_max']),
          },
      ],
    });
  });

  // GET /dashboard/leaderboard?range=&from=&to=
  //
  // O usuario e quem ele segue, com todas as metricas de uma vez (o app
  // ordena pela escolhida). So entram pessoas que o usuario segue: a mesma
  // regra de visibilidade do feed. `evolucaoPct` compara a velocidade media do
  // periodo com a do periodo anterior; e relativa a cada pessoa, por isso nao
  // ha ranking de velocidade absoluta (a medida e uma estimativa relativa).
  router.get('/leaderboard', (Request request) async {
    final periodo = _lerPeriodo(request.url.queryParameters);
    if (periodo is String) return ApiResponse.error(periodo);
    periodo as _Periodo;

    final rows = await db.getLeaderboard(request.userId, periodo.from, periodo.to, prevFrom: periodo.prevFrom);
    return ApiResponse.ok({
      'period': {
        'range': periodo.label,
        'from': periodo.from.toIso8601String(),
        'to': periodo.to.toIso8601String(),
        'days': periodo.days,
      },
      'entries': [
        for (final r in rows)
          () {
            final atual = toDoubleOrNull(r['vel_media']);
            final anterior = toDoubleOrNull(r['vel_media_anterior']);
            return {
              'userId': r['id'].toString(),
              'name': r['name'],
              'avatarUrl': r['avatar_url'],
              'level': r['level'],
              'isMe': r['id'].toString() == request.userId,
              'tacadas': toIntOr(r['tacadas']),
              'diasAtivos': toIntOr(r['dias_ativos']),
              'tempoSegundos': toIntOr(r['tempo_segundos']),
              'velMedia': atual,
              'evolucaoPct': (atual != null && anterior != null && anterior > 0)
                  ? double.parse(((atual - anterior) / anterior * 100).toStringAsFixed(1))
                  : null,
            };
          }(),
      ],
    });
  });

  return router;
}
