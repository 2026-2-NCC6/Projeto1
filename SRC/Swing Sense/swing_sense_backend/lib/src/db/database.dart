import 'package:postgres/postgres.dart';

import '../utils/env.dart';
import 'postgres_store.dart';

/// Conexao com o PostgreSQL do Supabase. As credenciais vem de variaveis de
/// ambiente (veja `.env.example`) - nunca ficam hardcoded no codigo.
class Database {
  Database._(this.pool, this.store);

  final Pool pool;
  final PgStore store;

  static Future<Database> connect() async {
    loadDotEnv();

    final host = env('DB_HOST');
    final username = env('DB_USER');
    final password = env('DB_PASSWORD');

    if (host == null || host.isEmpty || username == null || password == null) {
      throw StateError(
        'Configuracao do banco ausente: defina DB_HOST, DB_USER e DB_PASSWORD '
        '(copie .env.example para .env e preencha com as credenciais do Supabase).',
      );
    }

    final port = int.tryParse(env('DB_PORT') ?? '') ?? 5432;
    final database = env('DB_NAME') ?? 'postgres';
    final sslMode = _parseSslMode(env('DB_SSL_MODE'));

    final pool = Pool.withEndpoints(
      [
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password,
        ),
      ],
      settings: PoolSettings(
        sslMode: sslMode,
        maxConnectionCount: 5,
      ),
    );

    // Falha rapido na subida do servidor se as credenciais/host estiverem errados.
    await pool.execute('SELECT 1');

    return Database._(pool, PgStore(pool));
  }

  Future<void> close() => pool.close();
}

SslMode _parseSslMode(String? value) {
  switch (value) {
    case 'disable':
      return SslMode.disable;
    case 'verify-full':
      return SslMode.verifyFull;
    case 'require':
    default:
      return SslMode.require;
  }
}
