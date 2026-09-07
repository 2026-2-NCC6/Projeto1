import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/training.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/training_service.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stat_pill.dart';
import '../../widgets/user_avatar.dart';
import '../profile/other_profile_screen.dart';
import '../training/training_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _trainingService = TrainingService(ApiClient.instance);
  final _userService = UserService(ApiClient.instance);
  final _searchController = TextEditingController();

  List<Training> _trainings = [];
  List<AppUser> _users = [];
  String? _difficultyFilter;
  bool _loadingTrainings = true;
  bool _searching = false;
  Timer? _debounce;

  static const _difficulties = {
    'iniciante': 'Iniciante',
    'intermediario': 'Intermediario',
    'avancado': 'Avancado',
  };

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrainings() async {
    setState(() => _loadingTrainings = true);
    try {
      final result = await _trainingService.list(difficulty: _difficultyFilter);
      if (mounted) setState(() => _trainings = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTrainings = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isEmpty) {
        setState(() => _users = []);
        return;
      }
      setState(() => _searching = true);
      try {
        final result = await _userService.search(query.trim());
        if (mounted) setState(() => _users = result);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar jogadores por nome',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildUserResults(),
            const Divider(height: 32, indent: 16, endIndent: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('Catalogo de treinos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipTag(
                    label: 'Todos',
                    selected: _difficultyFilter == null,
                    onTap: () {
                      setState(() => _difficultyFilter = null);
                      _loadTrainings();
                    },
                  ),
                ),
                ..._difficulties.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChipTag(
                      label: e.value,
                      selected: _difficultyFilter == e.key,
                      onTap: () {
                        setState(() => _difficultyFilter = e.key);
                        _loadTrainings();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingTrainings)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: SwingSenseLoader(size: 48)))
          else if (_trainings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(icon: Icons.sports_tennis, title: 'Nenhum treino', message: 'Nenhum treino encontrado para este filtro.'),
            )
          else
            ..._trainings.map((t) => _TrainingCard(training: t)),
        ],
      ),
    );
  }

  Widget _buildUserResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (_users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('Nenhum jogador encontrado', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      children: _users
          .map(
            (u) => ListTile(
              leading: UserAvatar(name: u.name, imageUrl: u.avatarUrl, radius: 20),
              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(u.levelLabel, style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OtherProfileScreen(userId: u.id)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.training});
  final Training training;

  Color get _color {
    try {
      return Color(int.parse('FF${training.coverColor}', radix: 16));
    } catch (_) {
      return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrainingDetailScreen(trainingId: training.id)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: _color.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.sports_tennis, color: _color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(training.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '${training.difficultyLabel} - ${training.durationMinutes} min',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
