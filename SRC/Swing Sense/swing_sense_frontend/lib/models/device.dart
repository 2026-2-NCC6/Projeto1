/// Representa a raquete inteligente pareada com o usuario. Enquanto o ESP32
/// fisico nao existe, `isSimulated` vem `true` e a telemetria e gerada pelo
/// MockRacketService no proprio app.
class SmartDevice {
  SmartDevice({
    required this.id,
    required this.deviceName,
    required this.isSimulated,
    this.deviceIdentifier,
    this.firmwareVersion,
    this.lastSyncAt,
  });

  final String id;
  final String deviceName;
  final bool isSimulated;

  /// Identificador do hardware (ex.: `SwingSense-A1B2` para o prototipo BLE).
  final String? deviceIdentifier;
  final String? firmwareVersion;
  final DateTime? lastSyncAt;

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    return SmartDevice(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String? ?? 'Smart Racket',
      isSimulated: json['isSimulated'] as bool? ?? true,
      deviceIdentifier: json['deviceIdentifier'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.tryParse(json['lastSyncAt'] as String) : null,
    );
  }
}
