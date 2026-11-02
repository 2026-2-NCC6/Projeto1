/// Modelos do dashboard (`GET /dashboard/me` e `GET /dashboard/leaderboard`).
library;

/// Filtro de periodo e de golpe escolhido na tela.
class DashboardFilter {
  const DashboardFilter({this.range = '30d', this.customFrom, this.customTo, this.tipo});

  /// `7d`, `30d`, `90d`, `all` ou `custom` (usa [customFrom]/[customTo], ambos inclusivos).
  final String range;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// `FH`, `BH`, `SQ` ou `null` (todos os golpes).
  final String? tipo;

  bool get isCustom => range == 'custom' && customFrom != null && customTo != null;

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Parametros da query: o periodo vale para as duas rotas; `tipo` so para `/me`.
  Map<String, String> periodQuery() => isCustom
      ? {'from': _dia(customFrom!), 'to': _dia(customTo!)}
      : {'range': range == 'custom' ? '30d' : range};

  DashboardFilter copyWith({String? range, DateTime? customFrom, DateTime? customTo, String? tipo, bool clearTipo = false}) =>
      DashboardFilter(
        range: range ?? this.range,
        customFrom: customFrom ?? this.customFrom,
        customTo: customTo ?? this.customTo,
        tipo: clearTipo ? null : (tipo ?? this.tipo),
      );
}

double? _d(Object? v) => v is num ? v.toDouble() : null;
int _i(Object? v) => v is num ? v.toInt() : 0;

class DashboardKpis {
  const DashboardKpis({
    required this.tacadas,
    required this.sessoes,
    required this.tempoSegundos,
    required this.diasAtivos,
    this.velMedia,
    this.velMax,
  });

  final int tacadas;
  final int sessoes;
  final int tempoSegundos;
  final int diasAtivos;

  /// Velocidade ESTIMADA da raquete (km/h), relativa. Null sem tacadas.
  final double? velMedia;
  final int? velMax;

  factory DashboardKpis.fromJson(Map<String, dynamic> j) => DashboardKpis(
        tacadas: _i(j['tacadas']),
        sessoes: _i(j['sessoes']),
        tempoSegundos: _i(j['tempoSegundos']),
        diasAtivos: _i(j['diasAtivos']),
        velMedia: _d(j['velMedia']),
        velMax: j['velMax'] == null ? null : _i(j['velMax']),
      );
}

class DashboardDay {
  const DashboardDay({required this.date, required this.tacadas, this.velMedia});
  final DateTime date;
  final int tacadas;
  final double? velMedia;
}

class DashboardSession {
  const DashboardSession({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.tacadas,
    required this.forehand,
    required this.backhand,
    required this.saque,
    this.velMedia,
    this.velMax,
  });

  final String id;
  final String title;
  final DateTime? startedAt;
  final int tacadas;
  final int forehand;
  final int backhand;
  final int saque;
  final double? velMedia;
  final int? velMax;
}

class DashboardData {
  const DashboardData({
    required this.range,
    required this.days,
    required this.from,
    required this.kpis,
    required this.previous,
    required this.forehand,
    required this.backhand,
    required this.saque,
    required this.certas,
    required this.incertas,
    required this.porDia,
    required this.porDiaSemana,
    required this.sessoes,
    required this.tipo,
  });

  final String range;
  final int days;

  /// Inicio do periodo (instante UTC da meia-noite de Brasilia).
  final DateTime from;
  final String? tipo;
  final DashboardKpis kpis;

  /// Mesmos totais do periodo anterior de mesma duracao; null em "Tudo".
  final DashboardKpis? previous;
  final int forehand;
  final int backhand;
  final int saque;
  final int certas;
  final int incertas;
  final List<DashboardDay> porDia;

  /// Tacadas por dia da semana, segunda (0) a domingo (6).
  final List<int> porDiaSemana;
  final List<DashboardSession> sessoes;

  bool get isEmpty => kpis.tacadas == 0;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final period = j['period'] as Map<String, dynamic>;
    final porTipo = j['porTipo'] as Map<String, dynamic>? ?? const {};
    final confianca = j['confianca'] as Map<String, dynamic>? ?? const {};
    return DashboardData(
      range: period['range'] as String? ?? '30d',
      days: _i(period['days']),
      from: DateTime.parse(period['from'] as String),
      tipo: period['tipo'] as String?,
      kpis: DashboardKpis.fromJson(j['kpis'] as Map<String, dynamic>),
      previous: j['previous'] == null ? null : DashboardKpis.fromJson(j['previous'] as Map<String, dynamic>),
      forehand: _i(porTipo['FH']),
      backhand: _i(porTipo['BH']),
      saque: _i(porTipo['SQ']),
      certas: _i(confianca['certas']),
      incertas: _i(confianca['incertas']),
      porDia: [
        for (final d in (j['porDia'] as List? ?? const []).cast<Map<String, dynamic>>())
          DashboardDay(date: DateTime.parse(d['date'] as String), tacadas: _i(d['tacadas']), velMedia: _d(d['velMedia'])),
      ],
      porDiaSemana: [
        for (final v in (j['porDiaSemana'] as List? ?? const [])) _i(v),
      ],
      sessoes: [
        for (final s in (j['sessoes'] as List? ?? const []).cast<Map<String, dynamic>>())
          DashboardSession(
            id: s['id'] as String,
            title: s['title'] as String? ?? 'Treino',
            startedAt: s['startedAt'] != null ? DateTime.tryParse(s['startedAt'] as String) : null,
            tacadas: _i(s['tacadas']),
            forehand: _i(s['forehand']),
            backhand: _i(s['backhand']),
            saque: _i(s['saque']),
            velMedia: _d(s['velMedia']),
            velMax: s['velMax'] == null ? null : _i(s['velMax']),
          ),
      ],
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.isMe,
    required this.tacadas,
    required this.diasAtivos,
    required this.tempoSegundos,
    this.avatarUrl,
    this.level,
    this.velMedia,
    this.evolucaoPct,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? level;
  final bool isMe;
  final int tacadas;
  final int diasAtivos;
  final int tempoSegundos;
  final double? velMedia;

  /// Variacao % da velocidade media contra o periodo anterior; null sem base de comparacao.
  final double? evolucaoPct;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        userId: j['userId'] as String,
        name: j['name'] as String? ?? 'Jogador',
        avatarUrl: j['avatarUrl'] as String?,
        level: j['level'] as String?,
        isMe: j['isMe'] as bool? ?? false,
        tacadas: _i(j['tacadas']),
        diasAtivos: _i(j['diasAtivos']),
        tempoSegundos: _i(j['tempoSegundos']),
        velMedia: _d(j['velMedia']),
        evolucaoPct: _d(j['evolucaoPct']),
      );
}

/// Metrica pela qual a comunidade e ordenada.
enum LeaderboardMetric {
  tacadas('Tacadas'),
  constancia('Dias ativos'),
  tempo('Tempo'),
  evolucao('Evolução');

  const LeaderboardMetric(this.label);
  final String label;

  /// Valor usado para ordenar e dimensionar a barra; null = sem dado (vai para o fim).
  double? valueOf(LeaderboardEntry e) => switch (this) {
        LeaderboardMetric.tacadas => e.tacadas.toDouble(),
        LeaderboardMetric.constancia => e.diasAtivos.toDouble(),
        LeaderboardMetric.tempo => e.tempoSegundos.toDouble(),
        LeaderboardMetric.evolucao => e.evolucaoPct,
      };
}

/// `7h 05min`, `12min` ou `45s`.
String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
  return '${m}min';
}
