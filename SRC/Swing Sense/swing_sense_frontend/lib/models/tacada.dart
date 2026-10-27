import 'dart:convert';

import 'session_event.dart';

/// Uma tacada enviada pelo prototipo (ESP32-C3 + MPU6050) via BLE.
///
/// Segue o contrato fixo descrito em `INTEGRACAO_APP_BLE.md`: cada
/// notificacao BLE e um JSON UTF-8 completo com uma unica tacada. Campos
/// desconhecidos sao ignorados e `bola` e opcional (hoje sempre `null`).
class Tacada {
  Tacada({
    required this.v,
    required this.boot,
    required this.seq,
    required this.t,
    required this.tipo,
    required this.incerto,
    required this.bola,
    required this.acel,
    required this.giro,
    required this.vel,
    required this.accx,
    required this.recebidoEm,
    required this.dispositivoId,
  });

  /// Versao do formato da mensagem (atual: 1).
  final int v;

  /// Numero sorteado cada vez que o prototipo liga (0 a 4294967295).
  final int boot;

  /// Contador de tacadas desde que o prototipo ligou (1, 2, 3...).
  final int seq;

  /// Milissegundos desde que o prototipo ligou. Nao e data/hora.
  final int t;

  /// "FH" (forehand), "BH" (backhand) ou "SQ" (saque, quando o firmware passar
  /// a classificar; hoje o saque ainda chega como "FH").
  final String tipo;

  /// true se a classificacao ficou perto do limiar (pode estar errada).
  final bool incerto;

  /// Se acertou a bola. null = ainda nao medido.
  final bool? bola;

  /// Pico de aceleracao (m/s2).
  final double acel;

  /// Pico de velocidade angular (rad/s).
  final double giro;

  /// Velocidade ESTIMADA da raquete (km/h). Metrica relativa, a validar.
  final int vel;

  /// Valor interno da classificacao (depuracao/calibracao).
  final double accx;

  /// Horario do celular ao receber a notificacao (o prototipo nao tem relogio).
  final DateTime recebidoEm;

  /// Nome anunciado pelo prototipo, ex.: `SwingSense-A1B2`. Nao usar o
  /// `remoteId`: no iOS ele muda de celular para celular.
  final String dispositivoId;

  bool get isForehand => tipo == 'FH';
  bool get isServe => tipo == 'SQ';

  /// Decodifica os bytes de uma notificacao. Retorna `null` se a mensagem for
  /// invalida (o app registra e segue, nunca quebra).
  static Tacada? tryDecode(List<int> bytes, {required DateTime recebidoEm, required String dispositivoId}) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      return tryParse(decoded, recebidoEm: recebidoEm, dispositivoId: dispositivoId);
    } catch (_) {
      return null;
    }
  }

  static Tacada? tryParse(Map<String, dynamic> j, {required DateTime recebidoEm, required String dispositivoId}) {
    final v = j['v'];
    final boot = j['boot'];
    final seq = j['seq'];
    final t = j['t'];
    final tipo = j['tipo'];
    final incerto = j['incerto'];
    final bola = j['bola'];
    final acel = j['acel'];
    final giro = j['giro'];
    final vel = j['vel'];
    final accx = j['accx'];

    if (v is! int || boot is! int || seq is! int || t is! int) return null;
    if (tipo != 'FH' && tipo != 'BH' && tipo != 'SQ') return null;
    if (incerto is! bool) return null;
    if (bola != null && bola is! bool) return null;
    if (acel is! num || giro is! num || vel is! num || accx is! num) return null;

    return Tacada(
      v: v,
      boot: boot,
      seq: seq,
      t: t,
      tipo: tipo as String,
      incerto: incerto,
      bola: bola as bool?,
      acel: acel.toDouble(),
      giro: giro.toDouble(),
      vel: vel.round(),
      accx: accx.toDouble(),
      recebidoEm: recebidoEm,
      dispositivoId: dispositivoId,
    );
  }

  /// Identidade da tacada: (dispositivoId, boot, seq). Usada para evitar
  /// duplicatas na fila local e no banco.
  String get chave => '$dispositivoId|$boot|$seq';

  /// Corpo enviado ao backend (`POST /tacadas`). O usuario vem do token.
  Map<String, dynamic> toApiJson({String? sessionId}) => {
        'dispositivoId': dispositivoId,
        'boot': boot,
        'seq': seq,
        't': t,
        'recebidoEm': recebidoEm.toUtc().toIso8601String(),
        'tipo': tipo,
        'incerto': incerto,
        'bola': bola,
        'acel': acel,
        'giro': giro,
        'vel': vel,
        'accx': accx,
        'v': v,
        if (sessionId != null) 'sessionId': sessionId,
      };

  /// Converte para o evento de telemetria que a tela de sessao ao vivo e a
  /// rota `POST /sessions/:id/events` ja entendem.
  ///
  /// `vel` e a velocidade estimada da RAQUETE (nao da bola) e e relativa; ela
  /// alimenta `ballSpeedKmh` porque a interface atual so exibe essa metrica.
  /// Quando a medicao da bola existir, trocar aqui.
  SessionEvent toSessionEvent() => SessionEvent(
        eventType: isServe ? 'serve' : (isForehand ? 'forehand' : 'backhand'),
        ballSpeedKmh: vel.toDouble(),
        occurredAt: recebidoEm,
      );
}
