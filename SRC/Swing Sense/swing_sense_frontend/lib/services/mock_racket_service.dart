import 'dart:async';
import 'dart:math';

import '../models/session_event.dart';

/// Simula a raquete inteligente (ESP32 + giroscopio + sensor de velocidade da
/// bola) enquanto o hardware real nao esta pronto. Gera eventos de tacada em
/// intervalos realistas com velocidade, rotacao e angulo aleatorios, do mesmo
/// jeito que o dispositivo fisico enviaria via BLE/Wi-Fi.
///
/// Para plugar o hardware real no futuro: crie uma implementacao alternativa
/// que exponha o mesmo `Stream<SessionEvent> events` (ex.: lendo notificacoes
/// BLE do ESP32) e troque a instancia usada na tela de sessao ao vivo - nada
/// mais no app precisa mudar.
class MockRacketService {
  final _controller = StreamController<SessionEvent>.broadcast();
  final _random = Random();
  Timer? _timer;
  bool get isRunning => _timer != null;

  Stream<SessionEvent> get events => _controller.stream;

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) => _emitShot());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _emitShot() {
    final roll = _random.nextDouble();
    String type;
    if (roll < 0.06) {
      type = 'ace';
    } else if (roll < 0.16) {
      type = 'fault';
    } else {
      type = 'shot';
    }

    final baseSpeed = type == 'ace' ? 140 : 70 + _random.nextInt(60);
    final speed = (baseSpeed + _random.nextDouble() * 15).toDouble();
    final spin = 800 + _random.nextInt(2400).toDouble();
    final angle = -35 + _random.nextDouble() * 70;

    _controller.add(SessionEvent(
      eventType: type,
      ballSpeedKmh: double.parse(speed.toStringAsFixed(1)),
      spinRateRpm: double.parse(spin.toStringAsFixed(1)),
      racketAngleDeg: double.parse(angle.toStringAsFixed(1)),
    ));
  }
}
