import 'package:flutter_test/flutter_test.dart';
import 'package:aquagym_tracklist/domain/models/lesson_phase.dart';
import 'package:aquagym_tracklist/domain/models/lesson_plan.dart';
import 'package:aquagym_tracklist/domain/models/phase_type.dart';
import 'package:aquagym_tracklist/domain/models/track.dart';
import 'package:aquagym_tracklist/domain/usecases/generate_setlist_usecase.dart';

Track _track(String id, int bpm, int durationSeconds) {
  return Track(
    spotifyId: id,
    uri: 'spotify:track:$id',
    title: 'Track $id',
    artist: 'Artist $id',
    duration: Duration(seconds: durationSeconds),
    bpm: bpm,
  );
}

void main() {
  group('GenerateSetlistUseCase.generateForPhase', () {
    test('seleziona solo brani nel range BPM richiesto', () {
      final usecase = GenerateSetlistUseCase();
      final library = [
        _track('a', 90, 180), // fuori range (troppo lento)
        _track('b', 128, 180),
        _track('c', 132, 180),
        _track('d', 160, 180), // fuori range (troppo veloce)
      ];
      final phase = LessonPhase(
        type: PhaseType.core,
        targetDuration: const Duration(minutes: 6),
        bpmMin: 125,
        bpmMax: 140,
      );

      final result = usecase.generateForPhase(
        library: library,
        phase: phase,
        alreadyUsedTrackIds: {},
      );

      expect(result.every((t) => t.bpm! >= 125 && t.bpm! <= 140), isTrue);
      expect(result.map((t) => t.spotifyId), containsAll(['b', 'c']));
      expect(result.map((t) => t.spotifyId), isNot(contains('a')));
      expect(result.map((t) => t.spotifyId), isNot(contains('d')));
    });

    test('ignora i brani non taggati (bpm null)', () {
      final usecase = GenerateSetlistUseCase();
      final library = [
        Track(
          spotifyId: 'untagged',
          uri: 'spotify:track:untagged',
          title: 'No BPM',
          artist: 'Someone',
          duration: const Duration(seconds: 180),
        ),
        _track('tagged', 130, 180),
      ];
      final phase = LessonPhase(
        type: PhaseType.core,
        targetDuration: const Duration(minutes: 3),
        bpmMin: 120,
        bpmMax: 140,
      );

      final result = usecase.generateForPhase(
        library: library,
        phase: phase,
        alreadyUsedTrackIds: {},
      );

      expect(result.map((t) => t.spotifyId), equals(['tagged']));
    });

    test('copre la durata richiesta entro la tolleranza', () {
      final usecase = GenerateSetlistUseCase();
      final library = List.generate(10, (i) => _track('t$i', 130, 60));
      final phase = LessonPhase(
        type: PhaseType.core,
        targetDuration: const Duration(minutes: 5),
        bpmMin: 120,
        bpmMax: 140,
      );

      final result = usecase.generateForPhase(
        library: library,
        phase: phase,
        alreadyUsedTrackIds: {},
        tolerance: const Duration(seconds: 20),
      );

      final total = result.fold(Duration.zero, (sum, t) => sum + t.duration);
      expect(total >= phase.targetDuration - const Duration(seconds: 20), isTrue);
    });

    test('segnala shortfall quando non ci sono abbastanza brani taggati', () {
      final usecase = GenerateSetlistUseCase();
      final library = [_track('only', 130, 60)];
      final plan = LessonPlan(
        id: 'lesson-1',
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        phases: [
          LessonPhase(
            type: PhaseType.warmup,
            targetDuration: const Duration(minutes: 10),
            bpmMin: 120,
            bpmMax: 140,
          ),
          LessonPhase(
            type: PhaseType.core,
            targetDuration: const Duration(minutes: 1),
            bpmMin: 60,
            bpmMax: 70,
          ),
          LessonPhase(
            type: PhaseType.stretching,
            targetDuration: const Duration(minutes: 1),
            bpmMin: 60,
            bpmMax: 70,
          ),
        ],
      );

      final result = usecase.generateLessonSetlist(plan: plan, library: library);

      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('Riscaldamento'));
    });

    test('non ripete un brano già usato in un\'altra fase se ce ne sono di alternativi', () {
      final usecase = GenerateSetlistUseCase();
      final library = [
        _track('shared', 130, 300),
        _track('alt', 130, 300),
      ];
      final plan = LessonPlan(
        id: 'lesson-2',
        name: 'Test2',
        createdAt: DateTime(2026, 1, 1),
        phases: [
          LessonPhase(
            type: PhaseType.warmup,
            targetDuration: const Duration(minutes: 5),
            bpmMin: 120,
            bpmMax: 140,
          ),
          LessonPhase(
            type: PhaseType.core,
            targetDuration: const Duration(minutes: 5),
            bpmMin: 120,
            bpmMax: 140,
          ),
          LessonPhase(
            type: PhaseType.stretching,
            targetDuration: Duration.zero,
            bpmMin: 60,
            bpmMax: 70,
          ),
        ],
      );

      final result = usecase.generateLessonSetlist(plan: plan, library: library);
      final warmupIds = result.plan.phaseOf(PhaseType.warmup).tracks.map((t) => t.spotifyId).toSet();
      final coreIds = result.plan.phaseOf(PhaseType.core).tracks.map((t) => t.spotifyId).toSet();

      expect(warmupIds.intersection(coreIds), isEmpty);
    });
  });
}
