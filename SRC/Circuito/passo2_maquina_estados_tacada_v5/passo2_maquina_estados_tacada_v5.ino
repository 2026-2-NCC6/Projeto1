/*
  PASSO 2 (v5) — Forehand x Backhand + FORCA pelo PICO REAL

  ============================================================
  O QUE MUDOU EM RELACAO A v4
  ============================================================
  1) FORCA ERA MEDIDA NO INSTANTE ERRADO
     A v4 reportava o accelMag da PRIMEIRA leitura acima de 20 m/s2, ou
     seja, o inicio da deteccao. Esse valor sempre fica logo acima de 20,
     por isso a "forca" parecia sempre igual. Nos dados gravados:
        forca reportada: 20.5 a 33.5 m/s2
        pico real:       50.8 a 96.4 m/s2  (~100 ms depois)
     Agora o codigo rastreia o PICO durante todo o golpe (impacto +
     recuperacao) e so reporta quando a tacada termina.

  2) GIROSCOPIO SATURANDO
     Com faixa de +-500 graus/s (8.73 rad/s), todos os golpes gravados
     bateram no teto varias vezes (leituras travadas em -8.731). Faixa
     aumentada para +-2000 graus/s (34.9 rad/s). Nao afeta a classificacao
     (que usa o acelerometro) nem o gatilho de preparacao (1.5 rad/s).

  3) VELOCIDADE ESTIMADA DA RAQUETE
     velocidade = pico de velocidade angular x RAIO_EFETIVO_M
     RAIO_EFETIVO_M e a distancia aproximada do eixo de rotacao (pulso)
     ate o centro das cordas. E uma ESTIMATIVA: o giro real combina
     pulso, cotovelo e ombro. Serve pra comparar golpes entre si, nao
     como medicao absoluta. Documentar assim no relatorio.

  Classificacao: igual a v4 (janela fixa pre-impacto, accX > 14 = BH).
  Saque nao e classificado (aparece como FOREHAND).
*/

#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>

Adafruit_MPU6050 mpu;

enum EstadoTacada { PARADO, PREPARACAO, IMPACTO, RECUPERACAO };
EstadoTacada estadoAtual = PARADO;

// ---------- Limiares de transicao de estado ----------
const float LIMIAR_GIRO_PREPARACAO           = 1.5;   // rad/s
const float LIMIAR_ACEL_IMPACTO             = 20.0;  // m/s2
const float LIMIAR_ACEL_ESTAVEL             = 13.5;  // m/s2
const unsigned long TIMEOUT_PREPARACAO        = 1000; // ms
const unsigned long TEMPO_ESTAVEL_RECUPERACAO = 150;  // ms
const unsigned long TIMEOUT_RECUPERACAO_SEG   = 2000; // ms

// ---------- Classificacao ----------
const float LIMIAR_ACCX_BACKHAND = 14.0;
const float ZONA_INCERTA         = 4.0;

// ---------- Forca / velocidade ----------
const float RAIO_EFETIVO_M = 0.6;  // pulso -> centro das cordas (ajuste se quiser)

// ---------- Buffer circular (classificacao) ----------
const int TAM_BUFFER      = 16;
const int JANELA_AMOSTRAS = 5;

float bufferAccX[TAM_BUFFER];
int   posBuffer = 0;
int   amostrasNoBuffer = 0;

unsigned long marcaTempo = 0;
unsigned long tempoEstavelDesde = 0;

// Dados da tacada em andamento
String tipoAtual = "";
float  accX_janelaAtual = 0;
float  picoAccelMag = 0;
float  picoGiroMag  = 0;

int contForehand = 0;
int contBackhand = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  Serial.println("Iniciando MPU6050...");
  if (!mpu.begin()) {
    Serial.println("ERRO: nao encontrou o MPU6050. Confira os fios!");
    while (1) delay(10);
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
  mpu.setGyroRange(MPU6050_RANGE_2000_DEG);   // era 500: saturava nos golpes
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  delay(100);
  Serial.println("Pronto: FOREHAND x BACKHAND + forca pelo pico real.\n");
}

void guardarNoBuffer(float valor) {
  bufferAccX[posBuffer] = valor;
  posBuffer = (posBuffer + 1) % TAM_BUFFER;
  if (amostrasNoBuffer < TAM_BUFFER) amostrasNoBuffer++;
}

float mediaUltimas(int n) {
  if (n > amostrasNoBuffer) n = amostrasNoBuffer;
  if (n == 0) return 0;
  float soma = 0;
  for (int i = 1; i <= n; i++) {
    int idx = (posBuffer - i + TAM_BUFFER) % TAM_BUFFER;
    soma += bufferAccX[idx];
  }
  return soma / n;
}

void loop() {
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  guardarNoBuffer(a.acceleration.x);

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
        picoAccelMag = 0;
        picoGiroMag  = 0;
      }
      break;

    case PREPARACAO:
      // o giro maximo pode acontecer ainda na aceleracao da raquete
      if (giroMag > picoGiroMag) picoGiroMag = giroMag;

      if (accelMag > LIMIAR_ACEL_IMPACTO) {
        if (accelMag > picoAccelMag) picoAccelMag = accelMag;
        classificarNoImpacto();
        estadoAtual = IMPACTO;
        marcaTempo = agora;
      } else if (agora - marcaTempo > TIMEOUT_PREPARACAO) {
        estadoAtual = PARADO;
      }
      break;

    case IMPACTO:
      if (accelMag > picoAccelMag) picoAccelMag = accelMag;
      if (giroMag  > picoGiroMag)  picoGiroMag  = giroMag;
      estadoAtual = RECUPERACAO;
      marcaTempo = agora;
      tempoEstavelDesde = 0;
      break;

    case RECUPERACAO:
      // continua rastreando: o pico real vem ~100 ms depois do cruzamento
      if (accelMag > picoAccelMag) picoAccelMag = accelMag;
      if (giroMag  > picoGiroMag)  picoGiroMag  = giroMag;

      if (accelMag < LIMIAR_ACEL_ESTAVEL) {
        if (tempoEstavelDesde == 0) {
          tempoEstavelDesde = agora;
        } else if (agora - tempoEstavelDesde > TEMPO_ESTAVEL_RECUPERACAO) {
          reportarTacada();
          estadoAtual = PARADO;
        }
      } else {
        tempoEstavelDesde = 0;
      }

      if (agora - marcaTempo > TIMEOUT_RECUPERACAO_SEG) {
        reportarTacada();
        estadoAtual = PARADO;
      }
      break;
  }

  delay(10);  // ~100 Hz
}

// Classificacao continua no impacto (janela pre-impacto do buffer)
void classificarNoImpacto() {
  accX_janelaAtual = mediaUltimas(JANELA_AMOSTRAS);
  if (accX_janelaAtual > LIMIAR_ACCX_BACKHAND) {
    tipoAtual = "BACKHAND";
    contBackhand++;
  } else {
    tipoAtual = "FOREHAND";
    contForehand++;
  }
}

// Forca so e reportada quando o golpe termina, com o pico completo
void reportarTacada() {
  float velRaquete_ms  = picoGiroMag * RAIO_EFETIVO_M;
  float velRaquete_kmh = velRaquete_ms * 3.6;
  float picoG = picoAccelMag / 9.81;

  Serial.print(">> ");
  Serial.print(tipoAtual);
  Serial.print("   accX_janela=");
  Serial.print(accX_janelaAtual, 2);
  if (fabs(accX_janelaAtual - LIMIAR_ACCX_BACKHAND) < ZONA_INCERTA) {
    Serial.print(" (perto do limiar)");
  }
  Serial.println();

  Serial.print("   pico acel: ");
  Serial.print(picoAccelMag, 1);
  Serial.print(" m/s2 (");
  Serial.print(picoG, 1);
  Serial.print(" g)   pico giro: ");
  Serial.print(picoGiroMag, 1);
  Serial.print(" rad/s   vel. estimada: ~");
  Serial.print(velRaquete_kmh, 0);
  Serial.println(" km/h");

  Serial.print("   total -> forehand: ");
  Serial.print(contForehand);
  Serial.print(" | backhand: ");
  Serial.println(contBackhand);
  Serial.println();
}

/*
  ============================================================
  COMO VALIDAR A FORCA
  ============================================================
  1. Faca 3 golpes BEM fracos, 3 medios e 3 fortes (mesmo tipo de golpe).
  2. Os tres grupos devem aparecer claramente separados em pico giro e
     vel. estimada. Se separarem, a metrica funciona.
  3. Se o pico giro chegar perto de 34.9 rad/s, o giroscopio saturou de
     novo (improvavel com 2000 graus/s, mas vale conferir).
  4. Se quiser calibrar RAIO_EFETIVO_M: com um radar de velocidade ou
     video em camera lenta, compare a velocidade real com a estimada.
*/
