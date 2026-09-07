class GlossaryTerm {
  GlossaryTerm({
    required this.id,
    required this.term,
    required this.category,
    required this.shortExplanation,
  });

  final String id;
  final String term;
  final String category;
  final String shortExplanation;

  static const categories = {
    'fundamentos': 'Fundamentos',
    'pontuacao': 'Pontuacao',
    'efeitos': 'Efeitos na bola',
    'quadra': 'Quadra e posicionamento',
  };

  String get categoryLabel => categories[category] ?? category;

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      id: json['id'] as String,
      term: json['term'] as String? ?? '',
      category: json['category'] as String? ?? 'fundamentos',
      shortExplanation: json['shortExplanation'] as String? ?? '',
    );
  }
}
