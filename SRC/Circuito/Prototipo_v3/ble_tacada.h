/*
  ble_tacada.h — envio das tacadas por BLE (contrato: docs/CONTRATO_BLE.md)

  Usa a biblioteca BLE que ja vem no core ESP32 (3.x); nao precisa instalar nada.
  O ESP32-C3 so tem BLE (nao tem Bluetooth Classico / BluetoothSerial).

  Interface usada pelo .ino:
    bleIniciar(nome)        -> cria servico/caracteristica e comeca a anunciar
    bleEnviarTacada(json)   -> manda uma tacada, se houver celular conectado
*/

#pragma once

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

#define UUID_SERVICO_SWINGSENSE "5f650a50-3eba-436c-b9d7-5beb09160c55"
#define UUID_CARAC_TACADA       "efae8d7d-880d-40d4-9a82-bc63cf7a3d81"

static BLEServer*         bleServidor    = nullptr;
static BLECharacteristic* bleCaracTacada = nullptr;
static volatile bool      bleConectado   = false;

class SwingSenseCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* servidor) override {
    bleConectado = true;
    Serial.println("BLE: celular conectado");
  }

  void onDisconnect(BLEServer* servidor) override {
    bleConectado = false;
    Serial.println("BLE: celular desconectado, anunciando de novo");
    servidor->startAdvertising();
  }
};

void bleIniciar(const char* nome) {
  BLEDevice::init(nome);

  bleServidor = BLEDevice::createServer();
  bleServidor->setCallbacks(new SwingSenseCallbacks());

  BLEService* servico = bleServidor->createService(UUID_SERVICO_SWINGSENSE);
  bleCaracTacada = servico->createCharacteristic(
    UUID_CARAC_TACADA, BLECharacteristic::PROPERTY_NOTIFY);

#if defined(CONFIG_BLUEDROID_ENABLED)
  // descritor 0x2902 (liga/desliga notificacoes); o NimBLE cria sozinho
  bleCaracTacada->addDescriptor(new BLE2902());
#endif

  servico->start();

  BLEAdvertising* anuncio = BLEDevice::getAdvertising();
  anuncio->addServiceUUID(UUID_SERVICO_SWINGSENSE);
  // UUID de 128 bits + nome nao cabem juntos no anuncio (31 bytes):
  // o nome vai na resposta de scan
  anuncio->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void bleEnviarTacada(const char* json) {
  if (!bleConectado || bleServidor == nullptr) return;

  // payload de uma notificacao = MTU - 3 bytes de cabecalho ATT
  size_t tamanho = strlen(json);
  uint16_t mtu = bleServidor->getPeerMTU(bleServidor->getConnId());
  if (tamanho > (size_t)(mtu - 3)) {
    Serial.print("AVISO BLE: MTU pequeno (");
    Serial.print(mtu);
    Serial.print(") para JSON de ");
    Serial.print(tamanho);
    Serial.println(" bytes. O app deve pedir MTU >= 185. Tacada nao enviada.");
    return;
  }

  // so chega ao celular se ele ativou as notificacoes da caracteristica
  bleCaracTacada->setValue((uint8_t*)json, tamanho);
  bleCaracTacada->notify();
}
