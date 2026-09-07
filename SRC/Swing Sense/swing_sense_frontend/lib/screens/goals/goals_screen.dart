import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/goal.dart';
import '../../models/training_session.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../state/auth_provider.dart';
import '../../state/goals_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import 'create_goal_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _userService = UserService(ApiClient.instance);
  List<TrainingSession> _sessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsProvider>().load();
      _loadSessions();
    });
  }

  Future<void> _loadSessions() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    try {
      final sessions = await _userService.sessionsOf(userId);
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  Future<void> _refresh() async {
    await context.read<GoalsProvider>().load();
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGoalScreen()));
              if (mounted) context.read<GoalsProvider>().load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.green,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: provider.isLoading && provider.goals.isEmpty
            ? const Center(child: SwingSenseLoader())
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (provider.goals.isNotEmpty) _SummaryHeader(goals: provider.goals),
                  if (!_loadingSessions && _sessions.isNotEmpty) ...[
                    _SectionTitle('Frequencia de treino (6 semanas)'),
                    _WeeklyFrequencyChart(sessions: _sessions),
                    _SectionTitle('Evolucao da velocidade media'),
                    _SpeedTrendChart(sessions: _sessions),
                  ],
                  _SectionTitle('Suas metas'),
                  if (provider.goals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: EmptyState(
                        icon: Icons.flag_outlined,
                        title: 'Nenhuma meta ainda',
                        message: 'Crie metas de velocidade, frequencia ou tempo de treino e acompanhe sua evolucao.',
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: provider.goals.map((g) => _GoalCard(goal: g)).toList(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.goals});
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final avgProgress = goals.isEmpty ? 0.0 : goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;
    final completed = goals.where((g) => g.isCompleted).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: avgProgress,
                    strokeWidth: 7,
                    backgroundColor: AppColors.surfaceElevated2,
                    valueColor: const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                Text('${(avgProgress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progresso geral', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  '${goals.length} meta${goals.length == 1 ? '' : 's'} ativa${goals.length == 1 ? '' : 's'} · $completed concluida${completed == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

class _WeeklyFrequencyChart extends StatelessWidget {
  const _WeeklyFrequencyChart({required this.sessions});
  final List<TrainingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeekStart = _weekStart(now);
    final weeks = List.generate(6, (i) => currentWeekStart.subtract(Duration(days: 7 * (5 - i))));

    final counts = <int>[];
    for (final weekStart in weeks) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = sessions.where((s) {
        final started = s.startedAt;
        return started != null && !started.isBefore(weekStart) && started.isBefore(weekEnd);
      }).length;
      counts.add(count);
    }
    final maxCount = counts.fold<int>(1, (max, c) => c > max ? c : max);

    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: (maxCount + 1).toDouble(),
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= weeks.length) return const SizedBox.shrink();
                  final isCurrent = index == weeks.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isCurrent ? 'Essa' : 'S-${weeks.length - 1 - index}',
                      style: TextStyle(
                        color: isCurrent ? AppColors.green : AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < counts.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                    color: i == counts.length - 1 ? AppColors.greenBright : AppColors.green.withOpacity(0.55),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedTrendChart extends StatelessWidget {
  const _SpeedTrendChart({required this.sessions});
  final List<TrainingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final withSpeed = sessions.where((s) => s.avgBallSpeedKmh != null && s.startedAt != null).toList()
      ..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
    final recent = withSpeed.length > 8 ? withSpeed.sublist(withSpeed.length - 8) : withSpeed;

    if (recent.isEmpty) {
      return Container(
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Text('Conclua treinos para ver sua evolucao aqui',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      );
    }

    final spots = [for (var i = 0; i < recent.length; i++) FlSpot(i.toDouble(), recent[i].avgBallSpeedKmh!)];

    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.green,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(color: AppColors.greenBright, radius: 3.5, strokeWidth: 0),
              ),
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
      ),
    );
  }
}

String _tipFor(Goal goal) {
  final progress = goal.progress;
  switch (goal.type) {
    case 'sessions_per_week':
      if (progress >= 1) return 'Meta batida! Que tal subir a fasquia e treinar uma vez a mais por semana?';
      if (progress >= 0.5) return 'Voce esta quase la — mais uma sessao essa semana fecha a meta.';
      return 'Tente encaixar um treino curto extra essa semana. Consistencia pesa mais que treinos longos e raros.';
    case 'avg_ball_speed':
      if (progress >= 1) return 'Excelente velocidade! Foque agora em manter essa consistencia em jogos.';
      if (progress >= 0.5) {
        return 'Voce esta perto do objetivo. Treinos de explosao de perna e giro de quadril ajudam a ganhar os ultimos km/h.';
      }
      return 'Priorize o timing de contato com a bola antes de forca bruta — a tecnica de base rende mais velocidade.';
    case 'total_minutes':
      if (progress >= 1) return 'Meta de tempo batida! Considere mirar em mais horas no proximo ciclo.';
      if (progress >= 0.5) return 'Faltam poucos minutos. Um treino um pouco mais longo essa semana resolve.';
      return 'Sessoes de 40-60min ajudam a acumular minutos sem precisar treinar todo dia.';
    default:
      if (progress >= 1) return 'Meta concluida! Bom trabalho — crie a proxima.';
      if (progress >= 0.5) return 'Voce esta na metade do caminho. Continue no ritmo atual.';
      return 'Registre seus treinos com regularidade para essa meta evoluir mais rapido.';
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'sessions_per_week':
      return Icons.event_repeat;
    case 'avg_ball_speed':
      return Icons.speed_outlined;
    case 'total_minutes':
      return Icons.timer_outlined;
    default:
      return Icons.flag_outlined;
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final percent = (goal.progress * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(goal.type), size: 18, color: AppColors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (goal.isCompleted)
                const Icon(Icons.emoji_events, color: AppColors.green, size: 20)
              else
                Text('$percent%', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated2,
              color: goal.isCompleted ? AppColors.greenBright : AppColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${goal.currentValue.toStringAsFixed(goal.currentValue % 1 == 0 ? 0 : 1)} de '
            '${goal.targetValue.toStringAsFixed(goal.targetValue % 1 == 0 ? 0 : 1)} ${goal.unit}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tipFor(goal),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
