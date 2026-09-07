import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/training_session.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../state/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/session_card.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService(ApiClient.instance);
  List<TrainingSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshCurrentUser();
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    try {
      final sessions = await _userService.sessionsOf(userId);
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: SwingSenseLoader()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.green,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.surfaceElevated2,
                    child: Text(
                      user.initials,
                      style: const TextStyle(color: AppColors.green, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    [user.levelLabel, if (user.city != null) user.city].join(' - '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(user.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ProfileStat(label: 'Treinos', value: '${user.sessionsCount}'),
                      _ProfileStat(label: 'Seguidores', value: '${user.followersCount}'),
                      _ProfileStat(label: 'Seguindo', value: '${user.followingCount}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
                        );
                        _load();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar perfil'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Historico de treinos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: SwingSenseLoader(size: 48)))
            else if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: EmptyState(
                  icon: Icons.history,
                  title: 'Nenhum treino registrado',
                  message: 'Seus treinos concluidos aparecerao aqui.',
                ),
              )
            else
              ..._sessions.map((s) => SessionCard(session: s, showUser: false)),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
