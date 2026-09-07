import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/glossary_term.dart';
import '../../services/api_client.dart';
import '../../services/glossary_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stat_pill.dart';

/// Tela educativa com regras e fundamentos basicos do tenis, pensada para
/// jogadores iniciantes que estao chegando na comunidade Swing Sense.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final _service = GlossaryService(ApiClient.instance);
  List<GlossaryTerm> _terms = [];
  bool _loading = true;
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final terms = await _service.list();
      if (mounted) setState(() => _terms = terms);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _category == null ? _terms : _terms.where((t) => t.category == _category).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Regras do tenis')),
      body: _loading
          ? const Center(child: SwingSenseLoader())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Novo por aqui? Veja os principais termos e regras usados no tenis antes do seu primeiro treino.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChipTag(label: 'Todos', selected: _category == null, onTap: () => setState(() => _category = null)),
                      ),
                      ...GlossaryTerm.categories.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChipTag(
                            label: e.value,
                            selected: _category == e.key,
                            onTap: () => setState(() => _category = e.key),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final term = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(term.term, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    term.categoryLabel,
                                    style: const TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(term.shortExplanation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
