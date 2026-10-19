/// Limitador de taxa em memoria (janela deslizante) usado contra forca bruta e
/// abuso (R-05, R-04). Em memoria => por instancia da API; para varias
/// replicas, mover para Redis/gateway (ver relatorio, "risco residual").
class SlidingWindowLimiter {
  SlidingWindowLimiter({
    required this.maxAttempts,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxAttempts;
  final Duration window;
  final DateTime Function() _now;
  final Map<String, List<DateTime>> _hits = {};

  static const _maxKeys = 20000;

  List<DateTime> _recent(String key) {
    final cutoff = _now().subtract(window);
    final list = _hits[key];
    if (list == null) return const [];
    list.removeWhere((t) => !t.isAfter(cutoff));
    if (list.isEmpty) {
      _hits.remove(key);
      return const [];
    }
    return list;
  }

  /// Retorna quanto tempo falta para liberar, ou `null` se ainda ha cota.
  Duration? blockedFor(String key) {
    final list = _recent(key);
    if (list.length < maxAttempts) return null;
    final releaseAt = list.first.add(window);
    final wait = releaseAt.difference(_now());
    return wait.isNegative ? Duration.zero : wait;
  }

  void record(String key) {
    if (_hits.length >= _maxKeys) _prune();
    _hits.putIfAbsent(key, () => []).add(_now());
  }

  /// Verifica a cota e, se houver, ja registra a tentativa.
  Duration? hit(String key) {
    final blocked = blockedFor(key);
    if (blocked != null) return blocked;
    record(key);
    return null;
  }

  void reset(String key) => _hits.remove(key);

  void _prune() {
    final cutoff = _now().subtract(window);
    _hits.removeWhere((_, list) {
      list.removeWhere((t) => !t.isAfter(cutoff));
      return list.isEmpty;
    });
    // Protecao extra contra exaustao de memoria por chaves unicas.
    if (_hits.length >= _maxKeys) _hits.clear();
  }
}
