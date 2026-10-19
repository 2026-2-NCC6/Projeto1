/// Validacoes de entrada compartilhadas pelas rotas (R-06, R-11 e correcoes
/// complementares da Entrega 2). Cada funcao retorna `null` quando o valor e
/// valido ou uma mensagem de erro (sem acentos, igual ao resto da API).
library;

final _uuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _emailRegex = RegExp(r'^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$');
final _slugRegex = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
final _hexColorRegex = RegExp(r'^[0-9a-fA-F]{6}$');

const validLevels = {'iniciante', 'intermediario', 'avancado', 'profissional'};
const validGoalStatuses = {'active', 'completed', 'cancelled', 'expired'};

const maxPasswordLength = 128;
const minPasswordLength = 8;

/// Senhas muito comuns (subconjunto das listas publicas mais usadas).
const _commonPasswords = {
  '12345678', '123456789', '1234567890', 'password', 'password1', 'senha123',
  'qwerty123', 'qwertyui', 'abc12345', 'iloveyou', '11111111', '00000000',
  'senha1234', 'brasil123', 'admin123', 'letmein1', 'welcome1', 'tenis123',
  'swingsense', 'swingsense1', 'mudar123', 'teste123', 'abcd1234', '1q2w3e4r',
};

bool isUuid(String? value) => value != null && _uuidRegex.hasMatch(value);

bool isValidEmail(String value) => value.length <= 254 && _emailRegex.hasMatch(value);

bool isSlug(String value) => _slugRegex.hasMatch(value);

bool isHexColor(String value) => _hexColorRegex.hasMatch(value);

/// Politica de senha (apenas no cadastro; o login continua aceitando senhas
/// antigas de 6+ caracteres para nao trancar contas existentes).
String? validatePassword(String password, {String? email, String? name}) {
  if (password.length < minPasswordLength) {
    return 'Senha deve ter pelo menos $minPasswordLength caracteres';
  }
  if (password.length > maxPasswordLength) {
    return 'Senha deve ter no maximo $maxPasswordLength caracteres';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password)) {
    return 'Senha deve conter letras e numeros';
  }
  final lower = password.toLowerCase();
  if (_commonPasswords.contains(lower)) {
    return 'Senha muito comum, escolha outra';
  }
  if (email != null && email.isNotEmpty && lower.contains(email.split('@').first.toLowerCase()) && email.split('@').first.length >= 4) {
    return 'Senha nao pode conter o seu email';
  }
  if (name != null && name.trim().length >= 4 && lower == name.trim().toLowerCase()) {
    return 'Senha nao pode ser igual ao nome';
  }
  return null;
}

/// Valida um texto opcional/obrigatorio com limite de tamanho.
String? validateText(Object? value, String label, {int min = 0, required int max, bool required = false}) {
  if (value == null) return required ? '$label e obrigatorio' : null;
  if (value is! String) return '$label deve ser um texto';
  final length = value.trim().length;
  if (required && length == 0) return '$label e obrigatorio';
  if (length < min) return '$label deve ter pelo menos $min caracteres';
  if (value.length > max) return '$label deve ter no maximo $max caracteres';
  return null;
}

/// Valida um numero (int ou double) dentro de uma faixa. `null` e aceito.
String? validateNumber(Object? value, String label, {required num min, required num max, bool integer = false}) {
  if (value == null) return null;
  if (value is! num) return '$label deve ser numerico';
  if (value is double && (value.isNaN || value.isInfinite)) return '$label invalido';
  if (integer && value != value.truncate()) return '$label deve ser inteiro';
  if (value < min || value > max) return '$label deve estar entre $min e $max';
  return null;
}

/// Aceita somente URLs http(s) (bloqueia `javascript:`, `data:`, `file:` etc.).
String? validateHttpUrl(Object? value, String label, {int max = 500}) {
  if (value == null) return null;
  if (value is! String) return '$label deve ser um texto';
  if (value.isEmpty) return null;
  if (value.length > max) return '$label deve ter no maximo $max caracteres';
  final uri = Uri.tryParse(value);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
    return '$label deve ser uma URL http(s) valida';
  }
  return null;
}

/// Data (yyyy-mm-dd ou ISO-8601) opcional.
String? validateDate(Object? value, String label, {DateTime? notAfter, DateTime? notBefore}) {
  if (value == null) return null;
  if (value is! String) return '$label deve ser um texto';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '$label invalida';
  if (notAfter != null && parsed.isAfter(notAfter)) return '$label invalida';
  if (notBefore != null && parsed.isBefore(notBefore)) return '$label invalida';
  return null;
}

/// Escapa `%`, `_` e `\` para uso seguro em `ILIKE ... ESCAPE '\'`.
String escapeLike(String input) {
  return input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
