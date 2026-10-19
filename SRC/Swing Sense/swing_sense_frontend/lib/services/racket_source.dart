import '../models/session_event.dart';

/// Origem dos eventos de tacada durante uma sessao: a raquete simulada
/// (`MockRacketService`) ou a raquete real por Bluetooth (`BleRacketService`).
/// A tela de sessao ao vivo so conhece esta interface.
abstract class RacketSource {
  Stream<SessionEvent> get events;

  /// Comeca (ou retoma) o repasse de eventos.
  void start();

  /// Pausa o repasse de eventos (nao desconecta a raquete).
  void stop();

  /// Libera os recursos desta tela. A raquete BLE e compartilhada e NAO e
  /// desconectada aqui.
  void dispose();
}
