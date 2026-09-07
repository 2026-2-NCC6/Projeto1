import 'dart:math';

import '../utils/password_util.dart';
import 'memory_store.dart';

/// Wrapper fino sobre o [MemoryStore]. Existia aqui uma conexao real com
/// PostgreSQL; para simplificar a demo (sem Docker, sem instalar banco), a
/// API passou a guardar tudo em memoria - a interface (`Database.connect()`,
/// `database.store`) foi mantida igual de proposito, entao trocar por um
/// banco de verdade no futuro significa mexer só aqui, nao nas rotas.
class Database {
  Database._(this.store);

  final MemoryStore store;

  static Future<Database> connect() async {
    final store = MemoryStore();
    _seedDemoData(store);
    return Database._(store);
  }

  Future<void> close() async {}
}

final _random = Random();

/// Popula o [MemoryStore] com os mesmos dados de demonstracao que antes
/// vinham de `bin/seed.dart` (que rodava contra um Postgres externo). Como
/// agora tudo vive na memoria do proprio processo do servidor, o seed roda
/// automaticamente a cada `dart run bin/server.dart`.
void _seedDemoData(MemoryStore store) {
  final demoPasswordHash = PasswordUtil.hash('senha123');

  final usersData = [
    {'name': 'Marina Alves', 'email': 'marina@swingsense.app', 'level': 'avancado', 'city': 'Sao Paulo, SP', 'bio': 'Tenista ha 12 anos. Foco em consistencia de fundo de quadra.'},
    {'name': 'Rafael Souza', 'email': 'rafael@swingsense.app', 'level': 'intermediario', 'city': 'Curitiba, PR', 'bio': 'Treinando o saque toda semana com a raquete inteligente.'},
    {'name': 'Beatriz Lima', 'email': 'beatriz@swingsense.app', 'level': 'iniciante', 'city': 'Belo Horizonte, MG', 'bio': 'Comecei a jogar tenis este ano, buscando evoluir!'},
    {'name': 'Thiago Nunes', 'email': 'thiago@swingsense.app', 'level': 'avancado', 'city': 'Rio de Janeiro, RJ', 'bio': 'Ex-atleta universitario. Agora treino e ensino.'},
    {'name': 'Voce', 'email': 'demo@swingsense.app', 'level': 'intermediario', 'city': 'Sao Paulo, SP', 'bio': 'Conta de demonstracao do Swing Sense.'},
  ];

  final userIds = <String>[];
  for (final u in usersData) {
    final id = MemoryStore.newId();
    store.users.add({
      'id': id,
      'name': u['name'],
      'email': u['email'],
      'password_hash': demoPasswordHash,
      'avatar_url': null,
      'bio': u['bio'],
      'level': u['level'],
      'birth_date': null,
      'city': u['city'],
      'role': 'player',
      'created_at': DateTime.now(),
    });
    userIds.add(id);
  }
  final demoUserId = userIds.last;

  void follow(String followerId, String followingId) {
    if (store.isFollowing(followerId, followingId)) return;
    store.follows.add({
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': DateTime.now(),
    });
  }

  // "Voce" (conta demo) segue todo mundo; os outros se seguem entre si tambem.
  for (final id in userIds.sublist(0, userIds.length - 1)) {
    follow(demoUserId, id);
  }
  follow(userIds[1], userIds[0]);
  follow(userIds[0], userIds[3]);

  final trainingsData = [
    {
      'author': userIds[3],
      'title': 'Fundamentos do Saque',
      'description': 'Serie guiada para consolidar o movimento do saque, do ritmo ao ponto de impacto.',
      'audience': 'iniciante', 'difficulty': 'iniciante', 'duration': 25, 'focus': 'saque', 'color': '1DB954',
    },
    {
      'author': userIds[0],
      'title': 'Consistencia de Forehand',
      'description': 'Sequencia de rally para melhorar consistencia e profundidade do forehand.',
      'audience': 'intermediario', 'difficulty': 'intermediario', 'duration': 35, 'focus': 'forehand', 'color': '2EBD59',
    },
    {
      'author': userIds[3],
      'title': 'Backhand de Alta Rotacao',
      'description': 'Treino avancado de top spin no backhand com metas de velocidade da bola.',
      'audience': 'avancado', 'difficulty': 'avancado', 'duration': 40, 'focus': 'backhand', 'color': '169C46',
    },
    {
      'author': userIds[0],
      'title': 'Explosao e Deslocamento',
      'description': 'Circuito de resistencia e deslocamento lateral em quadra.',
      'audience': 'geral', 'difficulty': 'intermediario', 'duration': 30, 'focus': 'resistencia', 'color': '1ED760',
    },
    {
      'author': null,
      'title': 'Primeiro Contato com a Raquete',
      'description': 'Treino introdutorio para quem esta pegando na raquete pela primeira vez.',
      'audience': 'iniciante', 'difficulty': 'iniciante', 'duration': 20, 'focus': 'fundamentos', 'color': '1DB954',
    },
  ];

  final trainingIds = <String>[];
  for (final t in trainingsData) {
    final id = MemoryStore.newId();
    store.trainings.add({
      'id': id,
      'author_id': t['author'],
      'title': t['title'],
      'description': t['description'],
      'target_audience': t['audience'],
      'difficulty': t['difficulty'],
      'duration_minutes': t['duration'],
      'focus': t['focus'],
      'cover_color': t['color'],
      'is_published': true,
      'version': 1,
      'created_at': DateTime.now(),
    });
    trainingIds.add(id);
  }

  // Sessoes concluidas (mockadas) para popular feed, historico e perfil.
  for (final userId in userIds) {
    final sessionsForUser = 3 + _random.nextInt(4);
    for (var i = 0; i < sessionsForUser; i++) {
      final training = trainingIds[_random.nextInt(trainingIds.length)];
      final daysAgo = _random.nextInt(30);
      final durationSeconds = 900 + _random.nextInt(2400);
      final shotCount = 40 + _random.nextInt(160);
      final aceCount = _random.nextInt(6);
      final avgSpeed = 60 + _random.nextInt(40);
      final maxSpeed = avgSpeed + 10 + _random.nextInt(30);
      final calories = 120 + _random.nextInt(380);

      final sessionId = MemoryStore.newId();
      store.trainingSessions.add({
        'id': sessionId,
        'user_id': userId,
        'training_id': training,
        'device_id': null,
        'title': 'Treino de tenis',
        'status': 'completed',
        'started_at': DateTime.now().subtract(Duration(days: daysAgo, minutes: durationSeconds ~/ 60)),
        'ended_at': DateTime.now().subtract(Duration(days: daysAgo)),
        'duration_seconds': durationSeconds,
        'shot_count': shotCount,
        'ace_count': aceCount,
        'avg_ball_speed_kmh': avgSpeed.toDouble(),
        'max_ball_speed_kmh': maxSpeed.toDouble(),
        'calories': calories,
        'notes': null,
        'created_at': DateTime.now(),
      });

      // Curtidas cruzadas para o feed ja nascer com engajamento.
      for (final otherId in userIds) {
        if (otherId != userId && _random.nextBool()) {
          store.sessionLikes.add({
            'session_id': sessionId,
            'user_id': otherId,
            'created_at': DateTime.now(),
          });
        }
      }
    }
  }

  // Metas de exemplo para a conta demo.
  final goalsData = [
    {'type': 'sessions_per_week', 'title': 'Treinar 4x por semana', 'target': 4.0, 'current': 2.0, 'unit': 'sessoes'},
    {'type': 'avg_ball_speed', 'title': 'Atingir 110 km/h no saque', 'target': 110.0, 'current': 92.0, 'unit': 'km/h'},
    {'type': 'total_minutes', 'title': 'Acumular 10h de treino no mes', 'target': 600.0, 'current': 245.0, 'unit': 'min'},
  ];
  for (final g in goalsData) {
    store.goals.add({
      'id': MemoryStore.newId(),
      'user_id': demoUserId,
      'type': g['type'],
      'title': g['title'],
      'target_value': g['target'],
      'current_value': g['current'],
      'unit': g['unit'],
      'deadline': DateTime.now().add(const Duration(days: 30)),
      'status': 'active',
      'created_at': DateTime.now(),
    });
  }

  // Glossario de regras e fundamentos do tenis (conteudo educativo para novos usuarios).
  final glossaryData = [
    // Fundamentos
    {'term': 'Saque', 'category': 'fundamentos', 'order': 1, 'text': 'Golpe que inicia cada ponto. O jogador lanca a bola ao ar e a rebate por cima da rede, dentro da area de saque adversaria (quadrante diagonal).'},
    {'term': 'Ace', 'category': 'fundamentos', 'order': 2, 'text': 'Saque que o adversario nao consegue sequer tocar. Ponto direto para quem sacou.'},
    {'term': 'Forehand', 'category': 'fundamentos', 'order': 3, 'text': 'Golpe de fundo batido do lado dominante do corpo (direita para destros), com a palma da mao virada para a bola.'},
    {'term': 'Backhand', 'category': 'fundamentos', 'order': 4, 'text': 'Golpe de fundo batido do lado nao dominante do corpo, podendo ser de uma ou duas maos.'},
    {'term': 'Voleio', 'category': 'fundamentos', 'order': 5, 'text': 'Golpe batido antes da bola quicar no chao, normalmente perto da rede.'},
    {'term': 'Smash', 'category': 'fundamentos', 'order': 6, 'text': 'Golpe forte batido acima da cabeca, usado para finalizar o ponto quando a bola vem alta.'},
    {'term': 'Rally', 'category': 'fundamentos', 'order': 7, 'text': 'Sequencia de trocas de bola entre os jogadores dentro de um mesmo ponto.'},
    {'term': 'Winner', 'category': 'fundamentos', 'order': 8, 'text': 'Golpe vencedor: a bola toca a quadra e o adversario nao consegue alcanca-la, encerrando o ponto.'},
    {'term': 'Erro nao forcado', 'category': 'fundamentos', 'order': 9, 'text': 'Erro cometido sem pressao do adversario, geralmente por falha tecnica ou de concentracao propria.'},
    // Pontuacao
    {'term': '15, 30, 40', 'category': 'pontuacao', 'order': 1, 'text': 'Sequencia de pontos dentro de um game: 0 (love), 15, 30, 40. Quem fizer o quinto ponto com 2 de vantagem vence o game.'},
    {'term': 'Deuce', 'category': 'pontuacao', 'order': 2, 'text': 'Empate em 40-40. E preciso vencer dois pontos seguidos (vantagem + ponto) para fechar o game.'},
    {'term': 'Vantagem (Ad)', 'category': 'pontuacao', 'order': 3, 'text': 'Ponto conquistado logo apos o deuce. Se o jogador com vantagem vencer o proximo ponto, fecha o game.'},
    {'term': 'Game', 'category': 'pontuacao', 'order': 4, 'text': 'Unidade de pontuacao formada por uma sequencia de pontos. E preciso vencer 6 games (com 2 de vantagem) para fechar um set.'},
    {'term': 'Set', 'category': 'pontuacao', 'order': 5, 'text': 'Conjunto de games. Partidas costumam ser melhor de 3 ou melhor de 5 sets.'},
    {'term': 'Tie-break', 'category': 'pontuacao', 'order': 6, 'text': 'Disputa especial jogada quando o set empata em 6-6 (na maioria dos torneios), vencida por quem chegar a 7 pontos com 2 de vantagem.'},
    {'term': 'Break point', 'category': 'pontuacao', 'order': 7, 'text': 'Ponto que, se vencido por quem esta recebendo o saque, quebra o game do sacador (break de saque).'},
    // Efeitos na bola
    {'term': 'Top spin', 'category': 'efeitos', 'order': 1, 'text': 'Efeito de rotacao para frente aplicado na bola, que faz ela subir na trajetoria e cair com mais forca e segurança dentro da quadra.'},
    {'term': 'Slice (back spin)', 'category': 'efeitos', 'order': 2, 'text': 'Efeito de rotacao para tras, que faz a bola flutuar baixo e quicar mais rente ao chao — bom para variar o ritmo do adversario.'},
    {'term': 'Flat (bola chapada)', 'category': 'efeitos', 'order': 3, 'text': 'Golpe batido com pouco ou nenhum efeito de rotacao, priorizando velocidade em linha reta.'},
    {'term': 'Kick serve', 'category': 'efeitos', 'order': 4, 'text': 'Saque com bastante top spin lateral, que faz a bola quicar alto e para o lado apos tocar a quadra.'},
    // Quadra e posicionamento
    {'term': 'Linha de fundo (baseline)', 'category': 'quadra', 'order': 1, 'text': 'Linha que delimita o fundo da quadra, de onde o saque e executado e onde acontece boa parte da troca de bola.'},
    {'term': 'Área de saque', 'category': 'quadra', 'order': 2, 'text': 'Retangulo diagonal a frente da rede para onde o saque deve ser direcionado para ser valido.'},
    {'term': 'Rede', 'category': 'quadra', 'order': 3, 'text': 'Divisoria central da quadra. A bola precisa passar por cima dela em cada troca para o ponto continuar valido.'},
    {'term': 'Zona de ataque (meio de quadra)', 'category': 'quadra', 'order': 4, 'text': 'Regiao entre a linha de fundo e a rede, usada para se aproximar e finalizar o ponto com voleios ou smashes.'},
  ];
  for (final entry in glossaryData) {
    store.glossaryTerms.add({
      'id': MemoryStore.newId(),
      'term': entry['term'],
      'category': entry['category'],
      'short_explanation': entry['text'],
      'sort_order': entry['order'],
    });
  }
}
