import 'scene3d.dart';

/// Animacoes dos exercicios, numa quadra completa: a bola vem do outro lado
/// da rede, a raquete rebate e a bola vai ate o alvo marcado na quadra
/// adversaria. Todas sao para destro; `mirror` espelha (backhand, saque pela
/// esquerda).
class Drills {
  Drills._();

  // ----------------------------------------------------------------------
  // Fundo de quadra
  // ----------------------------------------------------------------------

  static DrillAnimation _groundstroke({
    required Vec3 landing,
    bool mirror = false,
    bool lob = false,
    required List<String> labels,
    double hitArc = 2.4,
  }) {
    final swingUp = lob ? 1.0 : 0.0;
    return DrillAnimation(
      durationMs: 5400,
      mirror: mirror,
      contactT: 0.46,
      landT: 0.66,
      target: TargetZone.circle(landing, lob ? 2.0 : 1.7),
      keys: [
        RacketKey(0.00, const RacketState(Vec3(1.0, 1.0, 0.7), yaw: 5, pitch: 5, roll: -12), label: labels[0]),
        RacketKey(0.24, const RacketState(Vec3(1.8, 0.85, 0.2), yaw: 38, pitch: -12, roll: -34), label: labels[1]),
        RacketKey(0.46, RacketState(const Vec3(0.95, 0.9, 0.95), yaw: -4, pitch: 18, roll: 8 + 10 * swingUp), label: labels[2]),
        RacketKey(0.64, RacketState(Vec3(0.05, lob ? 1.9 : 1.55, 1.15), yaw: -48, pitch: 8, roll: lob ? 40 : 66), label: labels[3]),
        const RacketKey(0.80, RacketState(Vec3(0.1, 1.2, 0.8), yaw: -20, pitch: 5, roll: 20)),
      ],
      balls: [
        // Rival devolve: cruza a rede, quica do nosso lado e sobe ate a raquete.
        const BallSeg(0.00, 0.20, from: Vec3(0.4, 1.2, 21.5), to: Vec3(1.1, 0.0, 6.0), arc: 3.2),
        const BallSeg(0.20, 0.46, from: Vec3(1.1, 0.0, 6.0), toRacket: true, arc: 0.55),
        // Nossa rebatida ate o alvo, e o quique no fundo da quadra.
        BallSeg(0.46, 0.66, fromRacket: true, to: landing, arc: lob ? 5.4 : hitArc),
        BallSeg(0.66, 0.78, from: landing, to: Vec3(landing.x * 1.12, 0.0, landing.z + 3.0), arc: 1.0),
      ],
    );
  }

  static final forehandCross = _groundstroke(
    landing: const Vec3(-2.7, 0, 19.6),
    labels: const ['Posicao de espera', 'Preparacao: gire o tronco e leve a raquete atras', 'Contato a frente do corpo', 'Finalizacao alta, sobre o ombro'],
  );

  static final forehandLine = _groundstroke(
    landing: const Vec3(3.0, 0, 20.2),
    labels: const ['Posicao de espera', 'Preparacao: raquete atras, ombro fechado', 'Contato mais cedo, mirando a paralela', 'Finalize na direcao do alvo'],
  );

  static final backhandCross = _groundstroke(
    mirror: true,
    landing: const Vec3(-2.7, 0, 19.6),
    labels: const ['Posicao de espera com as duas maos', 'Preparacao: ombros viram, raquete atras', 'Contato a frente, bracos estendidos', 'Finalizacao sobre o ombro oposto'],
  );

  static final backhandLine = _groundstroke(
    mirror: true,
    landing: const Vec3(3.0, 0, 20.2),
    labels: const ['Posicao de espera com as duas maos', 'Preparacao: ombro aponta a bola', 'Contato cedo, mirando a paralela', 'Finalize na direcao do alvo'],
  );

  static final lob = _groundstroke(
    landing: const Vec3(0.0, 0, 21.4),
    lob: true,
    labels: const ['Posicao de espera', 'Prepare mais baixo que o normal', 'Contato com a face aberta', 'Finalize alto: a bola precisa subir'],
  );

  // ----------------------------------------------------------------------
  // Saque
  // ----------------------------------------------------------------------

  static DrillAnimation _serve({required bool mirror}) {
    const landing = Vec3(-1.5, 0, 16.9);
    return DrillAnimation(
      durationMs: 6000,
      mirror: mirror,
      contactT: 0.56,
      landT: 0.72,
      target: const TargetZone.box([-singlesHalfWidth, netZ, 0, netZ + serviceLineDist]),
      keys: const [
        RacketKey(0.00, RacketState(Vec3(0.95, 0.95, 0.35), yaw: 10, pitch: 10, roll: -8), label: 'Postura: pes na largura dos ombros'),
        RacketKey(0.22, RacketState(Vec3(1.35, 1.15, 0.30), yaw: 40, pitch: -15, roll: -25), label: 'Lancamento: braco livre sobe reto'),
        RacketKey(0.40, RacketState(Vec3(1.45, 2.05, 0.05), yaw: 62, pitch: -45, roll: -20), label: 'Posicao de trofeu: cotovelo alto'),
        RacketKey(0.48, RacketState(Vec3(1.15, 1.65, -0.25), yaw: 40, pitch: -135, roll: -10)),
        RacketKey(0.56, RacketState(Vec3(0.95, 2.85, 0.95), yaw: 0, pitch: 14, roll: 2), label: 'Contato no ponto mais alto'),
        RacketKey(0.74, RacketState(Vec3(0.05, 1.45, 1.1), yaw: -45, pitch: 25, roll: 115), label: 'Finalizacao cruzando o corpo'),
        RacketKey(0.88, RacketState(Vec3(0.3, 1.0, 0.6), yaw: -10, pitch: 8, roll: 30)),
      ],
      balls: const [
        BallSeg(0.08, 0.36, from: Vec3(0.55, 1.15, 0.45), to: Vec3(0.95, 3.7, 0.95)),
        BallSeg(0.36, 0.56, from: Vec3(0.95, 3.7, 0.95), toRacket: true),
        BallSeg(0.56, 0.72, fromRacket: true, to: landing, arc: 1.3),
        BallSeg(0.72, 0.84, from: landing, to: Vec3(-1.9, 0.0, 20.5), arc: 1.1),
      ],
    );
  }

  static final serveDeuce = _serve(mirror: false);
  static final serveAd = _serve(mirror: true);

  // ----------------------------------------------------------------------
  // Rede
  // ----------------------------------------------------------------------

  static DrillAnimation _volley({required bool mirror}) {
    const landing = Vec3(-2.8, 0, 20.6);
    return DrillAnimation(
      durationMs: 4200,
      mirror: mirror,
      contactT: 0.46,
      landT: 0.62,
      target: const TargetZone.circle(landing, 1.35),
      keys: const [
        RacketKey(0.00, RacketState(Vec3(0.75, 1.30, 9.7), yaw: 5, pitch: 15, roll: -8), label: 'Espera na rede: raquete a frente'),
        RacketKey(0.26, RacketState(Vec3(1.15, 1.30, 9.45), yaw: 32, pitch: -5, roll: -22), label: 'Backswing curto: so o ombro gira'),
        RacketKey(0.46, RacketState(Vec3(0.80, 1.30, 10.3), yaw: -2, pitch: 20, roll: 4), label: 'Toque firme a frente, punho travado'),
        RacketKey(0.62, RacketState(Vec3(0.55, 1.25, 10.6), yaw: -10, pitch: 18, roll: 6), label: 'Pouca finalizacao: volte a posicao'),
        RacketKey(0.82, RacketState(Vec3(0.75, 1.30, 9.7), yaw: 5, pitch: 15, roll: -8)),
      ],
      balls: const [
        BallSeg(0.00, 0.46, from: Vec3(0.6, 1.6, 21.5), toRacket: true, arc: 1.4),
        BallSeg(0.46, 0.62, fromRacket: true, to: landing, arc: 0.6),
        BallSeg(0.62, 0.74, from: landing, to: Vec3(-3.1, 0.0, 23.6), arc: 0.8),
      ],
    );
  }

  static final volleyForehand = _volley(mirror: false);
  static final volleyBackhand = _volley(mirror: true);

  static const smash = DrillAnimation(
    durationMs: 5200,
    contactT: 0.54,
    landT: 0.68,
    target: TargetZone.circle(Vec3(-2.0, 0, 19.2), 1.5),
    keys: [
      RacketKey(0.00, RacketState(Vec3(0.9, 1.2, 7.4), yaw: 5, pitch: 10, roll: -8), label: 'Espera: olhe a bola subir'),
      RacketKey(0.28, RacketState(Vec3(1.4, 2.1, 7.0), yaw: 58, pitch: -45, roll: -22), label: 'Raquete atras, mao livre aponta a bola'),
      RacketKey(0.54, RacketState(Vec3(0.95, 3.0, 8.2), yaw: 0, pitch: 18, roll: 2), label: 'Contato acima da cabeca, braco esticado'),
      RacketKey(0.74, RacketState(Vec3(0.05, 1.5, 8.5), yaw: -45, pitch: 25, roll: 110), label: 'Finalizacao para baixo'),
      RacketKey(0.90, RacketState(Vec3(0.5, 1.0, 7.8), yaw: -10, pitch: 8, roll: 25)),
    ],
    balls: [
      BallSeg(0.00, 0.54, from: Vec3(0.2, 1.5, 21.0), toRacket: true, arc: 7.0),
      BallSeg(0.54, 0.68, fromRacket: true, to: Vec3(-2.0, 0, 19.2), arc: 0.3),
      BallSeg(0.68, 0.80, from: Vec3(-2.0, 0, 19.2), to: Vec3(-2.6, 0.0, 23.0), arc: 2.2),
    ],
  );
}
