import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/session_event.dart';
import '../../models/training_session.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
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
  List<SessionEvent> _events = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    _SummaryTile(label: 'Duracao', value: session.durationLabel, icon: Icons.timer_outlined),
                    _SummaryTile(label: 'Tacadas', value: '${session.shotCount}', icon: Icons.sports_tennis_outlined),
                    _SummaryTile(label: 'Aces', value: '${session.aceCount}', icon: Icons.bolt_outlined),
                    _SummaryTile(
                      label: 'Vel. media',
                      value: session.avgBallSpeedKmh != null ? '${session.avgBallSpeedKmh!.round()} km/h' : '-',
                      icon: Icons.speed_outlined,
                    ),
                    _SummaryTile(
                      label: 'Vel. maxima',
                      value: session.maxBallSpeedKmh != null ? '${session.maxBallSpeedKmh!.round()} km/h' : '-',
                      icon: Icons.trending_up,
                    ),
                    _SummaryTile(
                      label: 'Calorias',
                      value: session.calories != null ? '${session.calories} kcal' : '-',
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Velocidade da bola ao longo do treino',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
