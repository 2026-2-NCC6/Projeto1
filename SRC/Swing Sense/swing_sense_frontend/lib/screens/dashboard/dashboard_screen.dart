import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/dashboard.dart';
import '../../services/api_client.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import 'community_tab.dart';
import 'dashboard_logic.dart';
import 'dashboard_widgets.dart';

/// Aba "Dashboard": metricas das tacadas da raquete real. O periodo fica numa
/// barra fixa; o golpe se filtra tocando no resumo ou no mix de golpes.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const _maxCustomDays = 366;
  static const _maxContentWidth = 1100.0;
  static const _ranges = {'7d': '7d', '30d': '30d', '90d': '90d', 'all': 'Tudo'};

  final _service = DashboardService(ApiClient.instance);
  late final TabController _tabs = TabController(length: 2, vsync: this);

  DashboardFilter _filter = const DashboardFilter();

  DashboardData? _mine;
  List<LeaderboardEntry>? _board;
  String? _mineError;
  String? _boardError;
  bool _loadingMine = true;
  bool _loadingBoard = true;

  // Descarta respostas antigas quando o usuario troca de filtro rapidamente.
  int _mineRequest = 0;
  int _boardRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadMine();
    _loadBoard();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    final id = ++_mineRequest;
    setState(() {
      _loadingMine = true;
      _mineError = null;
    });
    try {
      final data = await _service.mine(_filter);
      if (mounted && id == _mineRequest) setState(() => _mine = data);
    } on ApiException catch (e) {
      if (mounted && id == _mineRequest) setState(() => _mineError = e.message);
    } catch (_) {
      if (mounted && id == _mineRequest) setState(() => _mineError = 'Não foi possível carregar. Verifique a conexão.');
    } finally {
      if (mounted && id == _mineRequest) setState(() => _loadingMine = false);
    }
  }

  Future<void> _loadBoard() async {
    final id = ++_boardRequest;
    setState(() {
      _loadingBoard = true;
      _boardError = null;
    });
    try {
      final entries = await _service.leaderboard(_filter);
      if (mounted && id == _boardRequest) setState(() => _board = entries);
    } on ApiException catch (e) {
      if (mounted && id == _boardRequest) setState(() => _boardError = e.message);
    } catch (_) {
      if (mounted && id == _boardRequest) setState(() => _boardError = 'Não foi possível carregar. Verifique a conexão.');
    } finally {
      if (mounted && id == _boardRequest) setState(() => _loadingBoard = false);
    }
  }

  void _setRange(String range) {
    if (_filter.range == range) return;
    setState(() => _filter = _filter.copyWith(range: range));
    _loadMine();
    _loadBoard();
  }

  void _setTipo(String? tipo) {
    if (_filter.tipo == tipo) return;
    setState(() => _filter = _filter.copyWith(tipo: tipo, clearTipo: tipo == null));
    _loadMine();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _filter.isCustom ? DateTimeRange(start: _filter.customFrom!, end: _filter.customTo!) : null,
      helpText: 'Escolha o período',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    if (picked.end.difference(picked.start).inDays + 1 > _maxCustomDays) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O período máximo é de 366 dias.')));
      return;
    }
    setState(() => _filter = _filter.copyWith(range: 'custom', customFrom: picked.start, customTo: picked.end));
    _loadMine();
    _loadBoard();
  }

  static String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.green,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'Meu desempenho'), Tab(text: 'Comunidade')],
        ),
      ),
      body: Column(children: [
        _buildPeriodBar(),
        Expanded(child: TabBarView(controller: _tabs, children: [_buildMineTab(), _buildCommunityTab()])),
      ]),
    );
  }

  /// Seletor de periodo em segmentos de largura igual, centralizado e limitado.
  Widget _buildPeriodBar() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              for (final e in _ranges.entries) Expanded(child: _segment(e.value, _filter.range == e.key, () => _setRange(e.key))),
              Expanded(
                flex: 2,
                child: _segment(
                  _filter.isCustom ? '${_dm(_filter.customFrom!)} - ${_dm(_filter.customTo!)}' : 'Datas',
                  _filter.range == 'custom',
                  _pickCustomRange,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    final color = selected ? Colors.black : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: selected ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _error(String message, VoidCallback retry) => ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: EmptyState(
            icon: Icons.cloud_off,
            title: 'Algo deu errado',
            message: message,
            action: OutlinedButton(onPressed: retry, child: const Text('Tentar de novo')),
          ),
        ),
      ]);

  /// Conteudo centralizado com largura maxima, para nao esticar em tela larga.
  Widget _page({required Future<void> Function() onRefresh, required bool loading, required List<Widget> children}) {
    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: Stack(children: [
        ListView(padding: const EdgeInsets.only(bottom: 28), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: children)),
            ),
          ),
        ]),
        if (loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
      ]),
    );
  }

  Widget _buildMineTab() {
    final data = _mine;
    if (data == null) {
      if (_mineError != null) return _error(_mineError!, _loadMine);
      return const Center(child: SwingSenseLoader());
    }
    return _page(onRefresh: _loadMine, loading: _loadingMine, children: _mineContent(data));
  }

  List<Widget> _mineContent(DashboardData data) {
    if (_mineError != null) {
      return [Text(_mineError!, style: const TextStyle(color: AppColors.error))];
    }
    if (data.isEmpty) {
      return [
        const SizedBox(height: 40),
        EmptyState(
          icon: Icons.bar_chart,
          title: 'Sem tacadas neste período',
          message: _filter.tipo == null
              ? 'Treine com a raquete conectada para ver suas métricas, ou escolha um período maior.'
              : 'Nenhuma tacada desse golpe no período. Toque em "Ver todos" ou escolha um período maior.',
          action: _filter.tipo == null ? null : OutlinedButton(onPressed: () => _setTipo(null), child: const Text('Ver todos')),
        ),
      ];
    }

    // "Hoje" em Brasilia (UTC-3), o mesmo fuso em que o servidor conta os dias.
    final today = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final buckets = bucketize(data, today: today);
    final insights = buildInsights(data, today: today);
    final k = data.kpis, p = data.previous;
    final days = daysInPeriod(data, today: today);

    return [
      BentoGrid(items: [
        BentoItem.full(HeroCard(data: data, buckets: buckets, onTipo: _setTipo)),
        if (insights.isNotEmpty) BentoItem.full(InsightsPanel(insights: insights)),
        BentoItem.tile(StatTile(
          icon: Icons.speed,
          label: 'Velocidade média',
          value: k.velMedia == null ? '-' : '${k.velMedia!.round()} km/h',
          caption: k.velMax == null ? null : 'pico ${k.velMax} km/h',
          progress: (k.velMedia != null && k.velMax != null && k.velMax! > 0) ? k.velMedia! / k.velMax! : null,
          delta: k.velMedia == null ? null : deltaPct(k.velMedia!, p?.velMedia),
        )),
        BentoItem.tile(StatTile(
          icon: Icons.event_available,
          label: 'Treinos',
          value: '${k.sessoes}',
          caption: k.sessoes == 0 ? null : '${(k.tacadas / k.sessoes).round()} tacadas por treino',
          delta: deltaPct(k.sessoes, p?.sessoes),
        )),
        BentoItem.tile(StatTile(
          icon: Icons.timer_outlined,
          label: 'Tempo de treino',
          value: formatDuration(k.tempoSegundos),
          caption: k.sessoes == 0 ? null : 'média ${formatDuration((k.tempoSegundos / k.sessoes).round())} por treino',
          delta: deltaPct(k.tempoSegundos, p?.tempoSegundos),
        )),
        BentoItem.tile(StatTile(
          icon: Icons.local_fire_department_outlined,
          label: 'Dias ativos',
          value: days == null ? '${k.diasAtivos}' : '${k.diasAtivos} de $days',
          caption: days == null ? 'em todo o histórico' : '${pct(k.diasAtivos, days)}% do período',
          progress: days == null ? null : k.diasAtivos / days,
        )),
        BentoItem(EvolutionCard(data: data, buckets: buckets)),
        BentoItem(MixCard(data: data, onTipo: _setTipo)),
        BentoItem(WeekRhythmCard(porDiaSemana: data.porDiaSemana)),
        BentoItem(RecentSessionsCard(sessoes: data.sessoes)),
      ]),
    ];
  }

  Widget _buildCommunityTab() {
    final entries = _board;
    if (entries == null) {
      if (_boardError != null) return _error(_boardError!, _loadBoard);
      return const Center(child: SwingSenseLoader());
    }
    return _page(
      onRefresh: _loadBoard,
      loading: _loadingBoard,
      children: [CommunityTab(entries: entries, allTime: _filter.range == 'all')],
    );
  }
}
