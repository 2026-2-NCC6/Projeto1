# Swing Sense - Backend

API REST em Dart (puro, sem framework de app - `shelf` + `shelf_router`) para o
app Swing Sense: rede social de treinos de tenis integrada a uma raquete
inteligente (ESP32 com giroscopio e sensor de velocidade da bola, ainda em
desenvolvimento).

O ambiente foi propositalmente deixado "plug and play": o app mobile usa um
`MockRacketService` que fala com esta mesma API (rota `POST
/sessions/:id/events`) como se fosse o dispositivo real. Quando o ESP32
estiver pronto, basta substituir o mock por uma conexao BLE/Wi-Fi que envie o
mesmo formato de evento - nada na API muda.

## Banco de dados: PostgreSQL (Supabase)

Esta API usa o PostgreSQL hospedado no Supabase como banco de dados. Toda a
leitura/escrita (usuarios, treinos, sessoes, metas, glossario) passa pelo
`PgStore` (`lib/src/db/postgres_store.dart`), que roda queries parametrizadas
contra as tabelas ja criadas no projeto Supabase (`lib/src/db/schema.sql` e a
referencia do modelo de dados). A conexao e feita por `lib/src/db/database.dart`
usando um pool (`package:postgres`).

Configure as credenciais em um `.env` local (nunca commitado - veja
`.env.example`):

```
DB_HOST=aws-0-us-east-1.pooler.supabase.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres.<referencia-do-projeto>
DB_PASSWORD=<senha-do-banco>
DB_SSL_MODE=require
```

Use a connection string do modo **Session pooler** (porta 5432) do Supabase -
o modo Transaction pooler (porta 6543) nao suporta prepared statements, que
esta API usa.

## Como rodar

```bash
cp .env.example .env   # preencha DB_HOST/DB_USER/DB_PASSWORD com os dados do seu Supabase
dart pub get
dart run bin/server.dart
```

Voce vera `Swing Sense API rodando em http://0.0.0.0:8080`.

### Seguranca (Entrega 2)

Variaveis novas (todas opcionais em desenvolvimento - veja `.env.example`):

| Variavel | Funcao |
|----------|--------|
| `APP_ENV` | `production` exige `JWT_SECRET` forte e ativa HSTS |
| `JWT_SECRET` | Segredo >= 32 caracteres (`openssl rand -base64 48`). Vazio em dev => segredo aleatorio temporario |
| `JWT_EXPIRES_IN_HOURS` | Validade do token (padrao 24, maximo 72) |
| `CORS_ALLOWED_ORIGINS` | Allowlist de origens web (virgula) |
| `TRUST_PROXY` | `true` apenas atras de proxy TLS confiavel |
| `TLS_CERT_PATH` / `TLS_KEY_PATH` | TLS nativo (HTTPS) sem proxy |

Testes de seguranca (rodam sem banco): `dart test`.

### Com Docker (opcional)

```bash
docker compose up -d --build
```

## Tacadas da raquete real (BLE)

O app conecta na raquete por Bluetooth (`INTEGRACAO_APP_BLE.md`, na pasta
acima) e envia as tacadas em lote para `POST /tacadas`. A rota
(`lib/src/routes/tacada_routes.dart`) autentica, valida cada campo e entrega as
linhas saneadas para `PgStore.insertTacadas`, que grava de forma idempotente
(`ON CONFLICT (dispositivo_id, boot, seq) DO NOTHING`) numa transacao.

**Pre-requisito:** aplicar `lib/src/db/migrations/001_tacadas.sql` no Supabase
(SQL Editor). Sem a tabela, a rota responde 500 e o app guarda as tacadas na
fila local e tenta de novo (nada se perde). O formato do corpo:

```json
{"tacadas": [{"dispositivoId": "SwingSense-A1B2", "boot": 2891734012, "seq": 37, "t": 152340,
  "recebidoEm": "2026-10-19T12:00:00Z", "tipo": "FH", "incerto": false, "bola": null,
  "acel": 80.4, "giro": 26.3, "vel": 95, "accx": 3.2, "v": 1, "sessionId": "<uuid opcional>"}]}
```

## Estrutura

```
bin/server.dart          Entrypoint HTTP (abre o pool de conexao com o Supabase)
lib/src/app.dart         Monta as rotas publicas e protegidas por JWT
lib/src/db/              Database (pool Postgres), PgStore (queries) e schema.sql de referencia
lib/src/middleware/       Autenticacao (Bearer JWT) e seguranca (CORS, cabecalhos, limite de corpo, erros)
lib/src/utils/            JWT, senha, validadores, rate limiter e configuracao de seguranca
test/security_test.dart   Testes que reproduzem os ataques do relatorio e provam as correcoes
lib/src/routes/           Um arquivo por recurso (auth, users, feed, trainings, sessions, goals, glossary, devices)
lib/src/mappers.dart      Conversao das linhas do Postgres para JSON da API
```

## Principais rotas

| Metodo | Rota                          | Descricao                                            | Auth |
|--------|-------------------------------|-------------------------------------------------------|------|
| POST   | /auth/register                | Cria conta                                             | nao  |
| POST   | /auth/login                   | Login, retorna token JWT                               | nao  |
| POST   | /auth/logout                  | Revoga o token atual                                    | nao  |
| GET    | /glossary                     | Glossario de regras/fundamentos do tenis                | nao  |
| GET    | /users/me                     | Perfil autenticado                                      | sim  |
| PUT    | /users/me                     | Editar perfil                                           | sim  |
| GET    | /users/:id                    | Perfil publico de outro usuario                         | sim  |
| POST   | /users/:id/follow             | Seguir usuario                                          | sim  |
| GET    | /feed                         | Feed de treinos de quem voce segue                       | sim  |
| GET    | /trainings                    | Catalogo de treinos                                      | sim  |
| POST   | /sessions                     | Inicia uma sessao de treino                              | sim  |
| PATCH  | /sessions/:id                 | Pausa/retoma/encerra e atualiza estatisticas             | sim  |
| POST   | /sessions/:id/events           | Ingestao de telemetria (raquete real ou mock)            | sim  |
| GET    | /goals                        | Metas do usuario                                          | sim  |
| POST   | /devices/pair                 | Parear a raquete (simulada ou real)                      | sim  |

Todas as rotas autenticadas esperam o header `Authorization: Bearer <token>`.
