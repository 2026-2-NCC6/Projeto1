import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/training.dart';
import '../../services/api_client.dart';
import '../../services/training_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/primary_button.dart';
import '../session/session_setup_screen.dart';

class TrainingDetailScreen extends StatefulWidget {
  const TrainingDetailScreen({super.key, required this.trainingId});
  final String trainingId;

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  final _service = TrainingService(ApiClient.instance);
  Training? _training;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final training = await _service.get(widget.trainingId);
      if (mounted) setState(() => _training = training);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: SwingSenseLoader()));
    }
    final training = _training;
    if (training == null) {
      return const Scaffold(body: Center(child: Text('Treino nao encontrado')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(training.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(icon: Icons.bar_chart, label: training.difficultyLabel),
                  _InfoChip(icon: Icons.timer_outlined, label: '${training.durationMinutes} min'),
                  if (training.focus != null) _InfoChip(icon: Icons.center_focus_strong, label: training.focus!),
                  if (training.authorName != null) _InfoChip(icon: Icons.person_outline, label: training.authorName!),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Sobre este treino', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                training.description ?? 'Sem descricao adicional.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.green, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A pontuacao e calculada a partir dos dados da sua raquete inteligente '
                        '(velocidade da bola e numero de tacadas) captados durante a sessao.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Iniciar treino',
                icon: Icons.play_arrow,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionSetupScreen(preselectedTraining: training),
                  ),
                ),
              ),
            ],
          ),
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
