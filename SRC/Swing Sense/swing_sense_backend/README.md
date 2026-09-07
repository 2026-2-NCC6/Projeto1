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

## Banco de dados: em memoria (por enquanto)

Esta API **nao usa PostgreSQL nem qualquer outro banco externo** no momento -
todos os dados (usuarios, treinos, sessoes, metas, glossario) vivem em uma
`MemoryStore` (`lib/src/db/memory_store.dart`), populada automaticamente com
dados de demonstracao toda vez que o servidor inicia (`lib/src/db/database.dart`).
Isso significa:

- **Nao precisa instalar nada** (nem Docker, nem Postgres) para rodar.
- Os dados **resetam** cada vez que o servidor e reiniciado.
- `lib/src/db/schema.sql` ficou como referencia do modelo de dados original em
  SQL, para quando alguem do time for plugar um banco de verdade.

Login de demonstracao (recriado a cada start do servidor):
`demo@swingsense.app` / `senha123`.

## Como rodar

```bash
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
bin/server.dart          Entrypoint HTTP (cria a MemoryStore e ja semeia os dados demo)
lib/src/app.dart         Monta as rotas publicas e protegidas por JWT
lib/src/db/              MemoryStore (dados em memoria) + schema.sql de referencia
lib/src/middleware/       Middleware de autenticacao (Bearer JWT)
lib/src/routes/           Um arquivo por recurso (auth, users, feed, trainings, sessions, goals, glossary, devices)
lib/src/mappers.dart      Conversao dos registros em memoria para JSON da API
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
