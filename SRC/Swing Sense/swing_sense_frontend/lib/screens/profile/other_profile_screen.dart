import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/training_session.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/session_card.dart';
import '../../widgets/user_avatar.dart';

class OtherProfileScreen extends StatefulWidget {
  const OtherProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final _userService = UserService(ApiClient.instance);
  AppUser? _user;
  List<TrainingSession> _sessions = [];
  bool _loading = true;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _userService.getUser(widget.userId),
        _userService.sessionsOf(widget.userId),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0] as AppUser;
          _sessions = results[1] as List<TrainingSession>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final user = _user;
    if (user == null) return;
    setState(() => _followBusy = true);
    try {
      if (user.followedByMe) {
        await _userService.unfollow(user.id);
      } else {
        await _userService.follow(user.id);
      }
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: SwingSenseLoader()));
    }
    final user = _user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuario nao encontrado')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                UserAvatar(name: user.name, imageUrl: user.avatarUrl, radius: 44),
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
                    _Stat(label: 'Treinos', value: '${user.sessionsCount}'),
                    _Stat(label: 'Seguidores', value: '${user.followersCount}'),
                    _Stat(label: 'Seguindo', value: '${user.followingCount}'),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: user.followedByMe
                      ? OutlinedButton.icon(
                          onPressed: _followBusy ? null : _toggleFollow,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Seguindo'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _followBusy ? null : _toggleFollow,
                          icon: const Icon(Icons.person_add_alt, size: 18, color: Colors.black),
                          label: const Text('Seguir'),
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
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: EmptyState(icon: Icons.history, title: 'Nenhum treino ainda', message: 'Este jogador ainda nao registrou treinos.'),
            )
          else
            ..._sessions.map((s) => SessionCard(session: s, showUser: false)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
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
