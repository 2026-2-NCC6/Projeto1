import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/dashboard.dart';
import 'dashboard_logic.dart';

/// Cores dos golpes. Verde, azul e ambar se distinguem mesmo para daltonicos
/// (nenhuma depende so de vermelho x verde) e funcionam no fundo preto.
const kForehandColor = AppColors.greenBright;
const kBackhandColor = Color(0xFF4DA3FF);
const kServeColor = AppColors.warning;

Color strokeColor(String tipo) => switch (tipo) {
      'FH' => kForehandColor,
      'BH' => kBackhandColor,
      _ => kServeColor,
    };

String strokeName(String tipo) => switch (tipo) {
      'FH' => 'Forehand',
      'BH' => 'Backhand',
      _ => 'Saque',
    };

String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Layout em blocos (bento)
// ---------------------------------------------------------------------------

/// Um bloco do painel. [span] e em colunas: 1 = bloco pequeno, 2 = painel,
/// [BentoItem.full] = linha inteira.
class BentoItem {
  const BentoItem(this.child, {this.span = 2});
  const BentoItem.full(this.child) : span = 99;
  const BentoItem.tile(this.child) : span = 1;

  final Widget child;
  final int span;
}

/// Grade que se adapta a largura: 2 colunas no celular, 4 em tela larga (web).
/// Os blocos de uma mesma linha ficam com a mesma altura.
class BentoGrid extends StatelessWidget {
  const BentoGrid({super.key, required this.items, this.gap = 12, this.wideBreakpoint = 760});
  final List<BentoItem> items;
  final double gap;
  final double wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= wideBreakpoint ? 4 : 2;
      final rows = <List<BentoItem>>[];
      var used = 0;
      for (final item in items) {
        final span = item.span.clamp(1, cols);
        if (rows.isEmpty || used + span > cols) {
          rows.add([]);
          used = 0;
        }
        rows.last.add(item);
        used += span;
      }

      return Column(children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    // A ultima peca de uma linha incompleta ocupa o que sobrou.
                    flex: i == row.length - 1
                        ? cols - row.sublist(0, i).fold<int>(0, (s, e) => s + e.span.clamp(1, cols))
                        : row[i].span.clamp(1, cols),
                    child: row[i].child,
                  ),
                ],
              ]),
            ),
          ),
      ]);
    });
  }
}

/// Cartao base: titulo, legenda opcional, acao a direita e conteudo.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = 16});
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
                ],
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        if (title != null) const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class SoftEmpty extends StatelessWidget {
  const SoftEmpty(this.message, {super.key, this.icon = Icons.insights_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 110,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.textDisabled, size: 26),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Pecas pequenas
// ---------------------------------------------------------------------------

class DeltaBadge extends StatelessWidget {
  const DeltaBadge({super.key, required this.delta, this.suffix = ''});
  final double delta;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final flat = delta.abs() < 0.5;
    final up = delta > 0;
    final color = flat ? AppColors.textSecondary : (up ? AppColors.greenBright : AppColors.error);
    final icon = flat ? Icons.remove : (up ? Icons.arrow_upward : Icons.arrow_downward);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text('${delta.abs().round()}%$suffix', style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Numero que "sobe" ate o valor quando aparece ou muda.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.suffix = ''});
  final num value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}$suffix', style: style),
      );
}

/// Barra horizontal dividida em partes proporcionais aos valores.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.parts, this.height = 12});
  final List<(num value, Color color)> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = parts.where((p) => p.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: shown.isEmpty
            ? Container(color: AppColors.surfaceElevated2)
            : Row(children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    // Cada parte ocupa a fatia real; o flex em permilagem preserva a proporcao.
                    flex: (shown[i].$1 * 1000).round().clamp(1, 1 << 30),
                    child: Container(color: shown[i].$2),
                  ),
                ],
              ]),
      ),
    );
  }
}

class _StrokeChip extends StatelessWidget {
  const _StrokeChip({required this.tipo, required this.count, required this.share, required this.selected, required this.onTap});
  final String tipo;
  final int count;
  final int share;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = strokeColor(tipo);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(strokeName(tipo), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('$share%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text('($count)', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartao principal
// ---------------------------------------------------------------------------

/// Resumo do periodo: tacadas, tendencia, divisao por golpe (toque para filtrar).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.data, required this.buckets, required this.onTipo});
  final DashboardData data;
  final List<ChartBucket> buckets;

  /// Chamado com `null` para limpar o filtro de golpe.
  final ValueChanged<String?> onTipo;

  @override
  Widget build(BuildContext context) {
    final k = data.kpis;
    final delta = deltaPct(k.tacadas, data.previous?.tacadas);
    final total = k.tacadas;
    final tipos = {'FH': data.forehand, 'BH': data.backhand, 'SQ': data.saque};
    final filtered = data.tipo != null;

    return Container(
      padding: const EdgeInsets.all(20),
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
        Row(children: [
          Expanded(
            child: Text(
              filtered ? '${strokeName(data.tipo!)} · ${periodLabel(data)}' : 'Tacadas · ${periodLabel(data)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (delta != null) DeltaBadge(delta: delta, suffix: ' vs. anterior'),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp(value: total, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(total == 1 ? 'tacada' : 'tacadas',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          if (buckets.length >= 2)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: SizedBox(height: 56, child: _Sparkline(values: [for (final b in buckets) b.value.toDouble()])),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        ShareBar(parts: [for (final e in tipos.entries) (e.value, strokeColor(e.key))], height: 14),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in tipos.entries)
            if (e.value > 0 || data.tipo == e.key)
              _StrokeChip(
                tipo: e.key,
                count: e.value,
                share: pct(e.value, total),
                selected: data.tipo == e.key,
                onTap: () => onTipo(data.tipo == e.key ? null : e.key),
              ),
          if (filtered)
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: const Text('Ver todos', style: TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.close, size: 14),
              onPressed: () => onTipo(null),
              backgroundColor: AppColors.surfaceElevated2,
              side: BorderSide.none,
            ),
        ]),
      ]),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxV == 0 ? 1 : maxV * 1.1,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: AppColors.greenBright,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.greenBright.withOpacity(0.18)),
        ),
      ],
    ));
  }
}

// ---------------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------------

class InsightsPanel extends StatelessWidget {
  const InsightsPanel({super.key, required this.insights});
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final i in insights)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _tone(i.tone).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tone(i.tone).withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i.icon, size: 16, color: _tone(i.tone)),
              const SizedBox(width: 8),
              Flexible(child: Text(i.text, style: const TextStyle(fontSize: 12.5, height: 1.3))),
            ]),
          ),
        ),
    ]);
  }

  static Color _tone(InsightTone t) => switch (t) {
        InsightTone.good => AppColors.greenBright,
        InsightTone.warn => AppColors.warning,
        InsightTone.neutral => AppColors.textSecondary,
      };
}

/// Indicador pequeno: valor, contexto e um anel de progresso proporcional.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
    this.delta,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  /// 0 a 1; null esconde o anel.
  final double? progress;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            if (delta != null)
              DeltaBadge(delta: delta!)
            else if (caption != null)
              Text(caption!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            if (progress != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 4.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surfaceElevated2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.green),
                ),
              ),
            Icon(icon, size: 17, color: AppColors.green),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Evolucao (volume / velocidade)
// ---------------------------------------------------------------------------

class EvolutionCard extends StatefulWidget {
  const EvolutionCard({super.key, required this.data, required this.buckets});
  final DashboardData data;
  final List<ChartBucket> buckets;

  @override
  State<EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<EvolutionCard> {
  bool _speed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final weekly = d.range == 'all' || d.days > 31;
    return Panel(
      title: 'Evolução',
      subtitle: _speed
          ? 'Velocidade média por dia (km/h, estimativa relativa)'
          : (weekly ? 'Tacadas por semana' : 'Tacadas por dia'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _Toggle(label: 'Volume', selected: !_speed, onTap: () => setState(() => _speed = false)),
        const SizedBox(width: 6),
        _Toggle(label: 'Velocidade', selected: _speed, onTap: () => setState(() => _speed = true)),
      ]),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_speed), child: _speed ? _speedLine(d) : _volumeBars(d)),
      ),
    );
  }

  Widget _volumeBars(DashboardData d) {
    final buckets = widget.buckets;
    if (buckets.isEmpty || buckets.every((b) => b.value == 0)) return const SoftEmpty('Sem tacadas neste período');
    if (d.kpis.diasAtivos <= 1) {
      // Um unico dia de treino: um grafico de barras vazio nao diz nada.
      final day = d.porDia.isEmpty ? null : d.porDia.first;
      return SoftEmpty(
        day == null
            ? 'Treine em mais dias para ver a evolução'
            : '${day.tacadas} tacadas em ${_dm(day.date)}.\nTreine em mais dias para ver a evolução.',
        icon: Icons.bar_chart,
      );
    }
    final maxV = buckets.fold<int>(0, (m, b) => b.value > m ? b.value : m);
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        maxY: maxV * 1.18,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated2,
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              buckets[group.x].tooltip,
              const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: _titles(buckets.length, (i) => buckets[i].label, every: (buckets.length / 8).ceil()),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: buckets[i].value.toDouble(),
                width: buckets.length > 14 ? 9 : 16,
                borderRadius: BorderRadius.circular(5),
                color: i == buckets.length - 1 ? AppColors.greenBright : AppColors.green.withOpacity(0.6),
              ),
            ]),
        ],
      )),
    );
  }

  Widget _speedLine(DashboardData d) {
    final pts = d.porDia.where((p) => p.velMedia != null).toList();
    final shown = pts.length > 40 ? pts.sublist(pts.length - 40) : pts;
    if (shown.length < 2) {
      return SoftEmpty(
        shown.isEmpty
            ? 'Sem velocidade registrada neste período'
            : 'Média de ${shown.first.velMedia!.round()} km/h em ${_dm(shown.first.date)}.\nTreine em mais dias para ver a evolução.',
        icon: Icons.speed,
      );
    }
    final vals = [for (final p in shown) p.velMedia!];
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV) * 0.3).clamp(3, 1000).toDouble();
    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minY: (minV - pad).clamp(0, 10000).toDouble(),
        maxY: maxV + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(v.round().toString(),
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 10.5)),
            ),
          ),
          bottomTitles: _titles(shown.length, (i) => _dm(shown[i].date), every: (shown.length / 5).ceil()).bottomTitles,
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated2,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${_dm(shown[s.x.toInt()].date)} · ${s.y.round()} km/h',
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.greenBright,
            barWidth: 3,
            dotData: FlDotData(show: shown.length <= 20),
            belowBarData: BarAreaData(show: true, color: AppColors.greenBright.withOpacity(0.12)),
          ),
        ],
      )),
    );
  }

  FlTitlesData _titles(int count, String Function(int) label, {int every = 1}) => FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (value != i.toDouble() || i < 0 || i >= count || i % every != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(label(i), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
              );
            },
          ),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : AppColors.surfaceElevated2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.black : AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Mix de golpes (pizza) + confianca
// ---------------------------------------------------------------------------

class MixCard extends StatelessWidget {
  const MixCard({super.key, required this.data, required this.onTipo});
  final DashboardData data;
  final ValueChanged<String?> onTipo;

  @override
  Widget build(BuildContext context) {
    final total = data.kpis.tacadas;
    final tipos = {'FH': data.forehand, 'BH': data.backhand, 'SQ': data.saque};
    final shown = tipos.entries.where((e) => e.value > 0).toList();
    final seguras = pct(data.certas, total);

    return Panel(
      title: 'Mix de golpes',
      subtitle: 'Toque num golpe para filtrar o painel',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (data.tipo == null && total > 0)
          Row(children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  sectionsSpace: shown.length > 1 ? 3 : 0,
                  centerSpaceRadius: 38,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final e in shown)
                      PieChartSectionData(value: e.value.toDouble(), color: strokeColor(e.key), radius: 24, showTitle: false),
                  ],
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const Text('tacadas', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                ]),
              ]),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                for (final e in tipos.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: e.value > 0 ? () => onTipo(e.key) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: strokeColor(e.key), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(strokeName(e.key), style: const TextStyle(fontSize: 13))),
                        Text('${pct(e.value, total)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ])
        else if (total == 0)
          const SoftEmpty('Sem tacadas neste período')
        else
          Text('Mostrando só ${strokeName(data.tipo!).toLowerCase()}. Toque em "Ver todos" no topo para voltar ao mix completo.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
        if (total > 0) ...[
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(
              child: Text('Classificação segura', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            Text('$seguras%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.green)),
          ]),
          const SizedBox(height: 6),
          ShareBar(parts: [(data.certas, AppColors.green), (data.incertas, AppColors.textDisabled)], height: 8),
          const SizedBox(height: 6),
          const Text('Incerta = perto do limite entre forehand e backhand',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Ritmo semanal
// ---------------------------------------------------------------------------

class WeekRhythmCard extends StatelessWidget {
  const WeekRhythmCard({super.key, required this.porDiaSemana});
  final List<int> porDiaSemana;

  @override
  Widget build(BuildContext context) {
    final total = porDiaSemana.fold<int>(0, (s, v) => s + v);
    if (porDiaSemana.length != 7 || total == 0) {
      return const Panel(title: 'Ritmo da semana', child: SoftEmpty('Sem tacadas neste período'));
    }
    final maxV = porDiaSemana.reduce((a, b) => a > b ? a : b);
    return Panel(
      title: 'Ritmo da semana',
      subtitle: 'Parte das tacadas em cada dia',
      child: SizedBox(
        height: 150,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  Text(porDiaSemana[i] == 0 ? '' : '${pct(porDiaSemana[i], total)}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: porDiaSemana[i] == maxV ? AppColors.greenBright : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: porDiaSemana[i] / maxV),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, f, __) => FractionallySizedBox(
                          heightFactor: f < 0.04 ? 0.04 : f,
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: porDiaSemana[i] == 0
                                  ? AppColors.surfaceElevated2
                                  : (porDiaSemana[i] == maxV ? AppColors.greenBright : AppColors.green.withOpacity(0.6)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(weekdayShort[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Treinos do periodo
// ---------------------------------------------------------------------------

class RecentSessionsCard extends StatelessWidget {
  const RecentSessionsCard({super.key, required this.sessoes});
  final List<DashboardSession> sessoes;

  @override
  Widget build(BuildContext context) {
    final list = sessoes.take(5).toList();
    if (list.isEmpty) return const Panel(title: 'Treinos no período', child: SoftEmpty('Nenhum treino neste período'));
    final maxT = list.fold<int>(1, (m, s) => s.tacadas > m ? s.tacadas : m);
    return Panel(
      title: 'Treinos no período',
      subtitle: 'O comprimento da barra é proporcional ao nº de tacadas',
      child: Column(children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _SessionRow(s: list[i], fraction: list[i].tacadas / maxT),
        ],
      ]),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.s, required this.fraction});
  final DashboardSession s;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final when = s.startedAt == null ? '' : _dm(s.startedAt!.toLocal());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(s.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
        const SizedBox(width: 8),
        Text(when, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      FractionallySizedBox(
        widthFactor: fraction.clamp(0.08, 1.0),
        alignment: Alignment.centerLeft,
        child: ShareBar(
          parts: [(s.forehand, kForehandColor), (s.backhand, kBackhandColor), (s.saque, kServeColor)],
          height: 10,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '${s.tacadas} tacadas'
        '${s.velMedia == null ? '' : ' · média ${s.velMedia!.round()} km/h'}'
        '${s.velMax == null ? '' : ' · pico ${s.velMax} km/h'}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
      ),
    ]);
  }
}
