import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/phase_type.dart';
import '../providers/player_provider.dart';
import '../widgets/big_timer_widget.dart';

/// Schermata riprodotta durante la lezione vera e propria: font grande,
/// alto contrasto, pensata per essere letta a bordo vasca senza dover
/// prendere in mano il telefono. Tiene lo schermo acceso (wakelock) per
/// tutta la durata della lezione.
class LivePlayerScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LivePlayerScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(livePlayerControllerProvider(widget.lessonId));
    final controller = ref.read(livePlayerControllerProvider(widget.lessonId).notifier);
    final phaseColor = AppTheme.colorForPhase(state.plan.phases[state.phaseIndex].type.name);

    if (state.isConnecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connessione a Spotify...'),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(state.error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (state.isFinished) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text('Lezione completata!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Torna alle lezioni'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _PhaseProgressBar(currentIndex: state.phaseIndex),
              const Spacer(),
              BigTimerWidget(
                remaining: state.phaseRemaining,
                label: state.plan.phases[state.phaseIndex].type.label,
                color: phaseColor,
              ),
              const SizedBox(height: 8),
              Text(
                'Lezione: ${_fmt(state.totalRemaining)} rimanenti',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (state.currentTrack != null) ...[
                Text(
                  state.currentTrack!.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.currentTrack!.artist} · ${state.currentTrack!.bpm ?? '--'} BPM',
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ] else
                const Text('In attesa del prossimo brano...',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
              if (state.nextTrack != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Prossimo: ${state.nextTrack!.title}',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 56,
                    color: Colors.white,
                    icon: Icon(state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: controller.togglePlayPause,
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    iconSize: 44,
                    color: Colors.white,
                    icon: const Icon(Icons.skip_next),
                    onPressed: controller.skipToNextTrack,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _PhaseProgressBar extends StatelessWidget {
  final int currentIndex;

  const _PhaseProgressBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final phase in PhaseType.values)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              decoration: BoxDecoration(
                color: phase.index <= currentIndex
                    ? AppTheme.colorForPhase(phase.name)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}
