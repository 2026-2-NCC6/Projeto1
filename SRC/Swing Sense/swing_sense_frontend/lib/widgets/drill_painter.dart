import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../animation/scene3d.dart';

/// Desenha a quadra completa (vista de tras da linha de fundo): piso, linhas,
/// rede, plateia, alvo, bola com rastro, raquete com efeito de movimento e
/// os efeitos de impacto.
class DrillPainter extends CustomPainter {
  DrillPainter(this.anim, this.progress) : super(repaint: progress);

  final DrillAnimation anim;
  final Animation<double> progress;

  static const _neon = Color(0xFF1ED760);
  static const _ballColor = Color(0xFFF2FFF4);

  late Size _size;
  late double _s; // pixels por unidade normalizada
  late double _ox;
  late Camera _cam;

  Offset? _pt(Vec3 v) {
    final p = _cam.project(v);
    if (p == null) return null;
    return Offset(_ox + p.x * _s, p.y * _s);
  }

  double _scaleAt(Vec3 v) => (_cam.project(v)?.scale ?? 0) * _s;

  Path? _poly(Iterable<Vec3> pts, {bool close = true}) {
    final path = Path();
    var first = true;
    for (final v in pts) {
      final o = _pt(v);
      if (o == null) return null;
      if (first) {
        path.moveTo(o.dx, o.dy);
        first = false;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    if (close) path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    _s = math.min(size.width / aspect, size.height);
    _ox = (size.width - aspect * _s) / 2;
    _cam = anim.camera;

    final t = progress.value;
    final sample = anim.sample(t);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _paintBackground(canvas);
    _paintCourt(canvas);
    _paintLines(canvas);
    _paintTarget(canvas, sample);
    _paintPlayerMarker(canvas);
    _paintGroundShadows(canvas, sample);

    final ball = sample.ball;
    final ballBehindNet = ball != null && ball.z > netZ;
    if (ballBehindNet) _paintBall(canvas, t, ball);
    _paintNet(canvas);
    if (ball != null && !ballBehindNet) _paintBall(canvas, t, ball);

    _paintRacketTrail(canvas, t);
    _paintRacket(canvas, sample.racket, 1.0);
    _paintContactBurst(canvas, sample);
    _paintLandingRipple(canvas, sample);
    _paintVignette(canvas);

    canvas.restore();
  }

  // ----------------------------------------------------------------------
  // Cenario
  // ----------------------------------------------------------------------

  void _paintBackground(Canvas canvas) {
    final rect = Offset.zero & _size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, _size.height), const [
          Color(0xFF000000),
          Color(0xFF050A07),
          Color(0xFF07140D),
        ], const [0.0, 0.55, 1.0]),
    );

    // Refletores do estadio.
    for (final c in [Offset(_size.width * 0.18, -_size.height * 0.04), Offset(_size.width * 0.82, -_size.height * 0.04)]) {
      canvas.drawCircle(
        c,
        _size.height * 0.55,
        Paint()
          ..shader = ui.Gradient.radial(c, _size.height * 0.55, [
            Colors.white.withOpacity(0.13),
            Colors.white.withOpacity(0.0),
          ]),
      );
    }

    // Arquibancada ao fundo (faixa escura com "luzes" de celulares).
    final horizon = _pt(const Vec3(0, 0, courtLength + 9))?.dy ?? _size.height * 0.3;
    final standTop = horizon - _size.height * 0.16;
    final stand = Rect.fromLTRB(0, standTop, _size.width, horizon + _size.height * 0.02);
    canvas.drawRect(
      stand,
      Paint()
        ..shader = ui.Gradient.linear(stand.topCenter, stand.bottomCenter, const [
          Color(0xFF040605),
          Color(0xFF0B120E),
        ]),
    );
    final rnd = math.Random(7);
    final dot = Paint();
    for (var i = 0; i < 260; i++) {
      final x = rnd.nextDouble() * _size.width;
      final y = standTop + rnd.nextDouble() * (stand.height);
      final warm = rnd.nextBool();
      dot.color = (warm ? Colors.white : _neon).withOpacity(0.08 + rnd.nextDouble() * 0.26);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 1.1, dot);
    }
    // Painel de publicidade na frente da arquibancada.
    final boardTop = horizon - _size.height * 0.015;
    canvas.drawRect(
      Rect.fromLTRB(0, boardTop, _size.width, horizon + _size.height * 0.02),
      Paint()..color = const Color(0xFF07170F),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, boardTop, _size.width, boardTop + 2),
      Paint()..color = _neon.withOpacity(0.55),
    );
  }

  void _paintCourt(Canvas canvas) {
    const outer = 22.0;
    final surround = _poly(const [
      Vec3(-outer, 0, -12),
      Vec3(outer, 0, -12),
      Vec3(outer, 0, courtLength + 40),
      Vec3(-outer, 0, courtLength + 40),
    ]);
    if (surround != null) {
      final near = _pt(const Vec3(0, 0, -12)) ?? Offset(0, _size.height);
      final far = _pt(const Vec3(0, 0, courtLength + 40)) ?? const Offset(0, 0);
      canvas.drawPath(
        surround,
        Paint()
          ..shader = ui.Gradient.linear(near, far, const [Color(0xFF0A2218), Color(0xFF020504)]),
      );
    }

    final court = _poly(const [
      Vec3(-doublesHalfWidth, 0, 0),
      Vec3(doublesHalfWidth, 0, 0),
      Vec3(doublesHalfWidth, 0, courtLength),
      Vec3(-doublesHalfWidth, 0, courtLength),
    ]);
    if (court != null) {
      final near = _pt(const Vec3(0, 0, 0)) ?? Offset(0, _size.height);
      final far = _pt(const Vec3(0, 0, courtLength)) ?? const Offset(0, 0);
      canvas.drawPath(
        court,
        Paint()
          ..shader = ui.Gradient.linear(near, far, const [Color(0xFF14663F), Color(0xFF0E4A2E), Color(0xFF0A3822)], const [0.0, 0.55, 1.0]),
      );
      // Brilho suave (luz dos refletores) sobre o piso.
      final glow = _pt(const Vec3(0, 0, 7)) ?? near;
      canvas.save();
      canvas.clipPath(court);
      canvas.drawCircle(
        glow,
        _size.height * 0.5,
        Paint()
          ..shader = ui.Gradient.radial(glow, _size.height * 0.5, [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.0),
          ]),
      );
      canvas.restore();
    }
  }

  Path? _groundBand(double x0, double z0, double x1, double z1, double w) {
    // Faixa de largura [w] (m) entre dois pontos no chao.
    final dx = x1 - x0, dz = z1 - z0;
    final len = math.sqrt(dx * dx + dz * dz);
    final nx = -dz / len * w / 2, nz = dx / len * w / 2;
    return _poly([
      Vec3(x0 + nx, 0.0, z0 + nz),
      Vec3(x1 + nx, 0.0, z1 + nz),
      Vec3(x1 - nx, 0.0, z1 - nz),
      Vec3(x0 - nx, 0.0, z0 - nz),
    ]);
  }

  void _paintLines(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withOpacity(0.93);
    const w = 0.07;
    final segs = <List<double>>[
      [-doublesHalfWidth, 0, doublesHalfWidth, 0],
      [-doublesHalfWidth, courtLength, doublesHalfWidth, courtLength],
      [-doublesHalfWidth, 0, -doublesHalfWidth, courtLength],
      [doublesHalfWidth, 0, doublesHalfWidth, courtLength],
      [-singlesHalfWidth, 0, -singlesHalfWidth, courtLength],
      [singlesHalfWidth, 0, singlesHalfWidth, courtLength],
      [-singlesHalfWidth, netZ - serviceLineDist, singlesHalfWidth, netZ - serviceLineDist],
      [-singlesHalfWidth, netZ + serviceLineDist, singlesHalfWidth, netZ + serviceLineDist],
      [0, netZ - serviceLineDist, 0, netZ + serviceLineDist],
      [0, 0, 0, 0.3],
      [0, courtLength - 0.3, 0, courtLength],
    ];
    for (final s in segs) {
      final p = _groundBand(s[0], s[1], s[2], s[3], w);
      if (p != null) canvas.drawPath(p, paint);
    }
  }

  void _paintNet(Canvas canvas) {
    const halfW = 5.5;
    const hPost = 1.07;
    // Sombra da rede no piso.
    final shadow = _poly(const [
      Vec3(-halfW, 0, netZ),
      Vec3(halfW, 0, netZ),
      Vec3(halfW, 0, netZ + 0.55),
      Vec3(-halfW, 0, netZ + 0.55),
    ]);
    if (shadow != null) canvas.drawPath(shadow, Paint()..color = Colors.black.withOpacity(0.16));

    final net = _poly(const [
      Vec3(-halfW, 0, netZ),
      Vec3(halfW, 0, netZ),
      Vec3(halfW, hPost, netZ),
      Vec3(0, netHeight, netZ),
      Vec3(-halfW, hPost, netZ),
    ]);
    if (net == null) return;
    canvas.drawPath(net, Paint()..color = Colors.black.withOpacity(0.55));

    // Malha.
    canvas.save();
    canvas.clipPath(net);
    final mesh = Paint()
      ..color = Colors.white.withOpacity(0.20)
      ..strokeWidth = 0.7;
    for (var x = -halfW; x <= halfW + 0.01; x += 0.25) {
      final a = _pt(Vec3(x, 0, netZ)), b = _pt(Vec3(x, hPost, netZ));
      if (a != null && b != null) canvas.drawLine(a, b, mesh);
    }
    for (var y = 0.0; y <= hPost + 0.01; y += 0.12) {
      final a = _pt(Vec3(-halfW, y, netZ)), b = _pt(Vec3(halfW, y, netZ));
      if (a != null && b != null) canvas.drawLine(a, b, mesh);
    }
    canvas.restore();

    // Fita branca no topo (curva suave: mais baixa no centro).
    final tape = Path();
    var first = true;
    for (var i = 0; i <= 24; i++) {
      final x = -halfW + (2 * halfW) * i / 24;
      final h = netHeight + (hPost - netHeight) * math.pow(x.abs() / halfW, 2);
      final o = _pt(Vec3(x, h, netZ));
      if (o == null) return;
      if (first) {
        tape.moveTo(o.dx, o.dy);
        first = false;
      } else {
        tape.lineTo(o.dx, o.dy);
      }
    }
    final tapeW = math.max(2.2, 0.05 * _scaleAt(const Vec3(0, netHeight, netZ)) * 2.2);
    canvas.drawPath(
      tape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = tapeW
        ..strokeCap = StrokeCap.round,
    );

    // Postes.
    for (final x in [-halfW, halfW]) {
      final a = _pt(Vec3(x, 0, netZ)), b = _pt(Vec3(x, hPost, netZ));
      if (a != null && b != null) {
        canvas.drawLine(a, b, Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = tapeW * 1.1
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  // ----------------------------------------------------------------------
  // Alvo e marcadores
  // ----------------------------------------------------------------------

  void _paintTarget(Canvas canvas, DrillSample sample) {
    final zone = anim.targetWorld;
    final pulse = 0.5 + 0.5 * math.sin(progress.value * math.pi * 2 * 3);
    final glowBoost = sample.landGlow;

    if (zone.box != null) {
      final b = zone.box!;
      final path = _poly([Vec3(b[0], 0, b[1]), Vec3(b[2], 0, b[1]), Vec3(b[2], 0, b[3]), Vec3(b[0], 0, b[3])]);
      if (path == null) return;
      canvas.drawPath(path, Paint()..color = _neon.withOpacity(0.20 + 0.10 * pulse + 0.35 * glowBoost));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = _neon.withOpacity(0.75 + 0.2 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5),
      );
      _paintBeam(canvas, Vec3((b[0] + b[2]) / 2, 0, (b[1] + b[3]) / 2), 2.2);
      _label(canvas, 'ALVO', Vec3((b[0] + b[2]) / 2, 0.02, b[1] + 0.5));
      return;
    }

    final c = zone.center;
    for (final entry in [(1.0, 0.16), (0.62, 0.22), (0.28, 0.32)]) {
      final path = _circlePath(c, zone.radius * entry.$1);
      if (path == null) continue;
      canvas.drawPath(path, Paint()..color = _neon.withOpacity(entry.$2 + 0.08 * pulse + 0.25 * glowBoost));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = entry.$1 == 1.0 ? 2.4 : 1.4
          ..color = _neon.withOpacity(0.55 + 0.35 * pulse)
          ..maskFilter = entry.$1 == 1.0 ? const MaskFilter.blur(BlurStyle.solid, 2.5) : null,
      );
    }
    _paintBeam(canvas, c, zone.radius * 1.1);
    _label(canvas, 'ALVO', Vec3(c.x, 0.02, c.z - zone.radius * 1.35));
  }

  /// Coluna de luz sobre o alvo: ajuda a localiza-lo mesmo bem ao fundo.
  void _paintBeam(Canvas canvas, Vec3 base, double width) {
    final b = _pt(base);
    final t = _pt(Vec3(base.x, 3.2, base.z));
    if (b == null || t == null) return;
    final half = _scaleAt(base) * width / 2;
    final path = Path()
      ..moveTo(b.dx - half, b.dy)
      ..lineTo(b.dx + half, b.dy)
      ..lineTo(t.dx + half * 0.5, t.dy)
      ..lineTo(t.dx - half * 0.5, t.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(b, t, [_neon.withOpacity(0.30), _neon.withOpacity(0.0)]),
    );
  }

  Path? _circlePath(Vec3 c, double r, {int n = 40}) {
    return _poly([
      for (var i = 0; i < n; i++) Vec3(c.x + r * math.cos(2 * math.pi * i / n), 0.0, c.z + r * math.sin(2 * math.pi * i / n)),
    ]);
  }

  void _label(Canvas canvas, String text, Vec3 at) {
    final o = _pt(at);
    if (o == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: math.max(8, _size.height * 0.026),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintPlayerMarker(Canvas canvas) {
    final pulse = 0.5 + 0.5 * math.sin(progress.value * math.pi * 2 * 2);
    // O jogador fica ao lado da raquete na posicao inicial do exercicio.
    final rest = anim.racketAt(0).pos;
    final c = Vec3(rest.x + (anim.mirror ? 0.8 : -0.8), 0, rest.z - 0.35);
    final outer = _circlePath(c, 1.05, n: 36);
    if (outer == null) return;
    canvas.drawPath(outer, Paint()..color = _neon.withOpacity(0.10 + 0.06 * pulse));
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _neon.withOpacity(0.55),
    );
    _label(canvas, 'VOCE', Vec3(c.x, 0.02, c.z - 1.6));
  }

  // ----------------------------------------------------------------------
  // Sombras, bola, raquete
  // ----------------------------------------------------------------------

  void _paintGroundShadows(Canvas canvas, DrillSample sample) {
    // Sombra da raquete.
    final r = sample.racket.pos;
    final o = _pt(Vec3(r.x + 0.2, 0, r.z));
    if (o != null) {
      final k = _scaleAt(Vec3(r.x, 0, r.z));
      final h = (r.y).clamp(0.0, 4.0);
      canvas.drawOval(
        Rect.fromCenter(center: o, width: 1.5 * k * (1 + h * 0.08), height: 0.5 * k * (1 + h * 0.08)),
        Paint()
          ..color = Colors.black.withOpacity(0.26 / (1 + h * 0.3))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    final ball = sample.ball;
    if (ball != null) {
      final g = _pt(Vec3(ball.x, 0, ball.z));
      if (g != null) {
        final k = _scaleAt(Vec3(ball.x, 0, ball.z));
        final w = ballRadius * 2.6 * k * (1 + ball.y * 0.12);
        canvas.drawOval(
          Rect.fromCenter(center: g, width: math.max(5, w), height: math.max(2.2, w * 0.38)),
          Paint()..color = Colors.black.withOpacity(0.42 / (1 + ball.y * 0.28)),
        );
      }
    }
  }

  void _paintBall(Canvas canvas, double t, Vec3 ball) {
    // Rastro.
    for (var i = 8; i >= 1; i--) {
      final prev = anim.ballAt(t - i * 0.010);
      if (prev == null) continue;
      final p = _pt(prev);
      if (p == null) continue;
      final rr = math.max(1.6, ballRadius * _scaleAt(prev)) * (1 - i * 0.07);
      canvas.drawCircle(p, rr, Paint()..color = _ballColor.withOpacity(0.30 * (1 - i / 9)));
    }
    final o = _pt(ball);
    if (o == null) return;
    final r = math.max(3.4, ballRadius * _scaleAt(ball));
    canvas.drawCircle(
      o,
      r * 2.4,
      Paint()
        ..color = _ballColor.withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2),
    );
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = ui.Gradient.radial(o - Offset(r * 0.3, r * 0.3), r * 1.4, const [Colors.white, _ballColor, Color(0xFFB9E8C4)], const [0.0, 0.5, 1.0]),
    );
    // Costura.
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r * 0.78),
      -0.9,
      2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.14)
        ..color = _neon.withOpacity(0.9),
    );
  }

  Path? _racketFramePath(RacketState st) {
    final pts = [for (final v in RacketGeometry.frame()) st.toWorld(v)];
    return _poly(pts);
  }

  void _paintRacketTrail(Canvas canvas, double t) {
    for (var i = 6; i >= 1; i--) {
      final st = anim.racketAt(t - i * 0.016);
      final path = _racketFramePath(st);
      if (path == null) continue;
      final k = _scaleAt(st.pos);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, 0.06 * racketScale * k)
          ..color = _neon.withOpacity(0.07 * (7 - i)),
      );
    }
  }

  void _paintRacket(Canvas canvas, RacketState st, double opacity) {
    final k = _scaleAt(st.pos);
    if (k <= 0) return;
    Path? polyLocal(List<Vec3> pts) => _poly([for (final v in pts) st.toWorld(v)]);

    // Cabo e garganta.
    final handle = polyLocal(RacketGeometry.handle());
    final throat = polyLocal(RacketGeometry.throat());
    final dark = Paint()..color = const Color(0xFF090B0A);
    if (throat != null) canvas.drawPath(throat, dark);
    if (handle != null) {
      canvas.drawPath(handle, dark);
      canvas.save();
      canvas.clipPath(handle);
      final wrap = Paint()
        ..color = _neon.withOpacity(0.85)
        ..strokeWidth = math.max(1.0, 0.012 * racketScale * k);
      for (final seg in RacketGeometry.gripWraps()) {
        final a = _pt(st.toWorld(seg[0])), b = _pt(st.toWorld(seg[1]));
        if (a != null && b != null) canvas.drawLine(a, b, wrap);
      }
      canvas.restore();
    }

    final frame = _racketFramePath(st);
    if (frame == null) return;

    // Brilho atras da cabeca.
    canvas.drawPath(
      frame,
      Paint()
        ..color = _neon.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(4, 0.10 * racketScale * k)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(3, 0.05 * racketScale * k)),
    );
    // Encordoamento.
    canvas.save();
    canvas.clipPath(frame);
    canvas.drawPath(frame, Paint()..color = Colors.white.withOpacity(0.07));
    final stringPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = math.max(0.6, 0.004 * racketScale * k);
    for (final seg in RacketGeometry.strings()) {
      final a = _pt(st.toWorld(seg[0])), b = _pt(st.toWorld(seg[1]));
      if (a != null && b != null) canvas.drawLine(a, b, stringPaint);
    }
    canvas.restore();
    // Aro: grafite por fora, verde por dentro e um brilho branco.
    final w = math.max(3.0, 0.038 * racketScale * k);
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0B0D0C),
    );
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.42
        ..strokeJoin = StrokeJoin.round
        ..color = _neon,
    );
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.08)
        ..color = Colors.white.withOpacity(0.7),
    );
  }

  void _paintContactBurst(Canvas canvas, DrillSample sample) {
    final g = sample.contactGlow;
    if (g <= 0) return;
    final pos = sample.racket.pos;
    final o = _pt(pos);
    if (o == null) return;
    final k = _scaleAt(pos);
    final radius = (0.35 + (1 - g) * 1.1) * k;
    canvas.drawCircle(
      o,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(o, radius, [
          Colors.white.withOpacity(0.85 * g),
          _neon.withOpacity(0.35 * g),
          _neon.withOpacity(0.0),
        ], const [0.0, 0.45, 1.0]),
    );
    final ray = Paint()
      ..color = Colors.white.withOpacity(0.8 * g)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + 0.2;
      final r0 = radius * 0.55, r1 = radius * (0.9 + 0.35 * (i.isEven ? 1 : 0.4));
      canvas.drawLine(o + Offset(math.cos(a), math.sin(a)) * r0, o + Offset(math.cos(a), math.sin(a)) * r1, ray);
    }

  }

  /// Ondas no ponto em que a bola cai no alvo.
  void _paintLandingRipple(Canvas canvas, DrillSample sample) {
    final g = sample.landGlow;
    if (g <= 0) return;
    final land = anim.ballAt(anim.landT);
    if (land == null) return;
    final c = Vec3(land.x, 0, land.z);
    for (final f in [0.0, 0.35]) {
      final prog = ((1 - g) - f).clamp(0.0, 1.0);
      if (prog <= 0) continue;
      final path = _circlePath(c, 0.3 + prog * 2.0);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - prog) + 0.6
          ..color = Colors.white.withOpacity(0.8 * (1 - prog)),
      );
    }
    final o = _pt(c);
    if (o != null) {
      final r = _scaleAt(c) * 1.2;
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..shader = ui.Gradient.radial(o, r, [_neon.withOpacity(0.55 * g), _neon.withOpacity(0.0)]),
      );
    }
  }

  void _paintVignette(Canvas canvas) {
    final rect = Offset.zero & _size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(rect.center, _size.longestSide * 0.62, [
          Colors.transparent,
          Colors.black.withOpacity(0.50),
        ], const [0.55, 1.0]),
    );
  }

  @override
  bool shouldRepaint(covariant DrillPainter oldDelegate) => oldDelegate.anim != anim;
}
