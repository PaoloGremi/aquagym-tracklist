import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/phase_type.dart';
import '../../domain/models/track.dart';
import 'core_providers.dart';

class LessonBuilderState {
  final String name;
  final Map<PhaseType, Duration> durations;
  final Map<PhaseType, (int, int)> bpmRanges;
  final LessonPlan? generatedPlan;
  final List<String> warnings;
  final bool isGenerating;

  const LessonBuilderState({
    required this.name,
    required this.durations,
    required this.bpmRanges,
    this.generatedPlan,
    this.warnings = const [],
    this.isGenerating = false,
  });

  factory LessonBuilderState.initial() {
    const defaultTotal = Duration(minutes: 45);
    return LessonBuilderState(
      name: 'Nuova lezione',
      durations: {
        for (final t in PhaseType.values)
          t: Duration(
            seconds: (defaultTotal.inSeconds * t.defaultShareOfTotal).round(),
          ),
      },
      bpmRanges: {
        for (final t in PhaseType.values) t: t.defaultBpmRange,
      },
    );
  }

  Duration get totalDuration =>
      durations.values.fold(Duration.zero, (a, b) => a + b);

  LessonBuilderState copyWith({
    String? name,
    Map<PhaseType, Duration>? durations,
    Map<PhaseType, (int, int)>? bpmRanges,
    LessonPlan? generatedPlan,
    List<String>? warnings,
    bool? isGenerating,
  }) {
    return LessonBuilderState(
      name: name ?? this.name,
      durations: durations ?? this.durations,
      bpmRanges: bpmRanges ?? this.bpmRanges,
      generatedPlan: generatedPlan ?? this.generatedPlan,
      warnings: warnings ?? this.warnings,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

class LessonBuilderController extends StateNotifier<LessonBuilderState> {
  final LessonRepository _lessonRepo;
  final TrackRepository _trackRepo;

  LessonBuilderController(this._lessonRepo, this._trackRepo)
      : super(LessonBuilderState.initial());

  void setName(String name) => state = state.copyWith(name: name);

  /// Imposta la durata totale e ridistribuisce automaticamente le tre fasi
  /// secondo le quote di default (20% / 60% / 20%). L'istruttore può poi
  /// aggiustare manualmente ogni fase con [setPhaseDuration].
  void setTotalDuration(Duration total) {
    state = state.copyWith(durations: {
      for (final t in PhaseType.values)
        t: Duration(seconds: (total.inSeconds * t.defaultShareOfTotal).round()),
    });
  }

  void setPhaseDuration(PhaseType type, Duration duration) {
    state = state.copyWith(durations: {...state.durations, type: duration});
  }

  void setPhaseBpmRange(PhaseType type, int min, int max) {
    state = state.copyWith(bpmRanges: {...state.bpmRanges, type: (min, max)});
  }

  Future<void> generate() async {
    state = state.copyWith(isGenerating: true);
    final draft = _lessonRepo.createDraft(
      name: state.name,
      phaseDurations: state.durations,
      phaseBpmRanges: state.bpmRanges,
    );
    final library = _trackRepo.taggedLibrary;
    final result = _lessonRepo.generateSetlist(draft: draft, library: library);
    state = state.copyWith(
      generatedPlan: result.plan,
      warnings: result.warnings,
      isGenerating: false,
    );
  }

  void removeTrack(PhaseType type, String trackSpotifyId) {
    final plan = state.generatedPlan;
    if (plan == null) return;
    final phase = plan.phaseOf(type);
    final updated = phase.copyWith(
      tracks: phase.tracks.where((t) => t.spotifyId != trackSpotifyId).toList(),
    );
    state = state.copyWith(generatedPlan: plan.withPhase(updated));
  }

  void addTrack(PhaseType type, Track track) {
    final plan = state.generatedPlan;
    if (plan == null) return;
    final phase = plan.phaseOf(type);
    if (phase.tracks.any((t) => t.spotifyId == track.spotifyId)) return;
    final updated = phase.copyWith(tracks: [...phase.tracks, track]);
    state = state.copyWith(generatedPlan: plan.withPhase(updated));
  }

  void reorderTrackInPhase(PhaseType type, int oldIndex, int newIndex) {
    final plan = state.generatedPlan;
    if (plan == null) return;
    final phase = plan.phaseOf(type);
    final tracks = [...phase.tracks];
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = tracks.removeAt(oldIndex);
    tracks.insert(target, moved);
    state = state.copyWith(generatedPlan: plan.withPhase(phase.copyWith(tracks: tracks)));
  }

  Future<void> save() async {
    final plan = state.generatedPlan;
    if (plan == null) {
      throw StateError('Nessuna scaletta generata da salvare.');
    }
    await _lessonRepo.save(plan);
  }

  /// Carica una lezione già salvata nell'editor, per modificarla. Usato da
  /// [SetlistEditorScreen] quando aperta da "Modifica scaletta" sull'elenco
  /// lezioni: la lezione mantiene lo stesso id, quindi [save] la sovrascrive
  /// invece di crearne una nuova.
  void loadExisting(LessonPlan plan) {
    state = state.copyWith(
      name: plan.name,
      durations: {for (final p in plan.phases) p.type: p.targetDuration},
      bpmRanges: {for (final p in plan.phases) p.type: (p.bpmMin, p.bpmMax)},
      generatedPlan: plan,
      warnings: const [],
    );
  }

  void reset() => state = LessonBuilderState.initial();
}

final lessonBuilderControllerProvider = StateNotifierProvider.autoDispose<
    LessonBuilderController, LessonBuilderState>((ref) {
  return LessonBuilderController(
    ref.watch(lessonRepositoryProvider),
    ref.watch(trackRepositoryProvider),
  );
});
