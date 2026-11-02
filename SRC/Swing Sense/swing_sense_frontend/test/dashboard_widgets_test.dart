// Renderiza os blocos do dashboard em largura de celular e de tela larga para
// pegar erros de layout (overflow, restricoes infinitas) que os testes de logica nao veem.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swing_sense_app/models/dashboard.dart';
import 'package:swing_sense_app/screens/dashboard/community_tab.dart';
import 'package:swing_sense_app/screens/dashboard/dashboard_logic.dart';
import 'package:swing_sense_app/screens/dashboard/dashboard_widgets.dart';

DashboardData sample({int dias = 5, String? tipo}) {
  final from = DateTime.utc(2026, 10, 1, 3);
  return DashboardData(
    range: '30d', days: 30, from: from, tipo: tipo,
    kpis: DashboardKpis(tacadas: 120, sessoes: 4, tempoSegundos: 5400, diasAtivos: dias, velMedia: 34.5, velMax: 61),
    previous: const DashboardKpis(tacadas: 80, sessoes: 3, tempoSegundos: 3000, diasAtivos: 3, velMedia: 31, velMax: 55),
    forehand: 70, backhand: 40, saque: 10, certas: 100, incertas: 20,
    porDia: [
      for (var i = 0; i < dias; i++) DashboardDay(date: DateTime.utc(2026, 10, 5 + i * 3), tacadas: 10 + i * 5, velMedia: 30.0 + i),
    ],
    porDiaSemana: const [10, 0, 50, 20, 0, 40, 0],
    sessoes: [
      for (var i = 0; i < 4; i++)
        DashboardSession(id: 's$i', title: 'Treino $i', startedAt: DateTime.utc(2026, 10, 10 + i), tacadas: 20 + i * 10,
            forehand: 10 + i, backhand: 8, saque: 2, velMedia: 33.0 + i, velMax: 50 + i),
    ],
  );
}

Widget panel(DashboardData d) {
  final today = DateTime.utc(2026, 10, 29);
  final buckets = bucketize(d, today: today);
  final k = d.kpis;
  return BentoGrid(items: [
    BentoItem.full(HeroCard(data: d, buckets: buckets, onTipo: (_) {})),
    BentoItem.full(InsightsPanel(insights: buildInsights(d, today: today))),
    BentoItem.tile(StatTile(icon: Icons.speed, label: 'Velocidade média', value: '${k.velMedia!.round()} km/h', caption: 'pico ${k.velMax} km/h', progress: 0.56)),
    BentoItem.tile(StatTile(icon: Icons.event_available, label: 'Treinos', value: '${k.sessoes}', delta: 33)),
    BentoItem.tile(StatTile(icon: Icons.timer_outlined, label: 'Tempo de treino', value: '1h 30min', caption: 'média 22min por treino')),
    BentoItem.tile(StatTile(icon: Icons.local_fire_department_outlined, label: 'Dias ativos', value: '${k.diasAtivos} de 29', caption: '17% do período', progress: 0.17)),
    BentoItem(EvolutionCard(data: d, buckets: buckets)),
    BentoItem(MixCard(data: d, onTipo: (_) {})),
    BentoItem(WeekRhythmCard(porDiaSemana: d.porDiaSemana)),
    BentoItem(RecentSessionsCard(sessoes: d.sessoes)),
  ]);
}

Future<void> pumpAt(WidgetTester t, Size size, Widget child) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: ListView(children: [Padding(padding: const EdgeInsets.all(16), child: child)]),
    ),
  ));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  for (final size in [const Size(360, 780), const Size(1280, 900)]) {
    testWidgets('painel renderiza sem erro de layout em ${size.width.toInt()}px', (t) async {
      await pumpAt(t, size, panel(sample()));
      expect(t.takeException(), isNull);
      expect(find.text('120'), findsWidgets); // tacadas no resumo (e no centro da pizza)
      expect(find.text('Mix de golpes'), findsOneWidget);
    });

    testWidgets('um unico dia de treino mostra mensagem em vez de grafico vazio (${size.width.toInt()}px)', (t) async {
      await pumpAt(t, size, panel(sample(dias: 1)));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Treine em mais dias'), findsOneWidget);
    });

    testWidgets('filtro de golpe ativo esconde a pizza (${size.width.toInt()}px)', (t) async {
      await pumpAt(t, size, panel(sample(tipo: 'FH')));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Mostrando só forehand'), findsOneWidget);
    });

    testWidgets('comunidade renderiza podio e ranking (${size.width.toInt()}px)', (t) async {
      const entries = [
        LeaderboardEntry(userId: 'a', name: 'Ana Souza', isMe: true, tacadas: 120, diasAtivos: 4, tempoSegundos: 3600, evolucaoPct: 12),
        LeaderboardEntry(userId: 'b', name: 'Bruno Lima', isMe: false, tacadas: 300, diasAtivos: 9, tempoSegundos: 9000, evolucaoPct: -4),
        LeaderboardEntry(userId: 'c', name: 'Caio Reis', isMe: false, tacadas: 55, diasAtivos: 2, tempoSegundos: 1200),
        LeaderboardEntry(userId: 'd', name: 'Duda Melo', isMe: false, tacadas: 0, diasAtivos: 0, tempoSegundos: 0),
      ];
      await pumpAt(t, size, const CommunityTab(entries: entries, allTime: false));
      expect(t.takeException(), isNull);
      expect(find.text('Pódio'), findsOneWidget);
      expect(find.textContaining('Ana Souza'), findsWidgets);
    });
  }

  testWidgets('comunidade sem ninguem seguido mostra convite', (t) async {
    await pumpAt(t, const Size(400, 800), const CommunityTab(entries: [
      LeaderboardEntry(userId: 'a', name: 'Ana', isMe: true, tacadas: 1, diasAtivos: 1, tempoSegundos: 10),
    ], allTime: false));
    expect(find.text('Siga outros jogadores'), findsOneWidget);
  });
}
