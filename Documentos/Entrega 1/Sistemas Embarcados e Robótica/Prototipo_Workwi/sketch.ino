/*
  PASSO 2 — Máquina de estados: detectar e classificar a tacada

  Continua de onde o Passo 1 parou. A diferença é que agora, em vez de
  só imprimir os valores brutos, o código observa a aceleração e o giro
  pra decidir em que "fase" do movimento a raquete está:

      PARADO --(giro sustentado)--> PREPARACAO --(pico de aceleração)--> IMPACTO
        ^                                                                   |
        |                                                                   v
        +-------------------------- RECUPERACAO <--------------------------+
                        (aceleração estabiliza)

  No instante do IMPACTO, guardamos os valores do sensor e classificamos
  o golpe (regra simples: orientação da raquete no pico).

  IMPORTANTE: os limiares (LIMIAR_...) abaixo são um ponto de partida.
  Quase certeza que você vai precisar ajustar eles testando na prática
  (ver seção "COMO CALIBRAR" no fim do arquivo).
*/

#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>

Adafruit_MPU6050 mpu;

// ---------- Estados da máquina ----------
enum EstadoTacada {
  PARADO,
  PREPARACAO,
  IMPACTO,
  RECUPERACAO
};

EstadoTacada estadoAtual = PARADO;

// ---------- Limiares (AJUSTE conforme calibração) ----------
const float LIMIAR_GIRO_PREPARACAO      = 1.5;   // rad/s  - rotação que indica início do movimento
const float LIMIAR_ACEL_IMPACTO         = 20.0;  // m/s²   - pico de aceleração no momento da batida
const float LIMIAR_ACEL_ESTAVEL         = 12.0;  // m/s²   - "quase parado de novo" (perto da gravidade ~9.8)
const unsigned long TIMEOUT_PREPARACAO      = 1000; // ms - se preparar e não bater, cancela
const unsigned long TEMPO_ESTAVEL_RECUPERACAO = 150; // ms - tempo estável pra confirmar fim do golpe
const unsigned long TIMEOUT_RECUPERACAO_SEG  = 2000; // ms - trava de segurança pra não ficar preso no estado

unsigned long marcaTempo = 0;
unsigned long tempoEstavelDesde = 0;

// Dados guardados no instante do impacto, usados pra classificar
float accelZ_noImpacto = 0;
float giroZ_noImpacto  = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    delay(10);
  }

  Serial.println("Iniciando MPU6050...");

  if (!mpu.begin()) {
    Serial.println("ERRO: não encontrou o MPU6050. Confira os fios!");
    while (1) {
      delay(10);
    }
  }

  Serial.println("MPU6050 conectado com sucesso!");

  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  delay(100);
  Serial.println("Máquina de estados pronta. Balance a raquete pra testar!");
}

void loop() {
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  float accelMag = sqrt(a.acceleration.x * a.acceleration.x +
                         a.acceleration.y * a.acceleration.y +
                         a.acceleration.z * a.acceleration.z);

  float giroMag = sqrt(g.gyro.x * g.gyro.x +
                        g.gyro.y * g.gyro.y +
                        g.gyro.z * g.gyro.z);

  unsigned long agora = millis();

  switch (estadoAtual) {

    case PARADO:
      if (giroMag > LIMIAR_GIRO_PREPARACAO) {
        estadoAtual = PREPARACAO;
        marcaTempo = agora;
        Serial.println(">> PREPARACAO (rotação detectada)");
      }
      break;

    case PREPARACAO:
      if (accelMag > LIMIAR_ACEL_IMPACTO) {
        // Guarda os dados do instante do golpe ANTES de mudar de estado
        accelZ_noImpacto = a.acceleration.z;
        giroZ_noImpacto  = g.gyro.z;

        estadoAtual = IMPACTO;
        marcaTempo = agora;
        classificarTacada();
      } else if (agora - marcaTempo > TIMEOUT_PREPARACAO) {
        // Girou mas não bateu a tempo -> cancela e volta
        estadoAtual = PARADO;
        Serial.println(">> Cancelado (girou mas não impactou), voltando pro PARADO");
      }
      break;

    case IMPACTO:
      // Estado é só um "flash" -- já emenda pra recuperação
      estadoAtual = RECUPERACAO;
      marcaTempo = agora;
      tempoEstavelDesde = 0;
      break;

    case RECUPERACAO:
      if (accelMag < LIMIAR_ACEL_ESTAVEL) {
        if (tempoEstavelDesde == 0) {
          tempoEstavelDesde = agora;
        } else if (agora - tempoEstavelDesde > TEMPO_ESTAVEL_RECUPERACAO) {
          estadoAtual = PARADO;
          Serial.println(">> PARADO (pronto pra próxima tacada)\n");
        }
      } else {
        tempoEstavelDesde = 0; // ainda balançando muito, reseta a contagem
      }

      // Trava de segurança: nunca fica preso indefinidamente num estado
      if (agora - marcaTempo > TIMEOUT_RECUPERACAO_SEG) {
        estadoAtual = PARADO;
      }
      break;
  }

  // Descomente as linhas abaixo pra ver os valores brutos enquanto calibra os limiares:
  Serial.print("accelMag: "); Serial.print(accelMag);
  Serial.print("  giroMag: "); Serial.println(giroMag);

  delay(1000); // ~100 leituras/segundo -- mais rápido que o Passo 1, pra não perder o pico do impacto
}

void classificarTacada() {
  Serial.print(">> TACADA DETECTADA!  accelZ=");
  Serial.print(accelZ_noImpacto);
  Serial.print("  giroZ=");
  Serial.print(giroZ_noImpacto);

  // Regra simples (igual à ideia da arquitetura): orientação da raquete no pico.
  // - Se accelZ ficou baixo/negativo no impacto -> raquete estava mais "na vertical"
  //   (braço acima da cabeça) -> SAQUE
  // - Senão, foi um golpe horizontal -> usa o giro em Z pra decidir forehand ou backhand
  //
  // Esses números (3.0, sinal do giroZ) são só um chute inicial -- ajuste depois
  // de olhar os valores reais que aparecem no Monitor Serial durante os testes.

  String tipo;
  if (accelZ_noImpacto < 3.0) {
    tipo = "SAQUE";
  } else if (giroZ_noImpacto > 0) {
    tipo = "FOREHAND";
  } else {
    tipo = "BACKHAND";
  }

  Serial.print("  => Tipo: ");
  Serial.println(tipo);
}

/*
  COMO CALIBRAR OS LIMIARES:

  1. Descomente as duas linhas de debug dentro do loop() (accelMag / giroMag).
  2. Abra o Monitor Serial e observe:
     - Com a raquete parada na mesa: accelMag deve ficar perto de 9.8, giroMag perto de 0.
     - Fazendo um gesto de preparação (girando o pulso) sem bater: veja até quanto giroMag sobe.
     - Fazendo uma "tacada" de verdade: veja o pico de accelMag no momento do impacto.
  3. Ajuste LIMIAR_GIRO_PREPARACAO e LIMIAR_ACEL_IMPACTO com base nesses valores reais
     (normalmente um pouco abaixo do pico observado, pra não perder golpes mais fracos,
     mas acima do "ruído" de quando está parado ou só andando com a raquete na mão).
  4. Recomente as linhas de debug depois de calibrar, pra não poluir a saída.
  5. Teste os 3 tipos de golpe (saque, forehand, backhand) várias vezes e confira se
     a classificação bate. Ajuste a regra em classificarTacada() se necessário --
     por exemplo, pode ser melhor usar o eixo X ou Y do giro em vez do Z, dependendo
     de como o sensor fica orientado quando fixado no punho da raquete.

  PRÓXIMO PASSO (depois que a classificação estiver satisfatória):
  Trocar os Serial.println() por envio via Bluetooth (BLE) pro app mobile,
  usando a biblioteca NimBLE-Arduino -- é o que a arquitetura do projeto define
  pra comunicação raquete -> app.
*/
