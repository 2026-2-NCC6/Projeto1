import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/dashboard.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_pill.dart';
import '../../widgets/user_avatar.dart';
import '../profile/other_profile_screen.dart';
import 'dashboard_logic.dart';
import 'dashboard_widgets.dart';

/// Comparacao entre o usuario e quem ele segue: resumo do grupo, podio e ranking
/// completo, todos proporcionais a metrica escolhida.
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key, required this.entries, required this.allTime});
  final List<LeaderboardEntry> entries;

  /// Em "Tudo" nao ha periodo anterior, entao a evolucao nao existe.
  final bool allTime;

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  LeaderboardMetric _metric = LeaderboardMetric.tacadas;

  LeaderboardMetric get _effective =>
      widget.allTime && _metric == LeaderboardMetric.evolucao ? LeaderboardMetric.tacadas : _metric;

  /// Metricas que somam (a parte de cada um no grupo faz sentido); evolucao nao soma.
  bool get _additive => _effective != LeaderboardMetric.evolucao;

  String _format(LeaderboardMetric m, LeaderboardEntry e) => switch (m) {
        LeaderboardMetric.tacadas => '${e.tacadas}',
        LeaderboardMetric.constancia => '${e.diasAtivos} ${e.diasAtivos == 1 ? 'dia' : 'dias'}',
        LeaderboardMetric.tempo => formatDuration(e.tempoSegundos),
        LeaderboardMetric.evolucao => e.evolucaoPct == null ? '-' : '${e.evolucaoPct! > 0 ? '+' : ''}${e.evolucaoPct!.round()}%',
      };

  String _formatValue(LeaderboardMetric m, double v) => switch (m) {
        LeaderboardMetric.tacadas => '${v.round()}',
        LeaderboardMetric.constancia => '${v.round()} dias',
        LeaderboardMetric.tempo => formatDuration(v.round()),
        LeaderboardMetric.evolucao => '${v > 0 ? '+' : ''}${v.round()}%',
      };

  @override
  Widget build(BuildContext context) {
    final metric = _effective;
    if (widget.entries.length <= 1) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: 'Siga outros jogadores',
          message: 'Quando você seguir alguém, vocês aparecem juntos aqui para comparar treinos e evolução.',
        ),
      );
    }

    // Quem nao tem dado na metrica (null) vai para o fim; o resto, do maior para o menor.
    final sorted = [...widget.entries]..sort((a, b) {
        final va = metric.valueOf(a), vb = metric.valueOf(b);
        if (va == null && vb == null) return a.name.compareTo(b.name);
        if (va == null) return 1;
        if (vb == null) return -1;
        final c = vb.compareTo(va);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    final values = [for (final e in sorted) metric.valueOf(e)];
    final maxAbs = values.fold<double>(0, (m, v) => (v?.abs() ?? 0) > m ? v!.abs() : m);
    final withData = [for (var i = 0; i < sorted.length; i++) if ((values[i] ?? 0) != 0) i];
    final total = values.fold<double>(0, (s, v) => s + (v != null && v > 0 ? v : 0));
    final myIndex = sorted.indexWhere((e) => e.isMe);
    final me = sorted[myIndex];
    final myValue = metric.valueOf(me);
    final hasMyData = myValue != null && myValue != 0;

    final podium = withData.take(3).toList();
    final restStart = podium.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final m in LeaderboardMetric.values)
              if (!(widget.allTime && m == LeaderboardMetric.evolucao))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipTag(label: m.label, selected: m == metric, onTap: () => setState(() => _metric = m)),
                ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      BentoGrid(items: [
        BentoItem(_GroupSummary(
          metric: metric,
          additive: _additive,
          people: sorted.length,
          position: hasMyData ? myIndex + 1 : null,
          myValue: myValue == null ? null : _formatValue(metric, myValue),
          myShare: _additive && total > 0 && myValue != null ? myValue / total : null,
          groupTotal: _additive ? _formatValue(metric, total) : null,
          groupAvg: _avg(values, metric),
        )),
        BentoItem(
          podium.length >= 2
              ? _Podium(
                  entries: [for (final i in podium) sorted[i]],
                  fractions: [for (final i in podium) maxAbs == 0 ? 0 : (values[i]!.abs() / maxAbs)],
                  labels: [for (final i in podium) _format(metric, sorted[i])],
                )
              : const Panel(title: 'Pódio', child: SoftEmpty('Ainda não há dados suficientes neste período', icon: Icons.emoji_events_outlined)),
        ),
        BentoItem.full(Panel(
          title: 'Ranking completo',
          subtitle: _additive
              ? 'Barra = proporção do líder · % = parte no total do grupo'
              : 'Evolução = variação da velocidade média contra o período anterior. A velocidade é uma estimativa relativa, '
                  'por isso cada pessoa é comparada com ela mesma.',
          child: Column(children: [
            for (var i = 0; i < sorted.length; i++)
              _RankRow(
                position: i + 1,
                entry: sorted[i],
                valueLabel: _format(metric, sorted[i]),
                fraction: maxAbs == 0 ? 0 : ((values[i]?.abs() ?? 0) / maxAbs).clamp(0.0, 1.0),
                negative: (values[i] ?? 0) < 0,
                share: _additive && total > 0 && (values[i] ?? 0) > 0 ? pct(values[i]!, total) : null,
                highlightTop: i < restStart && podium.contains(i),
              ),
          ]),
        )),
      ]),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Text(
          'Só aparecem você e quem você segue. Treinos de demonstração não contam.',
          style: TextStyle(color: AppColors.textDisabled, fontSize: 11.5),
        ),
      ),
    ]);
  }

  /// Media do grupo entre quem tem dado na metrica (ignora quem nao tem).
  String? _avg(List<double?> values, LeaderboardMetric metric) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return null;
    return _formatValue(metric, present.reduce((a, b) => a + b) / present.length);
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({
    required this.metric,
    required this.additive,
    required this.people,
    required this.position,
    required this.myValue,
    required this.myShare,
    required this.groupTotal,
    required this.groupAvg,
  });

  final LeaderboardMetric metric;
  final bool additive;
  final int people;
  final int? position;
  final String? myValue;
  final double? myShare;
  final String? groupTotal;
  final String? groupAvg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16402A), Color(0xFF0C1A12)],
        ),
        border: Border.all(color: AppColors.green.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sua posição em ${metric.label.toLowerCase()}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (position == null)
            const Text('Sem dados', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))
          else ...[
            CountUp(value: position!, suffix: 'º', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, height: 1.05)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('de $people', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        if (additive && myShare != null) ...[
          ShareBar(parts: [(myShare!, AppColors.greenBright), (1 - myShare!, AppColors.surfaceElevated2)], height: 12),
          const SizedBox(height: 8),
          Text('Você representa ${(myShare! * 100).round()}% do total do grupo',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
        Wrap(spacing: 18, runSpacing: 8, children: [
          if (myValue != null) _mini('Você', myValue!),
          if (groupAvg != null) _mini('Média do grupo', groupAvg!),
          if (groupTotal != null) _mini('Total do grupo', groupTotal!),
        ]),
      ]),
    );
  }

  Widget _mini(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ]);
}

/// Podio com colunas de altura proporcional ao valor (1o no centro).
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.fractions, required this.labels});
  final List<LeaderboardEntry> entries;
  final List<double> fractions;
  final List<String> labels;

  static const _maxBar = 110.0;

  @override
  Widget build(BuildContext context) {
    // Ordem visual: 2o, 1o, 3o.
    final order = entries.length >= 3 ? [1, 0, 2] : [1, 0];
    return Panel(
      title: 'Pódio',
      child: SizedBox(
        height: _maxBar + 96,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final i in order)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  UserAvatar(name: entries[i].name, imageUrl: entries[i].avatarUrl, radius: i == 0 ? 24 : 20),
                  const SizedBox(height: 6),
                  Text(entries[i].isMe ? 'Você' : entries[i].name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: entries[i].isMe ? AppColors.greenBright : null)),
                  Text(labels[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fractions[i]),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (_, f, __) => Container(
                      height: 28 + (_maxBar - 28) * f,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.greenBright : AppColors.green.withOpacity(0.55),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.position,
    required this.entry,
    required this.valueLabel,
    required this.fraction,
    required this.negative,
    required this.share,
    required this.highlightTop,
  });

  final int position;
  final LeaderboardEntry entry;
  final String valueLabel;
  final double fraction;
  final bool negative;
  final int? share;
  final bool highlightTop;

  @override
  Widget build(BuildContext context) {
    final color = negative ? AppColors.error : (entry.isMe ? AppColors.greenBright : AppColors.green.withOpacity(0.7));
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: entry.isMe
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtherProfileScreen(userId: entry.userId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isMe ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: entry.isMe ? AppColors.green : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: 24,
            child: Text('$position',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: position == 1 && highlightTop ? AppColors.warning : AppColors.textSecondary)),
          ),
          UserAvatar(name: entry.name, imageUrl: entry.avatarUrl, radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.isMe ? '${entry.name} (você)' : entry.name,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, f, __) => LinearProgressIndicator(
                    value: f,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceElevated2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            if (share != null) Text('$share%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}
