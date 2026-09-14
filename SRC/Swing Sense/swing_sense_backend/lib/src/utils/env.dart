import 'dart:io';

/// Leitor simples de arquivo `.env` (sem depender de nenhum pacote externo).
/// Variaveis ja exportadas no shell (`Platform.environment`) sempre tem
/// prioridade - o `.env` so preenche o que ainda nao estiver definido.
Map<String, String> _fileEnv = {};
bool _loaded = false;

void loadDotEnv([String path = '.env']) {
  if (_loaded) return;
  _loaded = true;

  final file = File(path);
  if (!file.existsSync()) return;

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final eq = line.indexOf('=');
    if (eq == -1) continue;

    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    final isQuoted = value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")));
    if (isQuoted) value = value.substring(1, value.length - 1);

    _fileEnv[key] = value;
  }
}

String? env(String key) => Platform.environment[key] ?? _fileEnv[key];
