# Swing Sense - Backend

API REST em Dart (puro, sem framework de app - `shelf` + `shelf_router`) para o
app Swing Sense: rede social de treinos de tenis integrada a uma raquete
inteligente (prototipo ESP32-C3 com giroscopio/acelerometro MPU6050; o sensor
de velocidade da bola ainda nao existe).

O app conversa com esta API de dois jeitos: a raquete real envia as tacadas por
Bluetooth e o app as encaminha em lote para `POST /tacadas`; sem a raquete, o
`MockRacketService` gera eventos no mesmo formato de `POST
/sessions/:id/events`.

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

Use a connection string do modo **Session pooler** (porta 5432) do Supabase,
que e a indicada para um servidor de longa duracao como este. O Transaction
pooler (porta 6543) tambem respondeu a consultas parametrizadas nos testes, mas
nao e o modo recomendado: se usar, nao troque o `queryMode` do driver para
`simple`, que nao aceita parametros.

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

O app conecta na raquete por Bluetooth e envia as tacadas em lote para
`POST /tacadas`. A rota (`lib/src/routes/tacada_routes.dart`) autentica, valida
cada campo e entrega as linhas saneadas para `PgStore.insertTacadas`, que grava
de forma idempotente (`ON CONFLICT (dispositivo_id, boot, seq) DO NOTHING`) numa
transacao.

**Migrations (ja aplicadas no Supabase do projeto):**

- `001_tacadas.sql`: tabela `tacadas`, com RLS ligado.
- `002_tacadas_estatisticas.sql`: somente aditiva. Adiciona
  `sessoes_treinamento.is_demo` e `avg/max_racket_speed_kmh`; triggers que
  mantem essas colunas e o `dispositivos.last_sync_at` a cada lote de tacadas;
  o tipo `SQ` (saque); indice unico de dispositivo por usuario; e as views
  `v_tacadas_sessao`, `v_tacadas_usuario` e `v_sessoes_qualidade`
  (`security_invoker`, sem acesso pela chave publica do Supabase).

Para um banco novo, aplique-as em ordem no SQL Editor.

**Escrita** - formato do corpo de `POST /tacadas` (`tipo`: `FH`, `BH` ou `SQ`):

```json
{"tacadas": [{"dispositivoId": "SwingSense-A1B2", "boot": 2891734012, "seq": 37, "t": 152340,
  "recebidoEm": "2026-10-19T12:00:00Z", "tipo": "FH", "incerto": false, "bola": null,
  "acel": 80.4, "giro": 26.3, "vel": 95, "accx": 3.2, "v": 1, "sessionId": "<uuid opcional>"}]}
```

**Leitura** - sempre do usuario do token:

| Rota | Retorno |
|------|---------|
| `GET /tacadas?sessionId=&limit=&offset=` | Tacadas, da mais antiga para a mais nova (`limit` 1 a 500, padrao 100) |
| `GET /tacadas/summary[?sessionId=]` | FH, BH, saque, incertas, medias e picos. Sem dados, devolve zeros |

Observacao: `vel` e a velocidade ESTIMADA da raquete (pico de giro x 0,6 m), uma
metrica relativa derivada do giro. Ela aparece nas sessoes como
`avgRacketSpeedKmh`/`maxRacketSpeedKmh`; os campos `*BallSpeedKmh` continuam
existindo, mas so fazem sentido quando houver um sensor de bola.

## Estrutura

```
bin/server.dart          Entrypoint HTTP (abre o pool de conexao com o Supabase)
lib/src/app.dart         Monta as rotas publicas e protegidas por JWT
lib/src/db/              Database (pool Postgres), PgStore (queries), schema.sql de referencia e migrations/
lib/src/middleware/       Autenticacao (Bearer JWT) e seguranca (CORS, cabecalhos, limite de corpo, erros)
lib/src/utils/            JWT, senha, validadores, rate limiter e configuracao de seguranca
test/security_test.dart   Testes que reproduzem os ataques do relatorio e provam as correcoes
test/tacada_test.dart     Testes de POST/GET /tacadas (banco simulado)
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
| GET    | /feed                         | Feed de treinos de quem voce segue (so sessoes com tacadas) | sim  |
| GET    | /trainings                    | Catalogo de treinos                                      | sim  |
| POST   | /sessions                     | Inicia uma sessao de treino                              | sim  |
| PATCH  | /sessions/:id                 | Pausa/retoma/encerra e atualiza estatisticas             | sim  |
| POST   | /sessions/:id/events           | Ingestao de telemetria (raquete real ou mock)            | sim  |
| POST   | /tacadas                      | Grava um lote de tacadas da raquete real (idempotente)   | sim  |
| GET    | /tacadas                      | Lista as tacadas do usuario (filtro por sessao, paginado) | sim  |
| GET    | /tacadas/summary              | Estatisticas das tacadas (usuario ou sessao)             | sim  |
| GET    | /goals                        | Metas do usuario                                          | sim  |
| POST   | /devices/pair                 | Parear a raquete (simulada ou real)                      | sim  |

Todas as rotas autenticadas esperam o header `Authorization: Bearer <token>`.
