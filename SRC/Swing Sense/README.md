# Swing Sense

Rede social de treinos de tenis (estilo Strava) integrada a uma raquete
inteligente (ESP32 + giroscopio + sensor de velocidade da bola, ainda em
desenvolvimento). Projeto dividido em duas pastas independentes:

```
swing_sense_app/       App mobile Flutter/Dart (Android e iOS)
swing_sense_backend/   API em Dart (shelf + shelf_router), dados em memoria
```

## Visao geral

- Login, cadastro, feed social, perfil (proprio e de outros jogadores), metas,
  catalogo de treinos, sessao de treino ao vivo e glossario de regras/fundamentos
  do tenis para novos usuarios.
- Identidade visual inspirada no Spotify: fundo preto, verde (#1DB954) como cor
  de destaque, texto branco, com telas de carregamento e transicoes animadas.
- A raquete inteligente ainda nao existe fisicamente. Enquanto isso, o app usa
  um `MockRacketService` (`swing_sense_app/lib/services/mock_racket_service.dart`)
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

Nao precisa de banco de dados nem Docker: os dados de demonstracao sao
gerados em memoria automaticamente a cada start do servidor (veja
`swing_sense_backend/README.md` para detalhes).
Login de demonstracao: `demo@swingsense.app` / `senha123`.

### 2. App mobile

```bash
cd swing_sense_app
flutter pub get
flutter run
```

No emulador Android, a API e acessada via `10.0.2.2` automaticamente. No
simulador iOS e no Web, via `localhost`. Para testar em um aparelho fisico na
mesma rede, rode com `--dart-define=API_BASE_URL=http://<ip-da-sua-maquina>:8080`.

## Por que Dart nos dois lados

O time optou por um stack unico em Dart (Flutter no app, `shelf` puro no
backend) para reduzir a curva de aprendizado entre front e back. O ambiente de
hardware foi propositalmente deixado "plug and play" via `MockRacketService`,
ja que a raquete inteligente ainda esta em desenvolvimento.

## Sobre o banco de dados

Por enquanto a API guarda tudo em memoria (nenhum banco externo) para deixar o
setup do projeto trivial durante o desenvolvimento do app e do design. A
integracao com um banco de verdade (PostgreSQL, Firebase, etc.) fica para uma
etapa futura do time - o schema de referencia continua em
`swing_sense_backend/lib/src/db/schema.sql`.
