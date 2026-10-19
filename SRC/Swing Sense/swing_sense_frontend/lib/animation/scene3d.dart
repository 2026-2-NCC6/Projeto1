import 'dart:math' as math;

/// Cena 3D estilizada dos treinos guiados: quadra completa vista de tras da
/// linha de fundo, com rede, bola, raquete e o alvo na quadra adversaria.
///
/// Dart puro (sem Flutter) para poder ser testado e pre-visualizado fora do
/// app. Eixos: x = direita, y = cima, z = em direcao a rede/quadra adversaria. Unidades em metros.
/// A tela normalizada tem altura 1 e largura [aspect].
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 scale(double k) => Vec3(x * k, y * k, z * k);
  Vec3 mirrorX() => Vec3(-x, y, z);

  static Vec3 lerp(Vec3 a, Vec3 b, double t) =>
      Vec3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
}

class P2 {
  const P2(this.x, this.y);
  final double x, y;
}

const double aspect = 1.6;
const double _toRad = math.pi / 180;

/// Medidas oficiais da quadra (metros). A linha de fundo do jogador fica em
/// z = 0 e a rede em z = [netZ].
const double courtLength = 23.77;
const double netZ = courtLength / 2;
const double singlesHalfWidth = 4.115;
const double doublesHalfWidth = 5.485;
const double serviceLineDist = 6.4; // da rede
const double netHeight = 0.914;

/// Raquete e bola sao desenhadas maiores que o real para ficarem legiveis.
const double racketScale = 3.3;
const double ballRadius = 0.16;

/// Camera elevada, atras da linha de fundo, olhando para a quadra.
/// [pitchDeg] negativo = olhando para baixo.
class Camera {
  const Camera({this.y = 8.8, this.z = -7.4, this.pitchDeg = -27, this.focal = 1.08});
  final double y;
  final double z;
  final double pitchDeg;
  final double focal;

  /// Projeta um ponto do mundo; retorna null se estiver atras da camera.
  Proj? project(Vec3 p) {
    final py = p.y - y;
    final pz = p.z - z;
    final c = math.cos(pitchDeg * _toRad);
    final s = math.sin(pitchDeg * _toRad);
    final yc = py * c - pz * s;
    final zc = py * s + pz * c;
    if (zc < 0.08) return null;
    final k = focal / zc;
    return Proj(aspect / 2 + p.x * k, 0.5 - yc * k, k, zc);
  }
}

class Proj {
  const Proj(this.x, this.y, this.scale, this.depth);
  final double x, y;

  /// Tamanho na tela (altura = 1) de 1 metro nesta profundidade.
  final double scale;
  final double depth;
  P2 get p => P2(x, y);
}

/// Orientacao da raquete: roll (no plano da tela), pitch (inclina o topo) e
/// yaw (gira em torno do eixo vertical), aplicados nessa ordem.
class RacketState {
  const RacketState(this.pos, {this.yaw = 0, this.pitch = 0, this.roll = 0});
  final Vec3 pos; // centro da cabeca (encordoamento)
  final double yaw, pitch, roll; // graus

  static RacketState lerp(RacketState a, RacketState b, double t) => RacketState(
        Vec3.lerp(a.pos, b.pos, t),
        yaw: a.yaw + (b.yaw - a.yaw) * t,
        pitch: a.pitch + (b.pitch - a.pitch) * t,
        roll: a.roll + (b.roll - a.roll) * t,
      );

  RacketState mirrored() => RacketState(pos.mirrorX(), yaw: -yaw, pitch: pitch, roll: -roll);

  /// Local (cabeca em XY, face para +z, cabo para -y) -> mundo.
  Vec3 toWorld(Vec3 local) {
    final v = local.scale(racketScale);
    final r = roll * _toRad, p = pitch * _toRad, w = yaw * _toRad;
    var x = v.x * math.cos(r) - v.y * math.sin(r);
    var y = v.x * math.sin(r) + v.y * math.cos(r);
    var z = v.z;
    final y2 = y * math.cos(p) - z * math.sin(p);
    final z2 = y * math.sin(p) + z * math.cos(p);
    y = y2;
    z = z2;
    final x3 = x * math.cos(w) + z * math.sin(w);
    final z3 = -x * math.sin(w) + z * math.cos(w);
    return Vec3(x3, y, z3) + pos;
  }

  /// Normal da face (para onde a raquete "olha").
  Vec3 get faceNormal => toWorld(const Vec3(0, 0, 1)) - pos;
}

/// Geometria da raquete em coordenadas locais (metros).
class RacketGeometry {
  RacketGeometry._();
  static const headRx = 0.135;
  static const headRy = 0.165;
  static const throatLen = 0.14;
  static const handleLen = 0.24;

  static List<Vec3> frame([int n = 40]) => [
        for (var i = 0; i < n; i++)
          Vec3(headRx * math.cos(2 * math.pi * i / n), headRy * math.sin(2 * math.pi * i / n), 0),
      ];

  /// Segmentos do encordoamento (pares de pontos), recortados na elipse.
  static List<List<Vec3>> strings() {
    final out = <List<Vec3>>[];
    for (var i = -3; i <= 3; i++) {
      final x = i * 0.033;
      final h = headRy * math.sqrt(1 - math.pow(x / headRx, 2)) * 0.94;
      out.add([Vec3(x, -h, 0), Vec3(x, h, 0)]);
    }
    for (var j = -5; j <= 5; j++) {
      final y = j * 0.028;
      final w = headRx * math.sqrt(1 - math.pow(y / headRy, 2)) * 0.94;
      out.add([Vec3(-w, y, 0), Vec3(w, y, 0)]);
    }
    return out;
  }

  /// Garganta em V (liga a cabeca ao cabo).
  static List<Vec3> throat() => const [
        Vec3(-0.062, -0.150, 0),
        Vec3(0.062, -0.150, 0),
        Vec3(0.018, -0.165 - throatLen, 0),
        Vec3(-0.018, -0.165 - throatLen, 0),
      ];

  static List<Vec3> handle() {
    const top = -0.165 - throatLen;
    const bottom = top - handleLen;
    return const [Vec3(-0.019, top, 0), Vec3(0.019, top, 0), Vec3(0.021, bottom, 0), Vec3(-0.021, bottom, 0)];
  }

  /// Faixas diagonais da empunhadura (pares de pontos).
  static List<List<Vec3>> gripWraps() {
    const top = -0.165 - throatLen;
    final out = <List<Vec3>>[];
    for (var i = 0; i < 7; i++) {
      final y = top - 0.012 - i * 0.032;
      out.add([Vec3(-0.02, y, 0), Vec3(0.02, y - 0.02, 0)]);
    }
    return out;
  }
}

class RacketKey {
  const RacketKey(this.t, this.state, {this.label});
  final double t;
  final RacketState state;
  final String? label;
}

/// Trecho do voo da bola. Se [fromRacket]/[toRacket], a ponta correspondente
/// segue o centro da raquete (garante que a bola encontra o encordoamento).
class BallSeg {
  const BallSeg(this.t0, this.t1, {this.from, this.to, this.fromRacket = false, this.toRacket = false, this.arc = 0});
  final double t0, t1;
  final Vec3? from, to;
  final bool fromRacket, toRacket;

  /// Altura extra (m) no meio do trecho, para dar parabola.
  final double arc;
}

class DrillSample {
  const DrillSample(this.racket, this.ball, this.label, this.contactGlow, this.landGlow, this.phaseIndex);
  final RacketState racket;
  final Vec3? ball;
  final String? label;

  /// 1 -> 0 logo apos o contato da bola com a raquete / com o alvo.
  final double contactGlow;
  final double landGlow;
  final int phaseIndex;
}

/// Zona-alvo na quadra adversaria: circulo (centro + raio) ou retangulo
/// [x0, z0, x1, z1] (por exemplo, a caixa de saque).
class TargetZone {
  const TargetZone.circle(this.center, this.radius) : box = null;
  const TargetZone.box(List<double> this.box)
      : center = const Vec3(0, 0, 0),
        radius = 0;
  final Vec3 center;
  final double radius;
  final List<double>? box;

  Vec3 get middle => box == null ? center : Vec3((box![0] + box![2]) / 2, 0, (box![1] + box![3]) / 2);

  TargetZone mirrored() => box == null
      ? TargetZone.circle(center.mirrorX(), radius)
      : TargetZone.box([-box![2], box![1], -box![0], box![3]]);
}

/// Animacao em loop de um exercicio.
class DrillAnimation {
  const DrillAnimation({
    required this.keys,
    required this.balls,
    required this.contactT,
    required this.landT,
    required this.target,
    this.durationMs = 4800,
    this.mirror = false,
    this.camera = const Camera(),
  });

  final List<RacketKey> keys;
  final List<BallSeg> balls;

  /// Instante do contato bola-raquete e do pouso da bola no alvo.
  final double contactT, landT;
  final TargetZone target;
  final int durationMs;
  final bool mirror;
  final Camera camera;

  TargetZone get targetWorld => mirror ? target.mirrored() : target;

  static double _ease(double s) => s * s * (3 - 2 * s);

  RacketState racketAt(double t) {
    final ks = [...keys];
    if (ks.last.t < 1.0) ks.add(RacketKey(1.0, ks.first.state));
    t = t % 1.0;
    var i = 0;
    while (i < ks.length - 2 && t >= ks[i + 1].t) {
      i++;
    }
    final a = ks[i], b = ks[i + 1];
    final span = b.t - a.t;
    final s = span <= 0 ? 1.0 : _ease(((t - a.t) / span).clamp(0.0, 1.0));
    final st = RacketState.lerp(a.state, b.state, s);
    return mirror ? st.mirrored() : st;
  }

  Vec3? ballAt(double t) {
    t = t % 1.0;
    for (final b in balls) {
      if (t < b.t0 || t > b.t1) continue;
      final u = ((t - b.t0) / (b.t1 - b.t0)).clamp(0.0, 1.0);
      final from = b.fromRacket ? racketAt(b.t0).pos : (mirror ? b.from!.mirrorX() : b.from!);
      final to = b.toRacket ? racketAt(b.t1).pos : (mirror ? b.to!.mirrorX() : b.to!);
      final p = Vec3.lerp(from, to, u);
      return Vec3(p.x, p.y + b.arc * 4 * u * (1 - u), p.z);
    }
    return null;
  }

  DrillSample sample(double t) {
    t = t % 1.0;
    String? label;
    var phase = -1;
    for (final k in keys) {
      if (k.label == null) continue;
      if (k.t <= t) {
        label = k.label;
        phase++;
      }
    }
    double glow(double at) {
      final d = t - at;
      if (d < 0 || d > 0.12) return 0;
      return 1 - d / 0.12;
    }

    return DrillSample(racketAt(t), ballAt(t), label, glow(contactT), glow(landT), phase < 0 ? 0 : phase);
  }

  List<String> get phases => keys.where((k) => k.label != null).map((k) => k.label!).toList();
}
