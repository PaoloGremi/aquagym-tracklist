import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify_sdk/models/player_state.dart' as sdk;

import '../../data/spotify/spotify_remote_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/track.dart';
import 'core_providers.dart';

class LivePlayerState {
  final LessonPlan plan;
  final int phaseIndex;
  final int trackIndex;
  final Track? currentTrack;
  final Duration trackElapsed;
  final Duration phaseRemaining;
  final Duration totalRemaining;
  final bool isPlaying;
  final bool isConnecting;
  final bool isFinished;
  final String? error;

  const LivePlayerState({
    required this.plan,
    required this.phaseIndex,
    required this.trackIndex,
    required this.phaseRemaining,
    required this.totalRemaining,
    this.currentTrack,
    this.trackElapsed = Duration.zero,
    this.isPlaying = false,
    this.isConnecting = true,
    this.isFinished = false,
    this.error,
  });

  factory LivePlayerState.initial(LessonPlan plan) {
    return LivePlayerState(
      plan: plan,
      phaseIndex: 0,
      trackIndex: 0,
      phaseRemaining: plan.phases.first.targetDuration,
      totalRemaining: plan.totalTargetDuration,
    );
  }

  Track? get nextTrack {
    final phase = plan.phases[phaseIndex];
    if (trackIndex + 1 < phase.tracks.length) return phase.tracks[trackIndex + 1];
    if (phaseIndex + 1 < plan.phases.length) {
      final nextPhase = plan.phases[phaseIndex + 1];
      return nextPhase.tracks.isNotEmpty ? nextPhase.tracks.first : null;
    }
    return null;
  }

  LivePlayerState copyWith({
    int? phaseIndex,
    int? trackIndex,
    Track? currentTrack,
    bool clearCurrentTrack = false,
    Duration? trackElapsed,
    Duration? phaseRemaining,
    Duration? totalRemaining,
    bool? isPlaying,
    bool? isConnecting,
    bool? isFinished,
    String? error,
  }) {
    return LivePlayerState(
      plan: plan,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      trackIndex: trackIndex ?? this.trackIndex,
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      trackElapsed: trackElapsed ?? this.trackElapsed,
      phaseRemaining: phaseRemaining ?? this.phaseRemaining,
      totalRemaining: totalRemaining ?? this.totalRemaining,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      isFinished: isFinished ?? this.isFinished,
      error: error,
    );
  }
}

/// Guida la riproduzione della lezione.
///
/// Nota sul design: l'App Remote SDK di Spotify non espone un evento
/// affidabile "traccia terminata" multipiattaforma, quindi NON ci basiamo
/// sulla coda interna di Spotify. Al contrario, riproduciamo un brano alla
/// volta con `play(uri)` e usiamo un timer locale, calcolato sulla durata
/// nota del brano (`track.duration`, presa dai metadati Spotify), per
/// decidere quando passare al successivo. Lo stream `subscribePlayerState`
/// viene comunque ascoltato per riflettere play/pause reali (es. se
/// l'istruttore mette in pausa direttamente dall'app Spotify).
class LivePlayerController extends StateNotifier<LivePlayerState> {
  final SpotifyRemoteService _remote;
  Timer? _ticker;
  StreamSubscription<sdk.PlayerState>? _remoteStateSub;

  LivePlayerController(this._remote, LessonPlan plan)
      : super(LivePlayerState.initial(plan)) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _remote.connect();
      state = state.copyWith(isConnecting: false);
      _remoteStateSub = _remote.subscribePlayerState().listen(
            _onRemoteState,
            onError: (_) {}, // non fatale: continuiamo a guidare col timer locale
          );
      await _playTrackAt(phaseIndex: 0, trackIndex: 0);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  void _onRemoteState(sdk.PlayerState ps) {
    state = state.copyWith(isPlaying: !ps.isPaused);
  }

  Future<void> _playTrackAt({required int phaseIndex, required int trackIndex}) async {
    final phase = state.plan.phases[phaseIndex];
    if (trackIndex >= phase.tracks.length) {
      // Scaletta della fase più corta della durata target: nessun brano da
      // avviare, si aspetta comunque lo scadere del timer di fase.
      state = state.copyWith(clearCurrentTrack: true, trackElapsed: Duration.zero);
      return;
    }
    final track = phase.tracks[trackIndex];
    try {
      await _remote.play(track.uri);
    } catch (e) {
      state = state.copyWith(error: 'Impossibile avviare "${track.title}": $e');
      return;
    }
    state = state.copyWith(
      phaseIndex: phaseIndex,
      trackIndex: trackIndex,
      currentTrack: track,
      trackElapsed: Duration.zero,
      isPlaying: true,
    );
  }

  void _tick() {
    if (!state.isPlaying || state.isFinished) return;

    final phaseRemaining = _subtractSecond(state.phaseRemaining);
    final totalRemaining = _subtractSecond(state.totalRemaining);

    if (phaseRemaining <= Duration.zero) {
      _advancePhase();
      return;
    }

    final track = state.currentTrack;
    final elapsed = state.trackElapsed + const Duration(seconds: 1);
    final trackFinished = track != null && elapsed >= track.duration;

    if (trackFinished) {
      state = state.copyWith(phaseRemaining: phaseRemaining, totalRemaining: totalRemaining);
      _playTrackAt(phaseIndex: state.phaseIndex, trackIndex: state.trackIndex + 1);
      return;
    }

    state = state.copyWith(
      trackElapsed: elapsed,
      phaseRemaining: phaseRemaining,
      totalRemaining: totalRemaining,
    );
  }

  Duration _subtractSecond(Duration d) {
    final result = d - const Duration(seconds: 1);
    return result.isNegative ? Duration.zero : result;
  }

  Future<void> _advancePhase() async {
    final nextIndex = state.phaseIndex + 1;
    if (nextIndex >= state.plan.phases.length) {
      await _remote.pause();
      _ticker?.cancel();
      state = state.copyWith(
        isPlaying: false,
        isFinished: true,
        phaseRemaining: Duration.zero,
        totalRemaining: Duration.zero,
      );
      return;
    }
    final nextPhase = state.plan.phases[nextIndex];
    state = state.copyWith(phaseIndex: nextIndex, phaseRemaining: nextPhase.targetDuration);
    await _playTrackAt(phaseIndex: nextIndex, trackIndex: 0);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _remote.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _remote.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> skipToNextTrack() async {
    await _playTrackAt(phaseIndex: state.phaseIndex, trackIndex: state.trackIndex + 1);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remoteStateSub?.cancel();
    _remote.disconnect();
    super.dispose();
  }
}

final livePlayerControllerProvider = StateNotifierProvider.autoDispose
    .family<LivePlayerController, LivePlayerState, String>((ref, lessonId) {
  final plan = ref.watch(lessonRepositoryProvider).getLesson(lessonId);
  if (plan == null) {
    throw StateError('Lezione "$lessonId" non trovata in libreria.');
  }
  return LivePlayerController(ref.watch(spotifyRemoteServiceProvider), plan);
});
