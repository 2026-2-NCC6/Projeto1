import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tacada.dart';
import 'api_client.dart';

typedef TacadaSender = Future<void> Function(List<Map<String, dynamic>> batch);

/// Fila local de tacadas + envio em lote ao backend (`POST /tacadas`).
///
/// * A fila e salva em SharedPreferences: se a internet da quadra cair (ou o
///   app fechar), nada se perde entre o celular e o servidor.
/// * O envio e idempotente: o backend ignora duplicatas pela chave
///   (dispositivoId, boot, seq), entao reenviar nunca duplica.
/// * Erros de rede/servidor (inclusive 501 "ainda nao implementado") mantem a
///   fila; so erros 400/413/422 descartam o lote (dado invalido nao melhora
///   sozinho e travaria a fila).
class TacadaSyncService {
  TacadaSyncService({TacadaSender? sender, bool autoFlush = true})
      : _sender = sender ?? _defaultSender,
        _autoFlush = autoFlush;

  static final TacadaSyncService instance = TacadaSyncService();

  static const _prefsKey = 'swing_sense_tacada_queue';
  static const maxQueue = 5000;
  static const batchSize = 200;

  final TacadaSender _sender;
  final bool _autoFlush;
  final List<Map<String, dynamic>> _queue = [];
  bool _loaded = false;
  bool _flushing = false;
  Timer? _timer;

  int get pending => _queue.length;

  static Future<void> _defaultSender(List<Map<String, dynamic>> batch) async {
    await ApiClient.instance.post('/tacadas', body: {'tacadas': batch});
  }

  static String _key(Map<String, dynamic> m) => '${m['dispositivoId']}|${m['boot']}|${m['seq']}';

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          _queue.add(Map<String, dynamic>.from(item as Map));
        }
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_queue));
    } catch (_) {}
  }

  /// Guarda a tacada na fila (ignorando duplicatas) e agenda o envio.
  Future<void> enqueue(Tacada tacada, {String? sessionId}) async {
    await _load();
    final item = tacada.toApiJson(sessionId: sessionId);
    final key = _key(item);
    if (_queue.any((q) => _key(q) == key)) return;
    _queue.add(item);
    if (_queue.length > maxQueue) _queue.removeRange(0, _queue.length - maxQueue);
    await _persist();
    if (_autoFlush) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), flush);
    }
  }

  /// Envia o que estiver na fila. Retorna quantas tacadas foram aceitas.
  Future<int> flush() async {
    await _load();
    if (_flushing || _queue.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(batchSize).toList();
        try {
          await _sender(batch);
          _queue.removeRange(0, batch.length);
          sent += batch.length;
        } on ApiException catch (e) {
          final invalid = e.statusCode == 400 || e.statusCode == 413 || e.statusCode == 422;
          if (!invalid) break; // 401/5xx/501: tenta de novo mais tarde
          debugPrint('[tacadas] lote descartado (${e.statusCode}): ${e.message}');
          _queue.removeRange(0, batch.length);
        } catch (_) {
          break; // sem rede / timeout
        }
        await _persist();
      }
      await _persist();
    } finally {
      _flushing = false;
    }
    return sent;
  }

  /// Usado no logout: tenta enviar o que sobrou e esvazia a fila, para que as
  /// tacadas de um usuario nunca sejam enviadas com o token de outro.
  Future<void> flushAndClear() async {
    try {
      await flush().timeout(const Duration(seconds: 4));
    } catch (_) {}
    await _load();
    _queue.clear();
    await _persist();
  }
}
