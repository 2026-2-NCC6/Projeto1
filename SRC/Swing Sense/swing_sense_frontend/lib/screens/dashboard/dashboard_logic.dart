import 'package:flutter/material.dart';

import '../../models/dashboard.dart';

/// Logica pura do dashboard (sem widgets de layout): agrupamento das barras,
/// variacoes e os "insights" em texto gerados a partir dos numeros.

String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

const weekdayShort = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
const _weekdayPlural = ['segundas', 'terças', 'quartas', 'quintas', 'sextas', 'sábados', 'domingos'];

/// Variacao % contra o periodo anterior; null quando nao ha base de comparacao.
double? deltaPct(num current, num? previous) {
  if (previous == null || previous <= 0) return null;
  return (current - previous) / previous * 100;
}

/// Percentual inteiro de [part] em [whole] (0 quando [whole] e zero).
int pct(num part, num whole) => whole <= 0 ? 0 : (part / whole * 100).round();

/// Texto curto do periodo: "últimos 30 dias", "01/10 a 07/10"...
String periodLabel(DashboardData d) {
  switch (d.range) {
    case 'all':
      return 'todo o histórico';
    case 'custom':
      final start = d.from.subtract(const Duration(hours: 3));
      final end = start.add(Duration(days: d.days - 1));
      return '${_dm(start)} a ${_dm(end)}';
    default:
      return 'últimos ${d.days} dias';
  }
}

/// Dias do periodo ate hoje (para "dias ativos / dias do periodo"); null em "Tudo".
int? daysInPeriod(DashboardData d, {required DateTime today}) {
  if (d.range == 'all') return null;
  // `from` e a meia-noite de Brasilia em UTC (03:00Z): volta 3h para achar o dia local.
  final startLocal = d.from.subtract(const Duration(hours: 3));
  final s = DateTime.utc(startLocal.year, startLocal.month, startLocal.day);
  final t = DateTime.utc(today.year, today.month, today.day);
  final last = s.add(Duration(days: d.days - 1));
  final end = last.isAfter(t) ? t : last;
  final n = end.difference(s).inDays + 1;
  return n < 1 ? 1 : n;
}

class ChartBucket {
  const ChartBucket(this.label, this.value, this.tooltip);
  final String label;
  final int value;
  final String tooltip;
}

/// Agrupa as tacadas por dia (periodos de ate 31 dias) ou por semana (maiores),
/// preenchendo com zero os dias sem treino para o eixo ficar continuo. Mostra no
/// maximo [maxWeeks] semanas (as mais recentes); periodos diarios nunca sao cortados.
/// `today` vem de fora para teste.
List<ChartBucket> bucketize(DashboardData d, {required DateTime today, int maxWeeks = 26}) {
  DateTime dateOnly(DateTime x) => DateTime.utc(x.year, x.month, x.day);
  final porDia = {for (final x in d.porDia) dateOnly(x.date): x.tacadas};
  final hoje = dateOnly(today);

  late DateTime start, end;
  if (d.range == 'all') {
    if (porDia.isEmpty) return const [];
    start = porDia.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    end = hoje;
  } else {
    // `from` e a meia-noite de Brasilia em UTC (03:00Z): volta 3h para achar o dia local.
    start = dateOnly(d.from.subtract(const Duration(hours: 3)));
    final last = start.add(Duration(days: d.days - 1));
    end = last.isAfter(hoje) ? hoje : last;
  }
  if (end.isBefore(start)) return const [];

  final span = end.difference(start).inDays + 1;
  final buckets = <ChartBucket>[];
  if (span <= 31) {
    for (var i = 0; i < span; i++) {
      final day = start.add(Duration(days: i));
      final n = porDia[day] ?? 0;
      buckets.add(ChartBucket('${day.day}', n, '${_dm(day)} · $n tacadas'));
    }
  } else {
    var weekStart = start.subtract(Duration(days: start.weekday - 1));
    while (!weekStart.isAfter(end)) {
      var n = 0;
      for (var i = 0; i < 7; i++) {
        n += porDia[weekStart.add(Duration(days: i))] ?? 0;
      }
      buckets.add(ChartBucket(_dm(weekStart), n, 'Semana de ${_dm(weekStart)} · $n tacadas'));
      weekStart = weekStart.add(const Duration(days: 7));
    }
    if (buckets.length > maxWeeks) return buckets.sublist(buckets.length - maxWeeks);
  }
  return buckets;
}

enum InsightTone { good, neutral, warn }

class Insight {
  const Insight(this.icon, this.text, this.tone);
  final IconData icon;
  final String text;
  final InsightTone tone;
}

/// Frases curtas tiradas dos numeros do periodo, da mais relevante para a menos.
/// Cada regra so dispara quando ha dado suficiente, entao a lista cresce ou
/// encolhe conforme o usuario treina.
List<Insight> buildInsights(DashboardData d, {DateTime? today, int max = 4}) {
  final k = d.kpis;
  final total = k.tacadas;
  if (total == 0) return const [];
  final out = <Insight>[];

  final dVel = k.velMedia == null ? null : deltaPct(k.velMedia!, d.previous?.velMedia);
  if (dVel != null && dVel.abs() >= 1) {
    out.add(Insight(
      dVel > 0 ? Icons.trending_up : Icons.trending_down,
      'Velocidade média ${dVel.abs().round()}% ${dVel > 0 ? 'acima' : 'abaixo'} do período anterior',
      dVel > 0 ? InsightTone.good : InsightTone.warn,
    ));
  }

  final dVol = deltaPct(total, d.previous?.tacadas);
  if (dVol != null && dVol.abs() >= 5) {
    out.add(Insight(
      dVol > 0 ? Icons.add_chart : Icons.remove_circle_outline,
      'Você fez ${dVol.abs().round()}% ${dVol > 0 ? 'mais' : 'menos'} tacadas que no período anterior',
      dVol > 0 ? InsightTone.good : InsightTone.neutral,
    ));
  }

  if (d.tipo == null) {
    final groundstrokes = d.forehand + d.backhand;
    if (groundstrokes >= 10 && d.backhand * 10 < groundstrokes * 3) {
      out.add(Insight(Icons.balance, 'Backhand é só ${pct(d.backhand, total)}% das tacadas: vale equilibrar', InsightTone.warn));
    } else if (groundstrokes >= 10 && d.forehand * 10 < groundstrokes * 3) {
      out.add(Insight(Icons.balance, 'Forehand é só ${pct(d.forehand, total)}% das tacadas: vale equilibrar', InsightTone.warn));
    } else if (d.forehand + d.backhand + d.saque > 0) {
      final fhTop = d.forehand >= d.backhand && d.forehand >= d.saque;
      final bhTop = !fhTop && d.backhand >= d.saque;
      out.add(Insight(
        Icons.sports_tennis,
        '${fhTop ? 'Forehand' : (bhTop ? 'Backhand' : 'Saque')} é ${pct(fhTop ? d.forehand : (bhTop ? d.backhand : d.saque), total)}% das suas tacadas',
        InsightTone.neutral,
      ));
    }
  }

  if (k.diasAtivos >= 2 && d.porDiaSemana.length == 7) {
    final best = d.porDiaSemana.indexOf(d.porDiaSemana.reduce((a, b) => a > b ? a : b));
    out.add(Insight(
      Icons.calendar_today,
      'Você treina mais às ${_weekdayPlural[best]} (${pct(d.porDiaSemana[best], total)}% das tacadas)',
      InsightTone.neutral,
    ));
  }

  final withPeak = d.sessoes.where((s) => s.velMax != null).toList();
  if (withPeak.isNotEmpty) {
    final top = withPeak.reduce((a, b) => (a.velMax! >= b.velMax!) ? a : b);
    out.add(Insight(Icons.bolt, 'Pico de ${top.velMax} km/h em "${top.title}"', InsightTone.good));
  }

  if (total >= 10 && d.incertas * 10 >= total * 3) {
    out.add(Insight(Icons.help_outline, '${pct(d.incertas, total)}% das tacadas ficaram com classificação incerta', InsightTone.warn));
  }

  final days = today == null ? null : daysInPeriod(d, today: today);
  if (days != null && days > 1) {
    out.add(Insight(Icons.local_fire_department_outlined, 'Você treinou em ${k.diasAtivos} de $days dias', InsightTone.neutral));
  }

  return out.take(max).toList();
}
