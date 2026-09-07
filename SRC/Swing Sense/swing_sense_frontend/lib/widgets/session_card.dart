import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/training_session.dart';
import 'user_avatar.dart';

/// Card de sessao de treino com visual inspirado em Instagram/Strava: banner
/// de destaque com a estatistica principal, numeros grandes no estilo
/// "atividade" e curtida animada.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.onLike,
    this.onComment,
    this.onOpenProfile,
    this.showUser = true,
  });

  final TrainingSession session;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onOpenProfile;
  final bool showUser;

  static const _bannerGradients = [
    [Color(0xFF12331F), AppColors.green],
    [AppColors.greenDark, Color(0xFF0B1F13)],
    [Color(0xFF0E2C1B), AppColors.greenBright],
    [AppColors.green, Color(0xFF0A1F12)],
    [Color(0xFF163A22), AppColors.greenDark],
  ];

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'ha ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'ha ${diff.inHours}h';
    if (diff.inDays < 7) return 'ha ${diff.inDays}d';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _bannerGradients[session.id.hashCode.abs() % _bannerGradients.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showUser) _Header(session: session, onTap: onOpenProfile, timeAgo: _timeAgo(session.startedAt)),
          _CoverBanner(session: session, colors: gradientColors),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              session.trainingTitle ?? session.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _BigStat(value: session.durationLabel, label: 'DURACAO'),
                const _StatDivider(),
                _BigStat(value: '${session.shotCount}', label: 'TACADAS'),
                const _StatDivider(),
                _BigStat(
                  value: session.calories != null ? '${session.calories}' : '-',
                  label: 'KCAL',
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 10),
            child: Row(
              children: [
                _LikeButton(liked: session.likedByMe, count: session.likeCount, onTap: onLike),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: '${session.commentCount}',
                  onTap: onComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.timeAgo, this.onTap});
  final TrainingSession session;
  final String timeAgo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(gradient: AppColors.greenGradient, shape: BoxShape.circle),
              child: UserAvatar(name: session.userName ?? '?', imageUrl: session.userAvatarUrl, radius: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.userName ?? 'Jogador',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(timeAgo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverBanner extends StatelessWidget {
  const _CoverBanner({required this.session, required this.colors});
  final TrainingSession session;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final hasSpeed = session.avgBallSpeedKmh != null;
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
          ),
          Positioned(
            right: -18,
            top: -18,
            child: Icon(Icons.sports_tennis, size: 140, color: Colors.black.withOpacity(0.12)),
          ),
          if (session.aceCount > 0)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('${session.aceCount} ace${session.aceCount > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 14,
            bottom: 12,
            child: hasSpeed
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${session.avgBallSpeedKmh!.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 6),
                        child: Text('km/h · vel. media',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ],
                  )
                : const Text('Treino registrado',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.border,
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({required this.liked, required this.count, this.onTap});
  final bool liked;
  final int count;
  final VoidCallback? onTap;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.liked ? AppColors.green : AppColors.textSecondary;
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(widget.liked ? Icons.favorite : Icons.favorite_border, size: 22, color: color),
            ),
            const SizedBox(width: 6),
            Text('${widget.count}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
