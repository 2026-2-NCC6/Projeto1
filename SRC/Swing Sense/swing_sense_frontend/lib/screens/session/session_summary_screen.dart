import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/session_event.dart';
import '../../models/training_session.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
import '../../services/tacada_service.dart';
import '../../widgets/primary_button.dart';
import '../home/home_shell.dart';

class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key, required this.session});
  final TrainingSession session;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final _sessionService = SessionService(ApiClient.instance);
  final _tacadaService = TacadaService(ApiClient.instance);
  List<SessionEvent> _events = [];
  bool _loadingEvents = true;
  TacadaStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadStats();
  }

  /// FH/BH/incertas vindos do banco. So aparece quando a sessao teve tacadas
  /// da raquete real; falha de rede apenas omite os blocos.
  Future<void> _loadStats() async {
    try {
      final stats = await _tacadaService.summaryForSession(widget.session.id);
      if (mounted && stats.total > 0) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _sessionService.getEvents(widget.session.id);
      if (mounted) setState(() => _events = events);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  static String _kmh(double? v) => v != null ? '${v.round()} km/h' : '-';

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.green, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Treino concluido!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(session.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 24),
                // Duas colunas com altura definida pelo conteudo: uma grade com
                // proporcao fixa cortava o texto quando a fonte do aparelho e maior.
                _TwoColumnTiles(
                  tiles: [
                    _SummaryTile(label: 'Duracao', value: session.durationLabel, icon: Icons.timer_outlined),
                    _SummaryTile(label: 'Tacadas', value: '${session.shotCount}', icon: Icons.sports_tennis_outlined),
                    _SummaryTile(label: 'Aces', value: '${session.aceCount}', icon: Icons.bolt_outlined),
                    // Raquete real: velocidade da RAQUETE (estimada, calculada pelo
                    // banco). Sem raquete real: velocidade da bola, como antes.
                    _SummaryTile(
                      label: session.hasRacketSpeed ? 'Vel. media da raquete' : 'Vel. media',
                      value: _kmh(session.hasRacketSpeed ? session.avgRacketSpeedKmh : session.avgBallSpeedKmh),
                      icon: Icons.speed_outlined,
                    ),
                    _SummaryTile(
                      label: session.hasRacketSpeed ? 'Vel. maxima da raquete' : 'Vel. maxima',
                      value: _kmh(session.hasRacketSpeed ? session.maxRacketSpeedKmh : session.maxBallSpeedKmh),
                      icon: Icons.trending_up,
                    ),
                    if (_stats != null) ...[
                      _SummaryTile(label: 'Forehand', value: '${_stats!.forehand}', icon: Icons.sports_tennis),
                      _SummaryTile(label: 'Backhand', value: '${_stats!.backhand}', icon: Icons.sports_tennis_outlined),
                      if (_stats!.saque > 0)
                        _SummaryTile(label: 'Saques', value: '${_stats!.saque}', icon: Icons.bolt_outlined),
                      _SummaryTile(label: 'Classificacao incerta', value: '${_stats!.incertas}', icon: Icons.help_outline),
                    ],
                    _SummaryTile(
                      label: 'Calorias',
                      value: session.calories != null ? '${session.calories} kcal' : '-',
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                    session.hasRacketSpeed
                        ? 'Velocidade da raquete ao longo do treino'
                        : 'Velocidade da bola ao longo do treino',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: _loadingEvents
                      ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                      : _events.isEmpty
                          ? const Center(
                              child: Text('Sem dados de telemetria', style: TextStyle(color: AppColors.textSecondary)))
                          : _SpeedChart(events: _events),
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: 'Voltar para o inicio', onPressed: _finish),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoColumnTiles extends StatelessWidget {
  const _TwoColumnTiles({required this.tiles});
  final List<Widget> tiles;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: _gap));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: _gap),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.events});
  final List<SessionEvent> events;

  @override
  Widget build(BuildContext context) {
    final speedEvents = events.where((e) => e.ballSpeedKmh != null).toList();
    final spots = <FlSpot>[
      for (var i = 0; i < speedEvents.length; i++) FlSpot(i.toDouble(), speedEvents[i].ballSpeedKmh!),
    ];
    if (spots.isEmpty) {
      return const Center(child: Text('Sem dados de velocidade', style: TextStyle(color: AppColors.textSecondary)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.green.withOpacity(0.3), AppColors.green.withOpacity(0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
