import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Indicador de carregamento animado com a identidade do Swing Sense: um
/// anel verde girando ao redor de uma bolinha de tenis estilizada, com leve
/// pulsacao. Usado na splash screen e em pontos de loading do app.
class SwingSenseLoader extends StatefulWidget {
  const SwingSenseLoader({super.key, this.size = 72});
  final double size;

  @override
  State<SwingSenseLoader> createState() => _SwingSenseLoaderState();
}

class _SwingSenseLoaderState extends State<SwingSenseLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = 0.92 + 0.08 * (0.5 + 0.5 * (1 - (2 * _controller.value - 1).abs()));
        return Transform.scale(
          scale: pulse,
          child: Transform.rotate(
            angle: _controller.value * 6.28318,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(painter: _LoaderPainter()),
            ),
          ),
        );
      },
    );
  }
}

class _LoaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = AppColors.surfaceElevated2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 3, trackPaint);

    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppColors.green, AppColors.greenBright, Colors.transparent],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 3), 0, 4.9, false, arcPaint);

    final ballPaint = Paint()..color = AppColors.greenBright;
    canvas.drawCircle(center, radius * 0.32, ballPaint);

    final seamPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final ballRadius = radius * 0.32;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ballRadius),
      -0.9,
      2.2,
      false,
      seamPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ballRadius),
      2.24,
      2.2,
      false,
      seamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
