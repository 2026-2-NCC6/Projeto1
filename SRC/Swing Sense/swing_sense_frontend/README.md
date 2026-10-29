# Swing Sense - App

App Flutter (Android, iOS e Web) do Swing Sense: rede social de treinos de tenis
integrada a uma raquete inteligente. Fala apenas com a API do backend
(`../swing_sense_backend`); nao acessa o banco diretamente.

## Como rodar

```bash
flutter pub get
flutter run                      # aparelho ou emulador
flutter run -d chrome            # navegador (sem Bluetooth: usa a raquete simulada)
```

A URL da API vem de `lib/core/config/app_config.dart`: `10.0.2.2:8080` no emulador
Android e `localhost:8080` nos demais. Para um aparelho fisico na mesma rede:

```bash
flutter run --dart-define=API_BASE_URL=http://<ip-da-sua-maquina>:8080
```

Em build de release o app so aceita HTTPS (exceto localhost).

## Raquete

| Origem | Arquivo | Uso |
|--------|---------|-----|
| Raquete real (BLE) | `lib/services/ble/ble_racket_service.dart` | Conecta ao servico GATT `SwingSense`, recebe um JSON por tacada |
| Raquete simulada | `lib/services/mock_racket_service.dart` | Gera telemetria sem hardware |

As duas implementam `RacketSource` (`lib/services/racket_source.dart`), entao a
tela de treino nao muda. As tacadas da raquete real passam por
`TacadaSyncService` (`lib/services/tacada_sync_service.dart`): fila local salva no
aparelho, envio em lote para `POST /tacadas` e reenvio sem duplicar se a rede cair.

Ao encerrar um treino, o app espera o envio das tacadas (ate 6 s) antes de abrir
o resumo, que le as estatisticas em `GET /tacadas/summary`
(`lib/services/tacada_service.dart`). Com raquete real o resumo e o feed mostram a
velocidade da RAQUETE (estimada, relativa); sem ela, a velocidade da bola.

## Testes

```bash
flutter test
```

O teste `test/widget_test.dart` ("App inicia na splash screen sem travar") falha por
um `Timer` pendente na splash. Ja falhava antes das mudancas de estatisticas de
tacadas.
