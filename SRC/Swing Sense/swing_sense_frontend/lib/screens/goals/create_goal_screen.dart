import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/goals_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_pill.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  String _type = 'sessions_per_week';
  bool _saving = false;

  static const _types = {
    'sessions_per_week': ('Treinos por semana', 'sessoes'),
    'avg_ball_speed': ('Velocidade media da bola', 'km/h'),
    'total_minutes': ('Minutos totais de treino', 'min'),
    'custom': ('Meta personalizada', 'un'),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<GoalsProvider>().createGoal(
            type: _type,
            title: _titleController.text.trim(),
            targetValue: double.parse(_targetController.text.replaceAll(',', '.')),
            unit: _types[_type]!.$2,
            deadline: DateTime.now().add(const Duration(days: 30)),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nao foi possivel criar a meta')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova meta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tipo de meta', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _types.entries
                      .map((e) => ChipTag(
                            label: e.value.$1,
                            selected: _type == e.key,
                            onTap: () => setState(() => _type = e.key),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Titulo da meta',
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um titulo' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Valor alvo (${_types[_type]!.$2})',
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe um valor';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: 'Criar meta', onPressed: _save, isLoading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
