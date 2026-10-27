# Swing Sense

Rede social de treinos de tenis (estilo Strava) integrada a uma raquete
inteligente (ESP32 + giroscopio + sensor de velocidade da bola, ainda em
desenvolvimento). Projeto dividido em duas pastas independentes:

```
swing_sense_frontend/  App mobile Flutter/Dart (Android e iOS; roda tambem no Chrome, sem Bluetooth)
swing_sense_backend/   API em Dart (shelf + shelf_router), dados no PostgreSQL do Supabase
```

## Visao geral

- Login, cadastro, feed social, perfil (proprio e de outros jogadores), metas,
  catalogo de treinos, sessao de treino ao vivo e glossario de regras/fundamentos
  do tenis para novos usuarios.
- Identidade visual inspirada no Spotify: fundo preto, verde (#1DB954) como cor
  de destaque, texto branco, com telas de carregamento e transicoes animadas.
- A raquete real (prototipo ESP32-C3 + MPU6050) fala com o app por Bluetooth
  (`swing_sense_frontend/lib/services/ble/ble_racket_service.dart`) e cada tacada
  e gravada na tabela `tacadas` do Supabase. Sem a raquete, o app usa um
  `MockRacketService` (`swing_sense_frontend/lib/services/mock_racket_service.dart`)
  que gera telemetria realista (velocidade da bola, rotacao, angulo) e a envia
  para a API pelo mesmo contrato que o ESP32 usara no futuro
  (`POST /sessions/:id/events`). Trocar o mock pelo hardware real nao exige
  mudar nada na API.

## Como rodar

### 1. Backend

```bash
cd swing_sense_backend
dart pub get
dart run bin/server.dart
```

Precisa de um `.env` com as credenciais do Supabase (copie `.env.example`;
detalhes em `swing_sense_backend/README.md`). A API conecta no banco ao subir e
falha logo se as credenciais estiverem erradas.

### 2. App mobile

```bash
cd swing_sense_frontend
flutter pub get
flutter run
```

No emulador Android, a API e acessada via `10.0.2.2` automaticamente. No
simulador iOS e no Web, via `localhost`. Para testar em um aparelho fisico na
mesma rede, rode com `--dart-define=API_BASE_URL=http://<ip-da-sua-maquina>:8080`.

## Por que Dart nos dois lados

O time optou por um stack unico em Dart (Flutter no app, `shelf` puro no
backend) para reduzir a curva de aprendizado entre front e back. O app aceita
tanto a raquete real (BLE) quanto a simulada (`MockRacketService`) pela mesma
interface (`RacketSource`).

## Sobre o banco de dados

Os dados ficam no PostgreSQL do Supabase. A API conecta direto pelo pooler
(pacote `postgres`), sem usar o SDK nem a API REST do Supabase, e todas as
tabelas tem RLS ligado.

- Modelo de dados de referencia: `swing_sense_backend/lib/src/db/schema.sql`
- Mudancas posteriores, em ordem: `swing_sense_backend/lib/src/db/migrations/`
  (`001_tacadas.sql` cria a tabela de tacadas da raquete real;
  `002_tacadas_estatisticas.sql` adiciona estatisticas, views e triggers)

Fluxo do dado da raquete: raquete -> BLE -> app (fila local, reenvio sem
duplicar) -> `POST /tacadas` -> tabela `tacadas`. O banco mantem sozinho a
velocidade da raquete de cada sessao e o `last_sync_at` do dispositivo.
