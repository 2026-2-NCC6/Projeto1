import '../animation/scene3d.dart';
import 'training.dart';

/// Um exercicio de um treino guiado: explicacao, passo a passo, dicas e a
/// animacao (na quadra) mostrando como executar.
class GuidedExercise {
  const GuidedExercise({
    required this.name,
    required this.summary,
    required this.animation,
    required this.steps,
    required this.tips,
    required this.mistakes,
    required this.prescription,
    required this.goal,
  });

  final String name;

  /// O que e o exercicio e para que serve.
  final String summary;
  final DrillAnimation animation;

  /// Passo a passo da execucao.
  final List<String> steps;
  final List<String> tips;
  final List<String> mistakes;

  /// Ex.: "3 series de 10 bolas".
  final String prescription;

  /// Onde mirar / o que significa acertar o alvo.
  final String goal;
}

/// Treino pre-pronto (funciona sem internet, e independente do catalogo da API).
class GuidedTraining {
  const GuidedTraining({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.difficulty,
    required this.durationMinutes,
    required this.focus,
    required this.coverColor,
    required this.benefits,
    required this.exercises,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String difficulty; // iniciante | intermediario | avancado
  final int durationMinutes;
  final String focus;
  final String coverColor; // RRGGBB
  final List<String> benefits;
  final List<GuidedExercise> exercises;

  String get difficultyLabel {
    switch (difficulty) {
      case 'iniciante':
        return 'Iniciante';
      case 'intermediario':
        return 'Intermediario';
      case 'avancado':
        return 'Avancado';
      default:
        return difficulty;
    }
  }

  /// Representacao usada pela tela de sessao ao registrar o treino com a
  /// raquete. `id` vazio = treino local (a sessao e criada sem `trainingId`).
  Training toTraining() => Training(
        id: '',
        title: title,
        description: description,
        difficulty: difficulty,
        durationMinutes: durationMinutes,
        focus: focus,
        coverColor: coverColor,
      );
}
