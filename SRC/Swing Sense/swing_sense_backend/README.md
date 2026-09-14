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

### Com Docker (opcional)

```bash
docker compose up -d --build
```

## Estrutura

```
bin/server.dart          Entrypoint HTTP (abre o pool de conexao com o Supabase)
lib/src/app.dart         Monta as rotas publicas e protegidas por JWT
lib/src/db/              Database (pool Postgres), PgStore (queries) e schema.sql de referencia
lib/src/middleware/       Middleware de autenticacao (Bearer JWT)
lib/src/routes/           Um arquivo por recurso (auth, users, feed, trainings, sessions, goals, glossary, devices)
lib/src/mappers.dart      Conversao das linhas do Postgres para JSON da API
```

## Principais rotas

| Metodo | Rota                          | Descricao                                            | Auth |
|--------|-------------------------------|-------------------------------------------------------|------|
| POST   | /auth/register                | Cria conta                                             | nao  |
| POST   | /auth/login                   | Login, retorna token JWT                               | nao  |
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
