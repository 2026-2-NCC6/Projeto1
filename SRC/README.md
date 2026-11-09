# Entregas do PI
### **DECLARAÇÃO DE USO DE INTELIGÊNCIA ARTIFICIAL**

Este documento apresenta a utilização de Inteligência Artificial como ferramenta de apoio ao desenvolvimento do **Swing Sense**, projeto de uma raquete de tênis inteligente integrada a um aplicativo mobile e a uma API.

A ferramenta utilizada nos módulos descritos foi o **Claude**, com o modelo **Claude Opus 5.5**. A declaração está organizada por entrega e módulo do sistema, seguindo o formato de identificação, finalidade, prompts principais e trechos relacionados.

---

## Entrega 1

### Módulo do sistema 1 — Simulação do sensor e da máquina de estados no Wokwi

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Sistemas Embarcados e Robótica; Projeto Interdisciplinar — IoT e Robótica, Entrega 1 |
| **Finalidade de uso** | Apoio à compreensão e à estruturação do protótipo de leitura do sensor MPU6050 conectado ao ESP32-C3, incluindo a organização da lógica de detecção de movimento por máquina de estados e a análise dos critérios usados para identificar uma tacada. |
| **Prompts principais utilizados** | 1. “Considere um ESP32-C3 conectado a um sensor MPU6050 por I2C. Explique como organizar a leitura dos dados de aceleração e giroscópio para acompanhar o movimento de uma raquete, separando a aquisição dos dados da lógica de detecção.”<br>2. “Analise uma máquina de estados para detecção de tacadas com os estados PARADO, PREPARACAO, IMPACTO e RECUPERACAO. Descreva a responsabilidade de cada estado e os eventos que podem justificar a mudança entre eles.”<br>3. “Considerando que a classificação da tacada utiliza o eixo `accX`, explique como organizar os limiares e uma zona de incerteza para reduzir classificações precipitadas. Indique quais parâmetros devem ser avaliados durante a calibração do protótipo.” |
| **Trechos ou entregas afetadas** | `SRC/Circuito/Construcao_Wokwi_V1/` — simulação do protótipo do sensor e da lógica inicial de detecção. |

### Módulo do sistema 2 — Aplicativo mobile (estrutura e interface inicial)

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Projeto Interdisciplinar — IoT e Robótica, Entrega 1 |
| **Finalidade de uso** | Apoio à organização da estrutura inicial do aplicativo Swing Sense em Flutter, considerando a separação das telas, a navegação entre funcionalidades e o gerenciamento de estado. O suporte também envolveu a análise da consistência da interface entre as áreas principais do aplicativo. |
| **Prompts principais utilizados** | 1. “Considerando um aplicativo mobile em Flutter para acompanhar o desempenho de um jogador de tênis, proponha uma organização de telas para autenticação, dashboard, feed e comunidade, perfil, metas, treinos, sessão ao vivo, glossário e onboarding. Mantenha os componentes organizados e a navegação coerente com essas funcionalidades.”<br>2. “Analise o uso de Provider para gerenciar o estado de autenticação, feed e metas em um aplicativo Flutter. Explique como separar essas responsabilidades e evitar que a lógica de estado fique concentrada nas telas.”<br>3. “Revise a organização de uma interface de dashboard esportivo que apresenta estatísticas e histórico de atividades. Considere a clareza das informações e a separação entre apresentação visual e obtenção dos dados.” |
| **Trechos ou entregas afetadas** | `SRC/Swing Sense/swing_sense_frontend/` — estrutura do aplicativo Flutter, telas e gerenciamento de estado. Entre os componentes de estado documentados estão `auth_provider`, `feed_provider` e `goals_provider`. |

### Módulo do sistema 3 — Modelagem formal, descrição técnica e plano de riscos

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Teoria da Computação e Linguagens Formais; Projeto Interdisciplinar — IoT e Robótica; Redes de Computadores e Cibersegurança, Entrega 1 |
| **Finalidade de uso** | Apoio à organização e à revisão da modelagem formal da detecção de tacadas, da descrição técnica da solução IoT e da estruturação dos documentos de planejamento e gerenciamento de riscos do projeto. |
| **Prompts principais utilizados** | 1. “Modele o processo de detecção de tacadas como um autômato finito, considerando os estados PARADO, PREPARACAO, IMPACTO e RECUPERACAO. Organize a descrição dos estados, eventos e transições de modo que a modelagem possa ser comparada à lógica implementada no firmware.”<br>2. “Com base na proposta de uma raquete inteligente com MPU6050 e ESP32-C3, ajude a estruturar a descrição técnica do sistema, apresentando o papel de cada componente e o fluxo de dados entre a raquete, o aplicativo e os serviços de backend.”<br>3. “Ajude a organizar um plano de gerenciamento de riscos para um projeto de IoT que depende da leitura de sensores, comunicação Bluetooth Low Energy, aplicativo mobile e API. Separe identificação, análise, resposta e acompanhamento dos riscos, sem presumir que riscos ainda não verificados já ocorreram.” |
| **Trechos ou entregas afetadas** | Documentos acadêmicos da `Documentos/Entrega 1/`, relacionados às disciplinas de Teoria da Computação e Linguagens Formais, Projeto Interdisciplinar — IoT e Robótica e Redes de Computadores e Cibersegurança. |

---

## Entrega 2

### Módulo do sistema 1 — Aplicativo mobile e integração com a raquete e a API

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Projeto Interdisciplinar — IoT e Robótica; Redes de Computadores e Cibersegurança, Entrega 2 |
| **Finalidade de uso** | Apoio à revisão da integração do aplicativo Flutter com as fontes de dados da raquete e com a API. O escopo inclui a separação entre a implementação BLE e a implementação simulada, além da análise do fluxo de armazenamento local e sincronização das tacadas com o backend. |
| **Prompts principais utilizados** | 1. “Analise uma interface `RacketSource` em Flutter com duas implementações: uma para comunicação com a raquete por BLE e outra para simulação. Verifique se a tela de sessão pode utilizar a abstração sem depender diretamente de uma implementação específica.”<br>2. “Revise o fluxo de uma fila local de tacadas que realiza o envio em lote para `POST /tacadas`. Considere indisponibilidade de rede, tentativas posteriores de sincronização e a necessidade de evitar duplicidade durante o reenvio.”<br>3. “Considere um aplicativo Flutter que utiliza Provider e se comunica com uma API protegida. Analise a separação entre autenticação, estado das funcionalidades e serviço de sincronização, indicando pontos que merecem testes de integração.” |
| **Trechos ou entregas afetadas** | `SRC/Swing Sense/swing_sense_frontend/`, incluindo a interface `RacketSource`, as implementações `BleRacketService` e `MockRacketService` e o serviço `tacada_sync_service`. |

### Módulo do sistema 2 — API e persistência de dados

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Projeto Interdisciplinar — IoT e Robótica; Redes de Computadores e Cibersegurança, Entrega 2 |
| **Finalidade de uso** | Apoio à análise da estrutura da API em Dart, da organização das rotas, dos mecanismos de autenticação e segurança e da persistência dos dados no PostgreSQL integrado ao Supabase. Também foi considerado o fluxo de recebimento de tacadas em lote e os cuidados necessários para o tratamento de reenvios. |
| **Prompts principais utilizados** | 1. “Analise a estrutura de uma API desenvolvida em Dart com `shelf` e `shelf_router`, considerando a separação das rotas de autenticação, usuários, feed, treinos, sessões, metas, dispositivos, tacadas, dashboard e glossário.”<br>2. “Revise um pipeline de requisições que utiliza middlewares para registro, cabeçalhos de segurança, CORS com allowlist, tratamento de erros e autenticação JWT. Aponte responsabilidades de cada etapa e cenários que devem ser cobertos por testes.”<br>3. “Considere um endpoint `POST /tacadas` que recebe lotes de até 500 registros. Analise a estratégia de idempotência baseada em `(dispositivo_id, boot, seq)` e proponha casos de teste para validar o comportamento diante de reenvios e registros repetidos.” |
| **Trechos ou entregas afetadas** | `SRC/Swing Sense/swing_sense_backend/`, incluindo as rotas da API, `schema.sql`, as migrations `001_tacadas.sql` e `002_tacadas_estatisticas.sql` e os testes de dashboard, segurança e tacadas. |

### Módulo do sistema 3 — Firmware da raquete e comunicação BLE

| **Campo** | **Descrição** |
| :--- | :--- |
| **Aluno(s) Responsável(veis)** | Grupo 1: Antônio Petri de Moraes Soares de Moura e Oliveira, Gabriel Higobassi Paschoal, Lucas Silva Maciel e Thiago Akira Higa Mitami |
| **Ferramenta utilizada** | Claude |
| **Versão/modelo** | Claude Opus 5.5 |
| **Disciplina / Trabalho** | Sistemas Embarcados e Robótica; Projeto Interdisciplinar — IoT e Robótica, Entrega 2 |
| **Finalidade de uso** | Apoio à análise da evolução do firmware para comunicação Bluetooth Low Energy com o aplicativo, considerando a leitura do MPU6050, a identificação de tacadas e a organização das mensagens transmitidas por notificação BLE. |
| **Prompts principais utilizados** | 1. “Considere o firmware de um ESP32-C3 conectado ao MPU6050. Revise a sequência de leitura do sensor e a máquina de estados PARADO, PREPARACAO, IMPACTO e RECUPERACAO, verificando se a classificação da tacada está coerente com os dados processados.”<br>2. “Analise a comunicação BLE entre o ESP32-C3 e um aplicativo mobile. Considere um serviço com característica de notificação e o envio de cada tacada em formato JSON. Aponte cuidados para manter os identificadores e os campos da mensagem consistentes entre dispositivo e aplicativo.”<br>3. “Revise o tratamento dos campos enviados na mensagem de tacada. Considere que o campo `bola` ainda não possui detecção implementada e deve permanecer representado como `null`, sem indicar que o contato com a bola já é identificado pelo sistema.” |
| **Trechos ou entregas afetadas** | `SRC/Circuito/Prototipo_v3/passo3_ble_tacada.ino` e `SRC/Circuito/Prototipo_v3/ble_tacada.h`. O protótipo utiliza o serviço BLE identificado pelo UUID `5f650a50-3eba-436c-b9d7-5beb09160c55` e a característica `efae8d7d-880d-40d4-9a82-bc63cf7a3d81`. |

---

## Declaração de responsabilidade

***Declaramos que o uso da ferramenta de Inteligência Artificial foi realizado como apoio ao desenvolvimento do projeto, buscando observar o GUIA PARA O USO RESPONSÁVEL DE INTELIGÊNCIA ARTIFICIAL NA FECAP, e que o conteúdo final, as decisões técnicas e a validação das entregas são de responsabilidade autoral dos integrantes do grupo.***
