/*
  PASSO 2 (RECALIBRADO) — Máquina de estados: detectar e classificar a tacada

  Atualizado a partir da coleta de dados rotulados (6 amostras de cada tipo,
  sensor fixado rigidamente na ponta inferior do cabo). A regra de
  classificação mudou em relação à versão original:

  DESCOBERTA: com o sensor nessa posição, accZ e giroZ (usados na regra
  original) NÃO separam bem os golpes. Quem separa é:
    - accX  -> separa BACKHAND dos demais (backhand tem accX bem mais alto)
    - giroX -> dentro do que não é backhand, separa FOREHAND de SAQUE

  IMPORTANTE: essa regra foi calibrada com só 6 amostras por tipo. Antes de
  considerar definitiva, colete mais dados (10-15 de cada tipo, com
  intensidades variadas) e confira se os limiares ainda se sustentam,
  principalmente o limiar de giroX perto de zero (é onde forehand e saque
  mais se confundem nos dados atuais).

  Continua usando a mesma máquina de estados de sempre:

      PARADO --(giro sustentado)--> PREPARACAO --(pico de aceleração)--> IMPACTO
        ^                                                                   |
        |                                                                   v
        +-------------------------- RECUPERACAO <--------------------------+

  Só que agora, no cruzamento do limiar de impacto, o código abre uma janela
  curta (25ms) e guarda o PICO real de aceleração dentro dela — em vez de
  usar a primeira amostra que cruzou o limiar — pra reduzir ruído e evitar
  classificar com base num valor de transição.
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

// ---------- Limiares de transição de estado (sem mudança) ----------
const float LIMIAR_GIRO_PREPARACAO      = 1.5;   // rad/s
const float LIMIAR_ACEL_IMPACTO         = 20.0;  // m/s²
const float LIMIAR_ACEL_ESTAVEL         = 13.5;  // m/s²
const unsigned long TIMEOUT_PREPARACAO      = 1000; // ms
const unsigned long TEMPO_ESTAVEL_RECUPERACAO = 150; // ms
const unsigned long TIMEOUT_RECUPERACAO_SEG  = 2000; // ms
const unsigned long JANELA_PICO_MS           = 25;   // ms

// ---------- Limiares de CLASSIFICAÇÃO (novos, calibrados com dado real) ----------
// ⚠️ Calibrados com n=6 por classe — revisar com mais amostras.
const float LIMIAR_ACCX_BACKHAND = 15.0;  // acima disso -> BACKHAND

unsigned long marcaTempo = 0;
unsigned long tempoEstavelDesde = 0;

// Valores dos 6 eixos capturados no pico da janela de impacto
float accX_pico, accY_pico, accZ_pico;
float giroX_pico, giroY_pico, giroZ_pico;

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
  Serial.println("Máquina de estados pronta (regra de classificação recalibrada).");
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
        capturarJanelaDePico(accelMag);

        estadoAtual = IMPACTO;
        marcaTempo = agora;
        classificarTacada();
      } else if (agora - marcaTempo > TIMEOUT_PREPARACAO) {
        estadoAtual = PARADO;
        Serial.println(">> Cancelado (girou mas não impactou), voltando pro PARADO");
      }
      break;

    case IMPACTO:
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
        tempoEstavelDesde = 0;
      }

      if (agora - marcaTempo > TIMEOUT_RECUPERACAO_SEG) {
        estadoAtual = PARADO;
      }
      break;
  }

  delay(10);
}

// Guarda o pico real de aceleração (e os 6 eixos correspondentes) dentro de
// uma janela curta após o cruzamento do limiar, em vez de usar a primeira
// amostra que cruzou — reduz o efeito de ruído na leitura usada pra classificar.
void capturarJanelaDePico(float accelMagInicial) {
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  accX_pico = a.acceleration.x;
  accY_pico = a.acceleration.y;
  accZ_pico = a.acceleration.z;
  giroX_pico = g.gyro.x;
  giroY_pico = g.gyro.y;
  giroZ_pico = g.gyro.z;
  float picoAccelMag = accelMagInicial;

  unsigned long inicioJanela = millis();
  while (millis() - inicioJanela < JANELA_PICO_MS) {
    mpu.getEvent(&a, &g, &temp);
    float mag = sqrt(a.acceleration.x * a.acceleration.x +
                      a.acceleration.y * a.acceleration.y +
                      a.acceleration.z * a.acceleration.z);
    if (mag > picoAccelMag) {
      picoAccelMag = mag;
      accX_pico = a.acceleration.x;
      accY_pico = a.acceleration.y;
      accZ_pico = a.acceleration.z;
      giroX_pico = g.gyro.x;
      giroY_pico = g.gyro.y;
      giroZ_pico = g.gyro.z;
    }
  }
}

void classificarTacada() {
  Serial.print(">> TACADA DETECTADA!  accX=");
  Serial.print(accX_pico);
  Serial.print("  accZ=");
  Serial.print(accZ_pico);
  Serial.print("  giroX=");
  Serial.print(giroX_pico);

  // Regra recalibrada com dados reais (ver cabeçalho do arquivo):
  //  1) accX alto isola o BACKHAND (sem sobreposição nos dados coletados)
  //  2) dentro do que sobra, o sinal de giroX separa FOREHAND de SAQUE
  String tipo;
  if (accX_pico > LIMIAR_ACCX_BACKHAND) {
    tipo = "BACKHAND";
  } else if (giroX_pico > 0) {
    tipo = "SAQUE";
  } else {
    tipo = "FOREHAND";
  }

  Serial.print("  => Tipo: ");
  Serial.println(tipo);
}

/*
  PRÓXIMOS PASSOS:
  1. Coletar mais amostras (10-15 por tipo, com força variada) usando o
     sketch passo2b_coleta_calibracao.ino e conferir se os limiares
     (accX > 15.0, giroX > 0) continuam separando bem.
  2. Prestar atenção especial nas tacadas com giroX perto de zero — é a
     zona onde forehand e saque mais se confundiram nos dados atuais.
  3. Investigar a amostra de backhand com accX=117.77 (bem acima das
     outras) — golpe mais forte de propósito, ou possível ruído/artefato?
  4. Depois de validar, migrar Serial.println() para envio via BLE
     (NimBLE-Arduino), conforme o Passo 3 já planejado.
*/
