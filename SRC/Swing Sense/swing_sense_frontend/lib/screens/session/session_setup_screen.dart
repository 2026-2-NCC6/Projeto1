import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/device.dart';
import '../../models/training.dart';
import '../../services/api_client.dart';
import '../../services/device_service.dart';
import '../../services/session_service.dart';
import '../../widgets/primary_button.dart';
import 'live_session_screen.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key, this.preselectedTraining});
  final Training? preselectedTraining;

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  final _deviceService = DeviceService(ApiClient.instance);
  final _sessionService = SessionService(ApiClient.instance);

  SmartDevice? _device;
  bool _loadingDevice = true;
  bool _pairing = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    try {
      final devices = await _deviceService.myDevices();
      if (mounted) setState(() => _device = devices.isNotEmpty ? devices.first : null);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDevice = false);
    }
  }

  Future<void> _pairDevice() async {
    setState(() => _pairing = true);
    try {
      final device = await _deviceService.pairSimulated();
      if (mounted) setState(() => _device = device);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nao foi possivel parear a raquete')));
      }
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _startSession() async {
    setState(() => _starting = true);
    try {
      final session = await _sessionService.start(
        trainingId: widget.preselectedTraining?.id,
        deviceId: _device?.id,
        title: widget.preselectedTraining?.title ?? 'Treino livre',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LiveSessionScreen(session: session)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nao foi possivel iniciar o treino')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final training = widget.preselectedTraining;
    return Scaffold(
      appBar: AppBar(title: const Text('Novo treino')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      training?.title ?? 'Treino livre',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      training != null
                          ? '${training.difficultyLabel} - ${training.durationMinutes} min'
                          : 'Sem roteiro fixo - jogue no seu ritmo e a raquete registra tudo.',
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Raquete inteligente', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              _loadingDevice
                  ? const LinearProgressIndicator(color: AppColors.green, backgroundColor: AppColors.surfaceElevated)
                  : _device != null
                      ? _DeviceStatusCard(device: _device!)
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bluetooth_disabled, color: AppColors.textSecondary),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Nenhuma raquete pareada. O hardware ainda esta em desenvolvimento - '
                                      'pareie a raquete simulada para gerar dados de treino automaticamente.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              AppSecondaryButton(
                                label: _pairing ? 'Pareando...' : 'Parear raquete simulada',
                                icon: Icons.bluetooth_searching,
                                onPressed: _pairing ? null : _pairDevice,
                              ),
                            ],
                          ),
                        ),
              const Spacer(),
              PrimaryButton(
                label: 'Comecar agora',
                icon: Icons.play_arrow,
                isLoading: _starting,
                onPressed: _startSession,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.device});
  final SmartDevice device;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
            child: const Icon(Icons.sports_tennis, color: AppColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  device.isSimulated ? 'Modo simulado - conectada' : 'Conectada',
                  style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.green),
        ],
      ),
    );
  }
}
