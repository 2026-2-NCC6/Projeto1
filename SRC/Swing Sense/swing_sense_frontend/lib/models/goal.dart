class Goal {
  Goal({
    required this.id,
    required this.type,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    this.unit = 'un',
    this.deadline,
    this.status = 'active',
  });

  final String id;
  final String type;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime? deadline;
  final String status;

  double get progress => targetValue == 0 ? 0 : (currentValue / targetValue).clamp(0, 1);
  bool get isCompleted => status == 'completed' || progress >= 1;

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'custom',
      title: json['title'] as String? ?? 'Meta',
      targetValue: _toDouble(json['targetValue']),
      currentValue: _toDouble(json['currentValue']),
      unit: json['unit'] as String? ?? 'un',
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
      status: json['status'] as String? ?? 'active',
    );
  }
}
