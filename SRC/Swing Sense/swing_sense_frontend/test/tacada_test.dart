import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swing_sense_app/models/tacada.dart';
import 'package:swing_sense_app/services/api_client.dart';
import 'package:swing_sense_app/services/tacada_sync_service.dart';

const _exemplo =
    '{"v":1,"boot":2891734012,"seq":37,"t":152340,"tipo":"FH","incerto":false,"bola":null,"acel":80.4,"giro":26.3,"vel":95,"accx":3.2}';
final _agora = DateTime.utc(2026, 10, 19, 12, 0, 0);

Tacada? _decode(String json) =>
    Tacada.tryDecode(utf8.encode(json), recebidoEm: _agora, dispositivoId: 'SwingSense-A1B2');

Tacada _tacada(int seq, {int boot = 1}) => Tacada(
      v: 1, boot: boot, seq: seq, t: seq * 1000, tipo: 'FH', incerto: false, bola: null,
      acel: 80.4, giro: 26.3, vel: 95, accx: 3.2, recebidoEm: _agora, dispositivoId: 'SwingSense-A1B2',
    );

void main() {
  group('Tacada (contrato BLE)', () {
    test('JSON de exemplo do documento', () {
      final t = _decode(_exemplo)!;
      expect(t.v, 1);
      expect(t.boot, 2891734012); // uint32: estoura int de 32 bits com sinal
      expect(t.seq, 37);
      expect(t.t, 152340);
      expect(t.tipo, 'FH');
      expect(t.incerto, isFalse);
      expect(t.bola, isNull);
      expect(t.acel, 80.4);
      expect(t.giro, 26.3);
      expect(t.vel, 95);
      expect(t.accx, 3.2);
      expect(t.recebidoEm, _agora);
      expect(t.dispositivoId, 'SwingSense-A1B2');
    });

    test('bola true e false (formato futuro)', () {
      expect(_decode(_exemplo.replaceFirst('"bola":null', '"bola":true'))!.bola, isTrue);
      expect(_decode(_exemplo.replaceFirst('"bola":null', '"bola":false'))!.bola, isFalse);
    });

    test('campo extra desconhecido e ignorado', () {
      final t = _decode(_exemplo.replaceFirst('"vel":95', '"vel":95,"novo":123,"outro":{"a":1}'));
      expect(t, isNotNull);
      expect(t!.vel, 95);
    });

    test('BH com incerto true', () {
      final t = _decode(_exemplo.replaceFirst('"FH"', '"BH"').replaceFirst('"incerto":false', '"incerto":true'))!;
      expect(t.tipo, 'BH');
      expect(t.incerto, isTrue);
      expect(t.toSessionEvent().eventType, 'backhand');
    });

    test('versao de formato diferente nao quebra', () {
      final t = _decode(_exemplo.replaceFirst('"v":1', '"v":2'));
      expect(t, isNotNull);
      expect(t!.v, 2);
    });

    test('mensagens invalidas retornam null (nunca lancam)', () {
      expect(_decode('nao e json'), isNull);
      expect(_decode('[1,2,3]'), isNull);
      expect(_decode('{}'), isNull);
      expect(_decode(_exemplo.replaceFirst('"FH"', '"XX"')), isNull);
      expect(_decode(_exemplo.replaceFirst('"acel":80.4', '"acel":"alto"')), isNull);
      expect(Tacada.tryDecode([0xFF, 0xFE, 0x00], recebidoEm: _agora, dispositivoId: 'x'), isNull);
    });

    test('toApiJson: campos do contrato e horario em UTC', () {
      final j = _tacada(5).toApiJson(sessionId: 'abc');
      expect(j['dispositivoId'], 'SwingSense-A1B2');
      expect(j['seq'], 5);
      expect(j['recebidoEm'], '2026-10-19T12:00:00.000Z');
      expect(j['bola'], isNull);
      expect(j['sessionId'], 'abc');
      expect(_tacada(5).toApiJson().containsKey('sessionId'), isFalse);
    });

    test('toSessionEvent alimenta a tela de sessao', () {
      final e = _tacada(1).toSessionEvent();
      expect(e.eventType, 'forehand');
      expect(e.ballSpeedKmh, 95);
    });
  });

  group('TacadaSyncService (fila local)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('envia em lote e esvazia a fila', () async {
      final enviados = <List<Map<String, dynamic>>>[];
      final s = TacadaSyncService(sender: (b) async => enviados.add(b), autoFlush: false);
      for (var i = 1; i <= 3; i++) {
        await s.enqueue(_tacada(i));
      }
      expect(s.pending, 3);
      expect(await s.flush(), 3);
      expect(s.pending, 0);
      expect(enviados.single.map((m) => m['seq']), [1, 2, 3]);
    });

    test('duplicata (mesmo dispositivo, boot e seq) nao entra duas vezes', () async {
      final s = TacadaSyncService(sender: (_) async {}, autoFlush: false);
      await s.enqueue(_tacada(1));
      await s.enqueue(_tacada(1));
      await s.enqueue(_tacada(1, boot: 2)); // outro boot = outra tacada
      expect(s.pending, 2);
    });

    test('falha de rede mantem a fila e reenvia depois', () async {
      var falhar = true;
      final s = TacadaSyncService(
        sender: (_) async {
          if (falhar) throw Exception('sem internet');
        },
        autoFlush: false,
      );
      await s.enqueue(_tacada(1));
      expect(await s.flush(), 0);
      expect(s.pending, 1);
      falhar = false;
      expect(await s.flush(), 1);
      expect(s.pending, 0);
    });

    test('501 (backend ainda sem banco) mantem a fila; 400 descarta o lote', () async {
      var status = 501;
      final s = TacadaSyncService(sender: (_) async => throw ApiException('x', statusCode: status), autoFlush: false);
      await s.enqueue(_tacada(1));
      await s.flush();
      expect(s.pending, 1);
      status = 400;
      await s.flush();
      expect(s.pending, 0);
    });

    test('fila sobrevive ao fechar o app (SharedPreferences)', () async {
      final a = TacadaSyncService(sender: (_) async => throw Exception('offline'), autoFlush: false);
      await a.enqueue(_tacada(7));
      final enviados = <List<Map<String, dynamic>>>[];
      final b = TacadaSyncService(sender: (x) async => enviados.add(x), autoFlush: false); // "app reaberto"
      expect(await b.flush(), 1);
      expect(enviados.single.single['seq'], 7);
    });

    test('lotes de no maximo 200', () async {
      final tamanhos = <int>[];
      final s = TacadaSyncService(sender: (b) async => tamanhos.add(b.length), autoFlush: false);
      for (var i = 1; i <= 450; i++) {
        await s.enqueue(_tacada(i));
      }
      await s.flush();
      expect(tamanhos, [200, 200, 50]);
    });

    test('flushAndClear esvazia a fila (troca de usuario)', () async {
      final s = TacadaSyncService(sender: (_) async => throw Exception('offline'), autoFlush: false);
      await s.enqueue(_tacada(1));
      await s.flushAndClear();
      expect(s.pending, 0);
    });
  });
}
