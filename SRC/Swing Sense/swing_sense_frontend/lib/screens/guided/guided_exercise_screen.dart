import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/guided_training.dart';
import '../../widgets/drill_animation_view.dart';
import '../../widgets/primary_button.dart';

/// Um exercicio do treino guiado: animacao na quadra, explicacao, passo a
/// passo, dicas e erros comuns, com navegacao entre exercicios.
class GuidedExerciseScreen extends StatefulWidget {
  const GuidedExerciseScreen({super.key, required this.training, this.initialIndex = 0});
  final GuidedTraining training;
  final int initialIndex;

  @override
  State<GuidedExerciseScreen> createState() => _GuidedExerciseScreenState();
}

class _GuidedExerciseScreenState extends State<GuidedExerciseScreen> {
  late int _index = widget.initialIndex;
  final _scroll = ScrollController();

  GuidedExercise get _exercise => widget.training.exercises[_index];
  bool get _isLast => _index == widget.training.exercises.length - 1;

  void _go(int delta) {
    setState(() => _index = (_index + delta).clamp(0, widget.training.exercises.length - 1));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _exercise;
    final total = widget.training.exercises.length;
    return Scaffold(
      appBar: AppBar(title: Text('Exercicio ${_index + 1} de $total')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  DrillAnimationView(animation: ex.animation),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text('Toque na animacao para pausar',
                        style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                  ),
                  const SizedBox(height: 14),
                  Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _Pill(icon: Icons.repeat, text: ex.prescription),
                      const _Pill(icon: Icons.gps_fixed, text: 'Mire no alvo verde'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(ex.summary, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 12),
                  _GoalBox(text: ex.goal),
                  const _SectionTitle('Como fazer'),
                  ...List.generate(
                    ex.steps.length,
                    (i) => _StepTile(number: i + 1, text: ex.steps[i]),
                  ),
                  const _SectionTitle('Dicas'),
                  ...ex.tips.map((t) => _Bullet(icon: Icons.lightbulb_outline, color: AppColors.greenBright, text: t)),
                  const _SectionTitle('Erros comuns'),
                  ...ex.mistakes.map((t) => _Bullet(icon: Icons.close_rounded, color: AppColors.error, text: t)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _go(-1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('Anterior', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _isLast ? 'Concluir' : 'Proximo exercicio',
                      icon: _isLast ? Icons.check : Icons.arrow_forward,
                      onPressed: _isLast ? () => Navigator.of(context).pop() : () => _go(1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.green),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _GoalBox extends StatelessWidget {
  const _GoalBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.green.withOpacity(0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gps_fixed, color: AppColors.greenBright, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
          ],
        ),
      );
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              child: Text('$number', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(text, style: const TextStyle(height: 1.45)))),
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.45))),
          ],
        ),
      );
}
