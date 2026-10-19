import '../animation/drills.dart';
import '../models/guided_training.dart';

/// Catalogo de treinos pre-prontos (conteudo local, sem depender da API).
class GuidedTrainings {
  GuidedTrainings._();

  // ----------------------------------------------------------------------
  // Exercicios
  // ----------------------------------------------------------------------

  static final _forehandCross = GuidedExercise(
    name: 'Forehand cruzado',
    summary: 'O golpe mais usado no tenis: a bola vai na diagonal, passando pela parte mais baixa da rede '
        'e pela maior distancia da quadra. E o melhor ponto de partida para ganhar controle e confianca.',
    animation: Drills.forehandCross,
    prescription: '3 series de 10 bolas',
    goal: 'Mire no circulo verde, no canto oposto da quadra adversaria (diagonal).',
    steps: [
      'Fique em posicao de espera: pes afastados, joelhos flexionados e raquete a frente, apoiada pela mao livre.',
      'Assim que ver a bola vir para o seu lado direito, gire ombros e quadril e leve a raquete para tras.',
      'Transfira o peso para a perna da frente enquanto a raquete desce e vem para a frente.',
      'Bata na bola a frente do corpo, na altura da cintura, com o braco relaxado e o pulso firme.',
      'Finalize alto, com a raquete passando sobre o ombro oposto, e volte rapido a posicao de espera.',
    ],
    tips: [
      'Olhe para a bola ate o instante do contato.',
      'Deixe a bola quicar e bata quando ela estiver subindo ou no topo do quique.',
      'Use a rotacao do corpo, nao so o braco: a forca vem das pernas e do quadril.',
    ],
    mistakes: [
      'Bater com o corpo parado, so com o braco.',
      'Contato atrasado, ao lado ou atras do corpo.',
      'Parar o movimento logo apos a bola: a finalizacao curta tira controle.',
    ],
  );

  static final _forehandLine = GuidedExercise(
    name: 'Forehand na paralela',
    summary: 'A bola corre ao longo da linha lateral. E um golpe de mudanca de direcao: bom para surpreender, '
        'mas com menos margem de erro porque a quadra e mais estreita.',
    animation: Drills.forehandLine,
    prescription: '3 series de 8 bolas',
    goal: 'Mire no circulo verde proximo a linha lateral do fundo da quadra.',
    steps: [
      'Comece na posicao de espera e leia cedo a bola que vem em direcao ao seu forehand.',
      'Prepare a raquete atras, com o ombro de tras fechado.',
      'Para ir na paralela, contate a bola um pouco mais cedo e mais a frente do que no cruzado.',
      'Empurre a raquete na direcao da linha lateral, com a face da raquete apontando para o alvo.',
      'Finalize na direcao do alvo e recupere o centro da quadra.',
    ],
    tips: [
      'Escolha uma margem de seguranca: mire 1 metro para dentro da linha.',
      'Contato mais cedo = bola mais para a paralela; contato tarde = bola cruzada.',
      'Depois da paralela, volte rapido ao centro: a resposta pode vir cruzada.',
    ],
    mistakes: [
      'Mirar colado na linha e errar para fora.',
      'Contato atrasado, que joga a bola para o lado errado.',
      'Ficar parado vendo a bola em vez de recuperar a posicao.',
    ],
  );

  static final _backhandCross = GuidedExercise(
    name: 'Backhand de duas maos cruzado',
    summary: 'Com as duas maos na raquete, o backhand ganha estabilidade e forca. A mao dominante conduz o golpe '
        'e a outra ajuda na direcao e na potencia.',
    animation: Drills.backhandCross,
    prescription: '3 series de 10 bolas',
    goal: 'Mire no circulo verde, no canto oposto da quadra adversaria (diagonal).',
    steps: [
      'Na espera, segure a raquete com as duas maos: a dominante na base do cabo e a outra logo acima.',
      'Gire os ombros ate o ombro de tras apontar para a bola, levando a raquete para tras com as duas maos.',
      'Flexione os joelhos e transfira o peso para a perna da frente.',
      'Contate a bola a frente do corpo, com os bracos estendidos e a cabeca estavel.',
      'Finalize sobre o ombro oposto, mantendo as duas maos na raquete ate o fim do movimento.',
    ],
    tips: [
      'Mantenha a mao de baixo firme: ela controla a direcao.',
      'Afaste-se um pouco mais da bola do que no forehand para ter espaco para estender os bracos.',
      'Respire na preparacao e expire no contato para manter o corpo relaxado.',
    ],
    mistakes: [
      'Soltar a mao de cima cedo demais.',
      'Ficar muito perto da bola e bater com os bracos encolhidos.',
      'Levantar a cabeca antes de terminar o golpe.',
    ],
  );

  static final _backhandLine = GuidedExercise(
    name: 'Backhand na paralela',
    summary: 'O mesmo golpe do backhand, agora indo reto pela lateral. Treina o controle de direcao e a '
        'capacidade de acelerar a bola sem perder a tecnica.',
    animation: Drills.backhandLine,
    prescription: '3 series de 8 bolas',
    goal: 'Mire no circulo verde perto da linha lateral do fundo da quadra.',
    steps: [
      'Posicione-se de lado para a bola, com o ombro de tras apontando para ela.',
      'Prepare a raquete atras com as duas maos e flexione os joelhos.',
      'Contate a bola mais cedo que no cruzado, com a face da raquete voltada para a paralela.',
      'Estenda os bracos em direcao ao alvo e acompanhe a bola com a raquete.',
      'Finalize e volte ao centro da quadra.',
    ],
    tips: [
      'Imagine empurrar a bola ao longo de uma linha reta ate o alvo.',
      'Mantenha o tronco estavel no contato.',
      'Pratique devagar primeiro: precisao antes de velocidade.',
    ],
    mistakes: [
      'Girar o corpo antes do contato e abrir a face da raquete.',
      'Bater com o cotovelo dobrado.',
      'Esquecer de recuperar a posicao.',
    ],
  );

  static final _lob = GuidedExercise(
    name: 'Lob defensivo',
    summary: 'Bola alta e profunda, por cima do adversario. E o golpe para sair de uma situacao dificil: ganha '
        'tempo para voce voltar ao centro e empurra o rival para o fundo.',
    animation: Drills.lob,
    prescription: '3 series de 8 bolas',
    goal: 'Mire no circulo grande no fundo da quadra, bem proximo da linha de fundo.',
    steps: [
      'Prepare a raquete um pouco mais baixa do que nos golpes normais.',
      'Abra levemente a face da raquete, apontando-a para o alto.',
      'Contate a bola com um movimento de baixo para cima, com os joelhos ajudando a subir.',
      'Finalize alto, bem acima da cabeca, para dar altura a bola.',
      'Volte para o centro da quadra enquanto a bola esta no ar.',
    ],
    tips: [
      'Altura e profundidade: a bola precisa passar bem acima do rival e cair perto da linha de fundo.',
      'Use o lob quando estiver em desvantagem ou quando o rival estiver colado na rede.',
      'Nao tenha pressa: o lob ganha tempo, aproveite.',
    ],
    mistakes: [
      'Bater a bola curta, que o rival transforma em smash.',
      'Fechar a face da raquete e mandar a bola na rede.',
      'Esquecer a finalizacao alta.',
    ],
  );

  static final _serveDeuce = GuidedExercise(
    name: 'Saque pela direita',
    summary: 'O saque e o unico golpe que so depende de voce. Aprenda a sequencia completa: postura, lancamento, '
        'posicao de trofeu, contato no ponto mais alto e finalizacao.',
    animation: Drills.serveDeuce,
    prescription: '4 series de 6 saques',
    goal: 'Acerte a caixa de saque verde, na diagonal oposta (do lado esquerdo da quadra adversaria).',
    steps: [
      'Posicione-se atras da linha de fundo, de lado para a rede, com os pes na largura dos ombros.',
      'Lance a bola com a mao livre, reta para cima, na altura do braco totalmente esticado.',
      'Flexione os joelhos e leve a raquete para tras: o cotovelo fica alto, na posicao de trofeu.',
      'Estenda pernas e braco para cima e acerte a bola no ponto mais alto possivel.',
      'Finalize cruzando o corpo, com a raquete terminando do lado oposto, e entre na quadra.',
    ],
    tips: [
      'Lance a bola e deixe-a subir: um bom lancamento resolve metade do saque.',
      'Relaxe o pulso: a velocidade vem da cadeia pernas, tronco e braco.',
      'Crie uma rotina antes de cada saque (quicar a bola, respirar, mirar).',
    ],
    mistakes: [
      'Lancar a bola atras ou muito a frente da cabeca.',
      'Bater com o braco dobrado, longe do ponto mais alto.',
      'Ficar sem flexionar as pernas.',
    ],
  );

  static final _serveAd = GuidedExercise(
    name: 'Saque pela esquerda',
    summary: 'A mesma tecnica, agora saindo do lado esquerdo da quadra. O saque cruza para a caixa da direita do '
        'adversario, e o angulo muda: o lancamento e o ponto de contato fazem a diferenca.',
    animation: Drills.serveAd,
    prescription: '4 series de 6 saques',
    goal: 'Acerte a caixa de saque verde, na diagonal oposta (do lado direito da quadra adversaria).',
    steps: [
      'Posicione-se do lado esquerdo da linha de fundo, proximo a marca central, de lado para a rede.',
      'Lance a bola reta para cima, um pouco mais a direita do que no saque pela direita.',
      'Leve a raquete para tras na posicao de trofeu, com o cotovelo alto e os joelhos flexionados.',
      'Suba com as pernas e acerte a bola no ponto mais alto, com o braco totalmente esticado.',
      'Finalize cruzando o corpo e prepare-se para a devolucao.',
    ],
    tips: [
      'Teste mirar no T (proximo a linha central) e no canto: varie para o rival nao se acostumar.',
      'Mantenha o lancamento consistente: so o golpe muda, nao a rotina.',
      'Observe onde sua bola cai para ajustar a mira.',
    ],
    mistakes: [
      'Mudar o lancamento a cada saque.',
      'Abrir o corpo cedo demais.',
      'Nao completar a finalizacao.',
    ],
  );

  static final _volleyForehand = GuidedExercise(
    name: 'Voleio de forehand',
    summary: 'Bater a bola no ar, perto da rede, sem deixar quicar. O voleio e um golpe curto e firme: pouca '
        'preparacao e muito controle.',
    animation: Drills.volleyForehand,
    prescription: '3 series de 12 bolas',
    goal: 'Direcione a bola para o circulo verde no fundo da quadra adversaria, longe do rival.',
    steps: [
      'Fique a cerca de 2 metros da rede, com a raquete a frente da cabeca e o cotovelo na frente do corpo.',
      'Faca um backswing curto: so o ombro gira, a raquete quase nao vai atras.',
      'De um passo para a bola com a perna oposta e toque nela a frente do corpo.',
      'Mantenha o pulso firme e empurre a bola na direcao do alvo, sem balanco longo.',
      'Termine a raquete a frente e volte imediatamente a posicao de espera.',
    ],
    tips: [
      'Quanto mais perto da rede, menor o movimento.',
      'Mantenha a cabeca da raquete acima do nivel da mao.',
      'Pense em "bloquear" a bola, nao em bater.',
    ],
    mistakes: [
      'Fazer um backswing grande, como num golpe de fundo.',
      'Deixar o pulso mole e a raquete cair.',
      'Voltar para tras em vez de ficar na rede.',
    ],
  );

  static final _volleyBackhand = GuidedExercise(
    name: 'Voleio de backhand',
    summary: 'O voleio do lado esquerdo exige o mesmo toque curto e firme. E um golpe essencial para fechar o '
        'ponto na rede com seguranca.',
    animation: Drills.volleyBackhand,
    prescription: '3 series de 12 bolas',
    goal: 'Direcione a bola para o circulo verde, no fundo da quadra adversaria.',
    steps: [
      'Fique pronto na rede, com a raquete a frente e os joelhos flexionados.',
      'Gire o ombro de tras ate apontar para a bola; a raquete vai pouco atras.',
      'De um passo na direcao da bola e toque a frente do corpo, com o pulso firme.',
      'Empurre a bola na direcao do alvo com um movimento curto.',
      'Recupere a posicao de espera sem perder o equilibrio.',
    ],
    tips: [
      'A mao livre ajuda a equilibrar na preparacao.',
      'Mantenha o cotovelo a frente do corpo.',
      'Olhe a bola ate o toque.',
    ],
    mistakes: [
      'Contato atras do corpo.',
      'Girar o corpo todo em vez de so o ombro.',
      'Segurar a raquete frouxa demais.',
    ],
  );

  static final _smash = GuidedExercise(
    name: 'Smash (bola alta)',
    summary: 'Resposta ao lob do adversario: uma "cortada" por cima da cabeca, parecida com um saque, para '
        'finalizar o ponto.',
    animation: Drills.smash,
    prescription: '3 series de 8 bolas',
    goal: 'Direcione a bola para o circulo verde no fundo da quadra adversaria, bem aberto.',
    steps: [
      'Ao ver o lob, vire de lado e deslize para tras com passos laterais, mantendo a bola a sua frente.',
      'Aponte a mao livre para a bola e leve a raquete para tras, na posicao de trofeu.',
      'Estenda o braco para cima e acerte a bola no ponto mais alto, a frente da cabeca.',
      'Estale o pulso na hora do contato para descer a bola com forca e direcao.',
      'Finalize cruzando o corpo e volte a posicao de rede.',
    ],
    tips: [
      'Os pes primeiro: o smash se ganha com a movimentacao, nao com o braco.',
      'Se a bola passar da sua cabeca, deixe quicar e jogue um lob.',
      'Nao precisa de forca maxima: precisao ganha mais pontos.',
    ],
    mistakes: [
      'Ficar embaixo da bola, sem espaco para estender o braco.',
      'Esquecer de apontar com a mao livre.',
      'Bater com o braco dobrado.',
    ],
  );

  // ----------------------------------------------------------------------
  // Treinos
  // ----------------------------------------------------------------------

  static final List<GuidedTraining> all = [
    GuidedTraining(
      id: 'guided-fundo-de-quadra',
      title: 'Fundo de quadra: forehand e backhand',
      subtitle: 'Os golpes de base, na diagonal e na paralela',
      description: 'Treino essencial para quem esta comecando. Voce vai praticar os quatro golpes de fundo de '
          'quadra mais usados: forehand e backhand, cruzados e na paralela. Cada exercicio tem uma animacao '
          'na quadra mostrando onde a bola deve cair.',
      difficulty: 'iniciante',
      durationMinutes: 25,
      focus: 'Golpes de base',
      coverColor: '1DB954',
      benefits: [
        'Constroi a base tecnica dos golpes de fundo.',
        'Treina a mira e o controle da direcao da bola.',
        'Melhora a posicao de espera e o jogo de pernas.',
      ],
      exercises: [_forehandCross, _backhandCross, _forehandLine, _backhandLine],
    ),
    GuidedTraining(
      id: 'guided-saque',
      title: 'Saque do zero',
      subtitle: 'Postura, lancamento, trofeu e contato',
      description: 'O saque e o golpe que abre o ponto. Aqui voce aprende a sequencia completa, passo a passo, '
          'e treina os dois lados da quadra mirando na caixa de saque correta.',
      difficulty: 'iniciante',
      durationMinutes: 20,
      focus: 'Saque',
      coverColor: '1ED760',
      benefits: [
        'Cria uma rotina de saque consistente.',
        'Treina o lancamento, a parte mais importante do golpe.',
        'Ensina a mirar nas duas caixas de saque.',
      ],
      exercises: [_serveDeuce, _serveAd],
    ),
    GuidedTraining(
      id: 'guided-rede',
      title: 'Jogo de rede',
      subtitle: 'Voleios e smash para fechar o ponto',
      description: 'Subir a rede e finalizar o ponto exige toque, reflexo e decisao. Neste treino voce pratica '
          'os dois voleios e o smash, que e a resposta ao lob do adversario.',
      difficulty: 'intermediario',
      durationMinutes: 20,
      focus: 'Rede',
      coverColor: '169C46',
      benefits: [
        'Melhora reflexos e toque perto da rede.',
        'Treina decisoes rapidas de direcao.',
        'Aumenta a eficiencia para finalizar pontos.',
      ],
      exercises: [_volleyForehand, _volleyBackhand, _smash],
    ),
    GuidedTraining(
      id: 'guided-profundidade-defesa',
      title: 'Profundidade e defesa',
      subtitle: 'Bolas fundas, paralelas e o lob',
      description: 'Jogar profundo mantem o adversario longe da rede, e saber se defender evita perder pontos. '
          'Treino de nivel intermediario com paralelas e lob defensivo.',
      difficulty: 'intermediario',
      durationMinutes: 25,
      focus: 'Consistencia',
      coverColor: '2ECC71',
      benefits: [
        'Ganha controle da profundidade da bola.',
        'Aprende a sair de situacoes dificeis com o lob.',
        'Melhora a tomada de decisao entre cruzar e ir na paralela.',
      ],
      exercises: [_forehandLine, _backhandLine, _lob],
    ),
    GuidedTraining(
      id: 'guided-completo',
      title: 'Treino completo de 45 minutos',
      subtitle: 'Uma sessao de jogo, do fundo a rede',
      description: 'Uma rotina completa para o dia a dia: aquecimento nos golpes de base, saque, rede e defesa. '
          'Ideal para quem ja conhece os fundamentos e quer treinar de forma organizada.',
      difficulty: 'avancado',
      durationMinutes: 45,
      focus: 'Treino completo',
      coverColor: '1DB954',
      benefits: [
        'Cobre todas as situacoes de jogo em uma unica sessao.',
        'Cria o habito de treinar com metas claras.',
        'Funciona como base para registrar o treino com a raquete.',
      ],
      exercises: [_forehandCross, _backhandCross, _serveDeuce, _volleyForehand, _smash, _lob],
    ),
  ];
}
