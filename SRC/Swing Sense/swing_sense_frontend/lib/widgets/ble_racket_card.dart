import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/ble/ble_racket_service.dart';

/// Cartao de conexao da raquete real (Bluetooth). Mostra o estado e permite
/// procurar/conectar e desconectar. A conexao e feita aqui dentro do app: o
/// prototipo e BLE e NAO aparece na tela de Bluetooth do sistema.
class BleRacketCard extends StatelessWidget {
  const BleRacketCard({super.key, required this.onConnect, this.busy = false});

  /// Chamado ao tocar em "Procurar raquete". A tela decide o que fazer em
  /// volta (registrar o dispositivo, mostrar erro...).
  final VoidCallback onConnect;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ble = BleRacketService.instance;
    return ValueListenableBuilder<RacketLinkState>(
      valueListenable: ble.state,
      builder: (context, state, _) {
        final connected = state == RacketLinkState.connected;
        final working = state == RacketLinkState.scanning ||
            state == RacketLinkState.connecting ||
            state == RacketLinkState.reconnecting ||
            busy;

        late final String title;
        late final String subtitle;
        late final IconData icon;
        late final Color color;
        switch (state) {
          case RacketLinkState.idle:
            title = 'Raquete real (Bluetooth)';
            subtitle = 'Ligue a raquete e fique perto do celular.';
            icon = Icons.bluetooth;
            color = AppColors.textSecondary;
          case RacketLinkState.scanning:
            title = 'Procurando raquete...';
            subtitle = 'Procurando um SwingSense por perto.';
            icon = Icons.bluetooth_searching;
            color = AppColors.warning;
          case RacketLinkState.connecting:
            title = 'Conectando...';
            subtitle = ble.deviceName ?? 'SwingSense';
            icon = Icons.bluetooth_searching;
            color = AppColors.warning;
          case RacketLinkState.connected:
            title = ble.deviceName ?? 'SwingSense';
            subtitle = 'Conectada - cada tacada chega ao vivo.';
            icon = Icons.bluetooth_connected;
            color = AppColors.green;
          case RacketLinkState.reconnecting:
            title = 'Reconectando...';
            subtitle = 'A conexao caiu. Tentando de novo sozinho.';
            icon = Icons.bluetooth_searching;
            color = AppColors.warning;
          case RacketLinkState.error:
            title = 'Sem conexao';
            subtitle = ble.errorMessage ?? 'Nao foi possivel conectar.';
            icon = Icons.bluetooth_disabled;
            color = AppColors.error;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: connected ? AppColors.green.withOpacity(0.4) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (working)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.green),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: () => ble.disconnect(),
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Desconectar'),
                      )
                    : OutlinedButton.icon(
                        onPressed: working ? null : onConnect,
                        icon: const Icon(Icons.bluetooth_searching, size: 18),
                        label: Text(state == RacketLinkState.error ? 'Tentar de novo' : 'Procurar raquete'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
