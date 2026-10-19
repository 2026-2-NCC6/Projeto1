import 'package:flutter/material.dart';

import '../animation/scene3d.dart';
import '../core/theme/app_colors.dart';
import 'drill_painter.dart';

/// Animacao em loop de um exercicio, dentro de uma quadra, com a fase atual,
/// barra de progresso por fase, pausa (toque) e camera lenta.
class DrillAnimationView extends StatefulWidget {
  const DrillAnimationView({super.key, required this.animation});
  final DrillAnimation animation;

  @override
  State<DrillAnimationView> createState() => _DrillAnimationViewState();
}

class _DrillAnimationViewState extends State<DrillAnimationView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _playing = true;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)..repeat();
  }

  Duration get _duration => Duration(milliseconds: (widget.animation.durationMs * (_slow ? 2.2 : 1.0)).round());

  @override
  void didUpdateWidget(covariant DrillAnimationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _controller
        ..duration = _duration
        ..value = 0;
      if (_playing) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  void _toggleSlow() {
    setState(() => _slow = !_slow);
    _controller.duration = _duration;
    if (_playing) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final anim = widget.animation;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.12), blurRadius: 24, spreadRadius: -4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: RepaintBoundary(
                  child: CustomPaint(painter: DrillPainter(anim, _controller)),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                right: 12,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final label = anim.sample(_controller.value).label ?? '';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.62),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.green.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 8, color: AppColors.greenBright),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_playing)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => _PhaseBar(
                          count: anim.phases.length,
                          current: anim.sample(_controller.value).phaseIndex,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RoundButton(
                      icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      onTap: _togglePlay,
                    ),
                    const SizedBox(width: 8),
                    _RoundButton(
                      icon: Icons.slow_motion_video_rounded,
                      selected: _slow,
                      onTap: _toggleSlow,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final color = i == current
            ? AppColors.greenBright
            : i < current
                ? AppColors.green.withOpacity(0.55)
                : Colors.white.withOpacity(0.22);
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        );
      }),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.selected = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.green : Colors.black.withOpacity(0.62),
          border: Border.all(color: selected ? AppColors.greenBright : Colors.white24),
        ),
        child: Icon(icon, size: 19, color: selected ? Colors.black : Colors.white),
      ),
    );
  }
}
