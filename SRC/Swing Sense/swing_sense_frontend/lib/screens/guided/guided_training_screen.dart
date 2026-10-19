import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/guided_training.dart';
import '../../widgets/primary_button.dart';
import '../session/session_setup_screen.dart';
import 'guided_exercise_screen.dart';

/// Visao geral de um treino guiado: explicacao, beneficios e a lista de
/// exercicios (cada um com animacao propria).
class GuidedTrainingScreen extends StatelessWidget {
  const GuidedTrainingScreen({super.key, required this.training});
  final GuidedTraining training;

  void _openExercise(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuidedExerciseScreen(training: training, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treino guiado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sports_tennis, color: Colors.black, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    training.title,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22, height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(training.subtitle, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(icon: Icons.bar_chart, label: training.difficultyLabel),
                _InfoChip(icon: Icons.timer_outlined, label: '${training.durationMinutes} min'),
                _InfoChip(icon: Icons.format_list_numbered, label: '${training.exercises.length} exercicios'),
                _InfoChip(icon: Icons.center_focus_strong, label: training.focus),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Sobre este treino', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              training.description,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text('O que voce vai ganhar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            ...training.benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle, color: AppColors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Exercicios', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            ...List.generate(training.exercises.length, (i) {
              final ex = training.exercises[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openExercise(context, i),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${i + 1}', style: const TextStyle(color: AppColors.greenBright, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(ex.prescription, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_outline, color: AppColors.green),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Comecar guia',
              icon: Icons.play_arrow,
              onPressed: () => _openExercise(context, 0),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SessionSetupScreen(preselectedTraining: training.toTraining())),
                ),
                icon: const Icon(Icons.sensors, color: AppColors.green),
                label: const Text('Treinar com a raquete', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
