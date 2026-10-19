import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/session_event.dart';
import '../../models/tacada.dart';
import '../racket_source.dart';

/// Contrato fixo do prototipo (veja `INTEGRACAO_APP_BLE.md`).
final Guid kServicoSwingSense = Guid('5f650a50-3eba-436c-b9d7-5beb09160c55');
final Guid kCaracTacada = Guid('efae8d7d-880d-40d4-9a82-bc63cf7a3d81');

/// No Android o MTU precisa ser >= 185, senao o JSON nao cabe no pacote e o
/// prototipo nao envia nada.
const int kMtuMinimo = 185;

enum RacketLinkState { idle, scanning, connecting, connected, reconnecting, error }

/// Raquete real por Bluetooth Low Energy (GATT, sem pareamento do sistema).
///
/// Sequencia obrigatoria a CADA conexao: connect -> MTU 185 (Android) ->
/// discoverServices -> setNotifyValue(true). Por isso a reconexao refaz tudo.
/// Os golpes chegam so enquanto o app esta conectado e a sessao esta em
/// andamento (`start()`); fora disso sao descartados (modo "ao vivo").
class BleRacketService implements RacketSource {
  BleRacketService._();
  static final BleRacketService instance = BleRacketService._();

  final ValueNotifier<RacketLinkState> state = ValueNotifier(RacketLinkState.idle);

  /// Nome anunciado (`SwingSense-XXXX`) - e o identificador da raquete.
  String? deviceName;
  String? errorMessage;

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _wantConnected = false;
  bool _reconnecting = false;
  bool _forwarding = false;

  final _tacadas = StreamController<Tacada>.broadcast();
  final _events = StreamController<SessionEvent>.broadcast();

  /// Tacadas completas (com todos os campos do contrato).
  Stream<Tacada> get tacadas => _tacadas.stream;

  @override
  Stream<SessionEvent> get events => _events.stream;

  bool get isConnected => state.value == RacketLinkState.connected;

  void _set(RacketLinkState s, {String? error}) {
    errorMessage = error;
    state.value = s;
  }

  // ----------------------------------------------------------------------
  // Conexao
  // ----------------------------------------------------------------------

  /// Procura o prototipo (filtrando pelo UUID do servico) e conecta.
  /// Lanca [RacketConnectException] com mensagem pronta para o usuario.
  Future<void> connect() async {
    final s = state.value;
    if (s == RacketLinkState.scanning || s == RacketLinkState.connecting) return;
    if (isConnected) return;

    _wantConnected = true;
    try {
      if (!await FlutterBluePlus.isSupported) {
        throw RacketConnectException('Este aparelho nao suporta Bluetooth Low Energy.');
      }
      final adapter = await FlutterBluePlus.adapterState
          .where((a) => a != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => BluetoothAdapterState.unknown);
      if (adapter == BluetoothAdapterState.off) {
        throw RacketConnectException('Bluetooth desligado. Ligue o Bluetooth e tente de novo.');
      }
      if (adapter == BluetoothAdapterState.unauthorized) {
        throw RacketConnectException('Permissao de Bluetooth negada. Libere nas configuracoes do aparelho.');
      }

      _set(RacketLinkState.scanning);
      final device = await _scan();
      if (device == null) {
        throw RacketConnectException(
          'Raquete nao encontrada. Confira se ela esta ligada e perto do celular '
          '(no Android 11 ou anterior, a localizacao precisa estar ligada).',
        );
      }

      _device = device;
      deviceName = device.platformName.isNotEmpty ? device.platformName : 'SwingSense';
      _set(RacketLinkState.connecting);
      await _link(device);
      _watchConnection(device);
      _set(RacketLinkState.connected);
    } catch (e) {
      _wantConnected = false;
      final message = e is RacketConnectException ? e.message : _friendly(e);
      _set(RacketLinkState.error, error: message);
      await _teardown();
      throw RacketConnectException(message);
    }
  }

  /// Desconecta de vez (o usuario nao quer mais receber golpes).
  Future<void> disconnect() async {
    _wantConnected = false;
    _forwarding = false;
    await _teardown();
    _set(RacketLinkState.idle);
  }

  Future<BluetoothDevice?> _scan() async {
    final found = Completer<void>();
    final sub = FlutterBluePlus.onScanResults.listen((list) {
      if (list.isNotEmpty && !found.isCompleted) found.complete();
    });
    try {
      await FlutterBluePlus.startScan(withServices: [kServicoSwingSense], timeout: const Duration(seconds: 10));
      await found.future.timeout(const Duration(seconds: 11), onTimeout: () {});
      // Se houver mais de um prototipo por perto, escolhe o de sinal mais forte.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final results = FlutterBluePlus.lastScanResults;
      if (results.isEmpty) return null;
      results.sort((a, b) => b.rssi.compareTo(a.rssi));
      return results.first.device;
    } finally {
      await sub.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  /// connect -> MTU -> discover -> notify. Repetido a cada (re)conexao.
  Future<void> _link(BluetoothDevice device) async {
    // mtu: null => nos mesmos pedimos 185, exatamente como o contrato manda.
    await device.connect(mtu: null, timeout: const Duration(seconds: 20));

    if (Platform.isAndroid) {
      try {
        await device.requestMtu(kMtuMinimo);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await device.requestMtu(kMtuMinimo); // segunda chance; se falhar, aborta
      }
    }

    final services = await device.discoverServices();
    final service = services.where((s) => s.uuid == kServicoSwingSense).toList();
    if (service.isEmpty) {
      throw RacketConnectException('Esse dispositivo nao e uma raquete Swing Sense.');
    }
    final caracs = service.first.characteristics.where((c) => c.uuid == kCaracTacada).toList();
    if (caracs.isEmpty) {
      throw RacketConnectException('A raquete nao expoe a caracteristica de tacadas (firmware diferente?).');
    }
    final carac = caracs.first;

    await _notifySub?.cancel();
    final sub = carac.onValueReceived.listen(_onBytes);
    _notifySub = sub;
    device.cancelWhenDisconnected(sub);

    // Sem isso nada chega.
    await carac.setNotifyValue(true);
  }

  void _watchConnection(BluetoothDevice device) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && _wantConnected && isConnected) {
        _reconnectLoop();
      }
    });
  }

  /// Reconecta sozinho (o prototipo volta a anunciar). Backoff de 2 s ate 10 s.
  Future<void> _reconnectLoop() async {
    if (_reconnecting) return;
    _reconnecting = true;
    _set(RacketLinkState.reconnecting);
    var attempt = 0;
    while (_wantConnected && attempt < 12) {
      attempt++;
      await Future<void>.delayed(Duration(seconds: math.min(2 * attempt, 10)));
      if (!_wantConnected) break;
      try {
        await _link(_device!);
        _set(RacketLinkState.connected);
        _reconnecting = false;
        return;
      } catch (e) {
        debugPrint('[ble] reconexao $attempt falhou: $e');
        try {
          await _device?.disconnect();
        } catch (_) {}
      }
    }
    _reconnecting = false;
    if (_wantConnected) {
      _wantConnected = false;
      _set(RacketLinkState.error, error: 'Conexao com a raquete perdida. Toque para conectar de novo.');
    }
  }

  Future<void> _teardown() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
  }

  // ----------------------------------------------------------------------
  // Recebimento
  // ----------------------------------------------------------------------

  void _onBytes(List<int> bytes) {
    final id = deviceName ?? 'SwingSense';
    final tacada = Tacada.tryDecode(bytes, recebidoEm: DateTime.now(), dispositivoId: id);
    if (tacada == null) {
      debugPrint('[ble] mensagem invalida ignorada (${bytes.length} bytes)');
      return;
    }
    if (tacada.v != 1) debugPrint('[ble] aviso: versao de formato ${tacada.v} (esperado 1)');
    if (!_forwarding) return; // fora da sessao (ou em pausa): descarta
    _tacadas.add(tacada);
    _events.add(tacada.toSessionEvent());
  }

  @override
  void start() => _forwarding = true;

  @override
  void stop() => _forwarding = false;

  /// A raquete e compartilhada entre telas: so para o repasse.
  @override
  void dispose() => _forwarding = false;

  static String _friendly(Object e) {
    final text = e.toString();
    if (e is TimeoutException || text.contains('timeout') || text.contains('Timeout')) {
      return 'Tempo esgotado ao falar com a raquete. Aproxime o celular e tente de novo.';
    }
    if (text.contains('permission') || text.contains('Permission')) {
      return 'Permissao de Bluetooth negada. Libere nas configuracoes do aparelho.';
    }
    return 'Nao foi possivel conectar na raquete. Tente de novo.';
  }
}

class RacketConnectException implements Exception {
  RacketConnectException(this.message);
  final String message;
  @override
  String toString() => message;
}
