import 'package:flutter_test/flutter_test.dart';

import 'package:swing_sense_app/models/dashboard.dart';
import 'package:swing_sense_app/screens/dashboard/dashboard_logic.dart';

DashboardData data({
  String range = '7d',
  int days = 7,
  required DateTime from,
  List<DashboardDay> porDia = const [],
}) =>
    DashboardData(
      range: range, days: days, from: from, tipo: null,
      kpis: const DashboardKpis(tacadas: 0, sessoes: 0, tempoSegundos: 0, diasAtivos: 0),
      previous: null, forehand: 0, backhand: 0, saque: 0, certas: 0, incertas: 0,
      porDia: porDia, porDiaSemana: const [], sessoes: const [],
    );

void main() {
  insightTests();
  regressionTests();
  group('DashboardFilter', () {
    test('periodo rapido vira range', () {
      expect(const DashboardFilter(range: '7d').periodQuery(), {'range': '7d'});
    });

    test('periodo personalizado vira from/to yyyy-MM-dd', () {
      final f = DashboardFilter(range: 'custom', customFrom: DateTime(2026, 10, 1), customTo: DateTime(2026, 10, 7));
      expect(f.periodQuery(), {'from': '2026-10-01', 'to': '2026-10-07'});
    });

    test('custom sem datas cai para 30d e clearTipo remove o golpe', () {
      expect(const DashboardFilter(range: 'custom').periodQuery(), {'range': '30d'});
      expect(const DashboardFilter(tipo: 'FH').copyWith(clearTipo: true).tipo, isNull);
    });
  });

  group('deltaPct e formatDuration', () {
    test('variacao contra o periodo anterior', () {
      expect(deltaPct(110, 100), closeTo(10, 1e-9));
      expect(deltaPct(50, 100), closeTo(-50, 1e-9));
      expect(deltaPct(5, 0), isNull);
      expect(deltaPct(5, null), isNull);
    });

    test('duracao legivel', () {
      expect(formatDuration(45), '45s');
      expect(formatDuration(720), '12min');
      expect(formatDuration(7500), '2h 05min');
    });
  });

  group('bucketize', () {
    // "Hoje" = 2026-10-29 (quinta). Periodo de 7 dias: 23/10 a 29/10.
    final today = DateTime.utc(2026, 10, 29, 12);
    final from7 = DateTime.utc(2026, 10, 23, 3); // meia-noite de Brasilia

    test('7 dias: uma barra por dia, dias sem treino com zero', () {
      final b = bucketize(
        data(from: from7, porDia: [DashboardDay(date: DateTime.utc(2026, 10, 26), tacadas: 4)]),
        today: today,
      );
      expect(b.length, 7);
      expect(b.map((x) => x.value), [0, 0, 0, 4, 0, 0, 0]);
      expect(b[3].tooltip, '26/10 · 4 tacadas');
    });

    test('periodo que termina no futuro e cortado em hoje', () {
      final b = bucketize(data(range: '30d', days: 30, from: DateTime.utc(2026, 10, 20, 3)), today: today);
      expect(b.length, 10); // 20/10 ate 29/10
    });

    test('mais de 31 dias agrupa por semana (segunda a domingo)', () {
      final b = bucketize(
        data(
          range: '90d', days: 90, from: DateTime.utc(2026, 8, 1, 3),
          porDia: [
            DashboardDay(date: DateTime.utc(2026, 10, 26), tacadas: 4), // segunda
            DashboardDay(date: DateTime.utc(2026, 10, 29), tacadas: 6), // quinta, mesma semana
          ],
        ),
        today: today,
      );
      expect(b.length, lessThanOrEqualTo(26));
      expect(b.last.value, 10);
      expect(b.last.label, '26/10');
    });

    test('"all" comeca no primeiro dia com tacada; sem dados nao ha barras', () {
      final b = bucketize(
        data(range: 'all', days: 2500, from: DateTime.utc(2020, 1, 1, 3),
            porDia: [DashboardDay(date: DateTime.utc(2026, 10, 19), tacadas: 55)]),
        today: today,
      );
      expect(b.fold<int>(0, (s, x) => s + x.value), 55);
      expect(bucketize(data(range: 'all', days: 1, from: DateTime.utc(2020, 1, 1, 3)), today: today), isEmpty);
    });
  });

  group('DashboardData.fromJson', () {
    test('le a resposta da API', () {
      final d = DashboardData.fromJson({
        'period': {'range': '7d', 'from': '2026-10-23T03:00:00.000Z', 'to': '2026-10-30T03:00:00.000Z', 'days': 7, 'tipo': null},
        'kpis': {'tacadas': 10, 'sessoes': 2, 'tempoSegundos': 3600, 'diasAtivos': 2, 'velMedia': 31.5, 'velMax': 48},
        'previous': null,
        'porTipo': {'FH': 6, 'BH': 3, 'SQ': 1},
        'confianca': {'certas': 8, 'incertas': 2},
        'porDia': [{'date': '2026-10-26', 'tacadas': 4, 'velMedia': 30.0}],
        'porDiaSemana': [4, 0, 6, 0, 0, 0, 0],
        'sessoes': [
          {'id': 's1', 'title': 'Rally', 'startedAt': '2026-10-28T15:00:00.000Z', 'tacadas': 6, 'forehand': 4,
           'backhand': 2, 'saque': 0, 'velMedia': 32.5, 'velMax': 48},
        ],
      });
      expect(d.kpis.velMax, 48);
      expect(d.previous, isNull);
      expect(d.forehand + d.backhand + d.saque, 10);
      expect(d.sessoes.single.title, 'Rally');
      expect(d.isEmpty, isFalse);
    });
  });

  group('LeaderboardMetric', () {
    const e = LeaderboardEntry(
      userId: 'u', name: 'A', isMe: true, tacadas: 10, diasAtivos: 3, tempoSegundos: 600, evolucaoPct: null,
    );
    test('valor por metrica; evolucao sem base e nula', () {
      expect(LeaderboardMetric.tacadas.valueOf(e), 10);
      expect(LeaderboardMetric.constancia.valueOf(e), 3);
      expect(LeaderboardMetric.tempo.valueOf(e), 600);
      expect(LeaderboardMetric.evolucao.valueOf(e), isNull);
    });
  });
}

DashboardData withMix({
  int fh = 0, int bh = 0, int sq = 0, int incertas = 0,
  DashboardKpis? kpis, DashboardKpis? previous,
  List<int> semana = const [0, 0, 0, 0, 0, 0, 0],
  List<DashboardSession> sessoes = const [],
}) =>
    DashboardData(
      range: '30d', days: 30, from: DateTime.utc(2026, 10, 1, 3), tipo: null,
      kpis: kpis ?? DashboardKpis(tacadas: fh + bh + sq, sessoes: 1, tempoSegundos: 600, diasAtivos: 3, velMedia: 30, velMax: 40),
      previous: previous, forehand: fh, backhand: bh, saque: sq,
      certas: fh + bh + sq - incertas, incertas: incertas, porDia: const [], porDiaSemana: semana, sessoes: sessoes,
    );

void insightTests() {
  group('buildInsights', () {
    test('sem tacadas nao gera insights', () {
      expect(buildInsights(withMix()), isEmpty);
    });

    test('avisa quando o backhand e pouco usado', () {
      final texts = buildInsights(withMix(fh: 40, bh: 10)).map((i) => i.text).toList();
      expect(texts.any((t) => t.contains('Backhand é só 20%')), isTrue);
    });

    test('destaca o golpe dominante quando ha equilibrio', () {
      final texts = buildInsights(withMix(fh: 30, bh: 25)).map((i) => i.text).toList();
      expect(texts.any((t) => t.startsWith('Forehand é 55%')), isTrue);
    });

    test('compara com o periodo anterior e respeita o limite de 4', () {
      const atual = DashboardKpis(tacadas: 100, sessoes: 3, tempoSegundos: 900, diasAtivos: 3, velMedia: 33, velMax: 50);
      const antes = DashboardKpis(tacadas: 50, sessoes: 2, tempoSegundos: 600, diasAtivos: 2, velMedia: 30, velMax: 45);
      final list = buildInsights(
        withMix(fh: 60, bh: 40, incertas: 40, kpis: atual, previous: antes, semana: [0, 0, 80, 0, 20, 0, 0],
            sessoes: [DashboardSession(id: 's', title: 'Rally', startedAt: null, tacadas: 100, forehand: 60, backhand: 40, saque: 0, velMax: 50)]),
        today: DateTime.utc(2026, 10, 29),
      );
      expect(list.length, 4);
      expect(list.first.text, contains('Velocidade média 10% acima'));
      expect(list[1].text, contains('100% mais tacadas'));
    });

    test('melhor dia da semana usa o plural certo', () {
      final texts = buildInsights(withMix(fh: 30, bh: 30, semana: [0, 0, 50, 10, 0, 0, 0])).map((i) => i.text);
      expect(texts.any((t) => t.contains('às quartas (83%')), isTrue);
    });
  });

  group('periodo', () {
    test('pct e periodLabel', () {
      expect(pct(1, 3), 33);
      expect(pct(5, 0), 0);
      expect(periodLabel(withMix()), 'últimos 30 dias');
      expect(
        periodLabel(DashboardData(
          range: 'custom', days: 7, from: DateTime.utc(2026, 10, 1, 3), tipo: null,
          kpis: const DashboardKpis(tacadas: 0, sessoes: 0, tempoSegundos: 0, diasAtivos: 0),
          previous: null, forehand: 0, backhand: 0, saque: 0, certas: 0, incertas: 0,
          porDia: const [], porDiaSemana: const [], sessoes: const [],
        )),
        '01/10 a 07/10',
      );
    });

    test('daysInPeriod corta em hoje e e nulo em "Tudo"', () {
      expect(daysInPeriod(withMix(), today: DateTime.utc(2026, 10, 10)), 10);
      expect(daysInPeriod(withMix(), today: DateTime.utc(2026, 12, 31)), 30);
      expect(daysInPeriod(data(range: 'all', days: 2000, from: DateTime.utc(2020, 1, 1, 3)), today: DateTime.utc(2026, 10, 10)), isNull);
    });
  });
}

void regressionTests() {
  test('30 dias: nenhum dia do periodo e cortado do grafico diario', () {
    final d = DashboardData(
      range: '30d', days: 30, from: DateTime.utc(2026, 9, 30, 3), tipo: null,
      kpis: const DashboardKpis(tacadas: 10, sessoes: 1, tempoSegundos: 60, diasAtivos: 1),
      previous: null, forehand: 10, backhand: 0, saque: 0, certas: 10, incertas: 0,
      porDia: [DashboardDay(date: DateTime.utc(2026, 10, 2), tacadas: 10)],
      porDiaSemana: const [], sessoes: const [],
    );
    final b = bucketize(d, today: DateTime.utc(2026, 10, 29));
    expect(b.length, 30);
    expect(b[2].value, 10);
  });
}
