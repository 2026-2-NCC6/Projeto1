import '../models/device.dart';
import 'api_client.dart';

class DeviceService {
  DeviceService(this._client);
  final ApiClient _client;

  Future<List<SmartDevice>> myDevices() async {
    final data = await _client.get('/devices/me');
    return (data as List).map((e) => SmartDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SmartDevice> pairSimulated({String deviceName = 'Smart Racket (simulada)'}) async {
    final data = await _client.post('/devices/pair', body: {
      'deviceName': deviceName,
      'isSimulated': true,
      'firmwareVersion': 'mock-1.0.0',
    });
    return SmartDevice.fromJson(data as Map<String, dynamic>);
  }
}
