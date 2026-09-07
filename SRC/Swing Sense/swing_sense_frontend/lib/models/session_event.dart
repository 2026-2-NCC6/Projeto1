/// Um evento de telemetria da raquete inteligente (real ou simulada):
/// tacada, ace, falta, inicio/fim de rally - com velocidade da bola (sensor)
/// e angulo/rotacao (giroscopio/IMU sob a raquete).
class SessionEvent {
  SessionEvent({
    required this.eventType,
    this.ballSpeedKmh,
    this.spinRateRpm,
    this.racketAngleDeg,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  final String eventType;
  final double? ballSpeedKmh;
  final double? spinRateRpm;
  final double? racketAngleDeg;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'ballSpeedKmh': ballSpeedKmh,
        'spinRateRpm': spinRateRpm,
        'racketAngleDeg': racketAngleDeg,
      };

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      eventType: json['eventType'] as String? ?? 'shot',
      ballSpeedKmh: _toDouble(json['ballSpeedKmh']),
      spinRateRpm: _toDouble(json['spinRateRpm']),
      racketAngleDeg: _toDouble(json['racketAngleDeg']),
      occurredAt: json['occurredAt'] != null ? DateTime.tryParse(json['occurredAt'] as String) : null,
    );
  }

  String get label {
    switch (eventType) {
      case 'shot':
        return 'Tacada';
      case 'ace':
        return 'Ace';
      case 'fault':
        return 'Falta';
      case 'rally_start':
        return 'Inicio de rally';
      case 'rally_end':
        return 'Fim de rally';
      default:
        return eventType;
    }
  }
}
