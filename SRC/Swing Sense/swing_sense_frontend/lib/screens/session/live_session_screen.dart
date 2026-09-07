import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/session_event.dart';
import '../../models/training_session.dart';
import '../../services/api_client.dart';
import '../../services/mock_racket_service.dart';
import '../../services/session_service.dart';
import 'session_summary_screen.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.session});
  final TrainingSession session;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final _sessionService = SessionService(ApiClient.instance);
  final _racket = MockRacketService();

  Timer? _clock;
  StreamSubscription<SessionEvent>? _subscription;

  final List<SessionEvent> _events = [];
  final List<SessionEvent> _pendingFlush = [];

  int _elapsedSeconds = 0;
  bool _paused = false;
  bool _stopping = false;
  double _lastSpeed = 0;

  int get _shotCount => _events.where((e) => e.eventType == 'shot' || e.eventType == 'ace').length;
  int get _aceCount => _events.where((e) => e.eventType == 'ace').length;
  double? get _avgSpeed {
    final speeds = _events.map((e) => e.ballSpeedKmh).whereType<double>().toList();
    if (speeds.isEmpty) return null;
    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  double? get _maxSpeed {
    final speeds = _events.map((e) => e.ballSpeedKmh).whereType<double>().toList();
    if (speeds.isEmpty) return null;
    return speeds.reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _startClock();
    _subscription = _racket.events.listen(_onEvent);
    _racket.start();
  }

  void _startClock() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) setState(() => _elapsedSeconds++);
      if (_elapsedSeconds > 0 && _elapsedSeconds % 6 == 0 && !_paused) _flushEvents();
    });
  }

  void _onEvent(SessionEvent event) {
    setState(() {
      _events.add(event);
      _pendingFlush.add(event);
      if (event.ballSpeedKmh != null) _lastSpeed = event.ballSpeedKmh!;
    });
  }

  Future<void> _flushEvents() async {
    if (_pendingFlush.isEmpty) return;
    final toSend = List<SessionEvent>.from(_pendingFlush);
    _pendingFlush.clear();
    try {
      await _sessionService.sendEvents(widget.session.id, toSend);
    } catch (_) {
      _pendingFlush.insertAll(0, toSend);
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _racket.stop();
      _sessionService.update(widget.session.id, status: 'paused', durationSeconds: _elapsedSeconds);
    } else {
      _racket.start();
      _sessionService.update(widget.session.id, status: 'in_progress');
    }
  }

  Future<void> _stopSession({required bool completed}) async {
    setState(() => _stopping = true);
    _clock?.cancel();
    _racket.stop();
    await _flushEvents();

    try {
      final updated = await _sessionService.update(
        widget.session.id,
        status: completed ? 'completed' : 'aborted',
        durationSeconds: _elapsedSeconds,
        shotCount: _shotCount,
        aceCount: _aceCount,
        avgBallSpeedKmh: _avgSpeed,
        maxBallSpeedKmh: _maxSpeed,
        calories: (_elapsedSeconds / 60 * 7).round(),
      );
      if (!mounted) return;
      if (completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SessionSummaryScreen(session: updated)),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmSafeStop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Parada segura'),
        content: const Text(
          'Isso encerra o treino imediatamente e bloqueia novos comandos ate voce reiniciar. Deseja continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Parar treino', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (result == true) _stopSession(completed: false);
  }

  String get _timeLabel {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  @override
  void dispose() {
    _clock?.cancel();
    _subscription?.cancel();
    _racket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: _confirmSafeStop,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _paused ? AppColors.warning.withOpacity(0.15) : AppColors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _paused ? 'PAUSADO' : 'AO VIVO',
                        style: TextStyle(
                          color: _paused ? AppColors.warning : AppColors.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.session.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                _timeLabel,
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 28),
              _SpeedGauge(speed: _lastSpeed),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LiveStat(label: 'Tacadas', value: '$_shotCount', icon: Icons.sports_tennis_outlined),
                  _LiveStat(label: 'Aces', value: '$_aceCount', icon: Icons.bolt_outlined),
                  _LiveStat(
                    label: 'Vel. media',
                    value: _avgSpeed != null ? '${_avgSpeed!.round()} km/h' : '-',
                    icon: Icons.speed_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _EventFeed(events: _events)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _stopping ? null : _togglePause,
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                        label: Text(_paused ? 'Retomar' : 'Pausar'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _stopping ? null : () => _stopSession(completed: true),
                        icon: const Icon(Icons.flag_outlined, color: Colors.black),
                        label: Text(_stopping ? 'Salvando...' : 'Encerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.speed});
  final double speed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green.withOpacity(0.5), width: 3),
        boxShadow: speed > 0
            ? [BoxShadow(color: AppColors.green.withOpacity(0.25), blurRadius: 30, spreadRadius: 2)]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speed > 0 ? speed.round().toString() : '--',
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
          ),
          const Text('km/h ultima bola', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.green, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _EventFeed extends StatelessWidget {
  const _EventFeed({required this.events});
  final List<SessionEvent> events;

  Color _colorFor(String type) {
    switch (type) {
      case 'ace':
        return AppColors.green;
      case 'fault':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = events.reversed.take(20).toList();
    if (recent.isEmpty) {
      return const Center(
        child: Text('Aguardando dados da raquete...', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final e = recent[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: _colorFor(e.eventType), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(e.label, style: TextStyle(color: _colorFor(e.eventType), fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (e.ballSpeedKmh != null)
                Text('${e.ballSpeedKmh!.round()} km/h', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
