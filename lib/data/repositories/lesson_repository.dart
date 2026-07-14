import 'package:uuid/uuid.dart';

import '../../domain/models/lesson_phase.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/phase_type.dart';
import '../../domain/models/track.dart';
import '../../domain/usecases/generate_setlist_usecase.dart';
import '../local_db/local_database.dart';

/// Gestisce le lezioni salvate (template riutilizzabili) e la loro
/// generazione automatica tramite [GenerateSetlistUseCase].
class LessonRepository {
  final LocalDatabase _db;
  final GenerateSetlistUseCase _generator;
  final Uuid _uuid = const Uuid();

  LessonRepository(this._db, this._generator);

  List<LessonPlan> getAllLessons() => _db.getAllLessons();

  LessonPlan? getLesson(String id) => _db.getLesson(id);

  /// Crea una nuova bozza di lezione con le tre fasi vuote (nessun brano
  /// ancora assegnato), pronta per essere passata al generatore o
  /// popolata manualmente.
  LessonPlan createDraft({
    required String name,
    required Map<PhaseType, Duration> phaseDurations,
    required Map<PhaseType, (int, int)> phaseBpmRanges,
  }) {
    return LessonPlan(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      phases: [
        for (final type in PhaseType.values)
          LessonPhase(
            type: type,
            targetDuration: phaseDurations[type] ?? Duration.zero,
            bpmMin: phaseBpmRanges[type]?.$1 ?? type.defaultBpmRange.$1,
            bpmMax: phaseBpmRanges[type]?.$2 ?? type.defaultBpmRange.$2,
          ),
      ],
    );
  }

  /// Genera (o rigenera) la scaletta di [draft] pescando dai brani taggati
  /// in [library]. Non salva automaticamente: la UI mostra il risultato
  /// nell'editor e l'istruttore conferma con [save].
  SetlistGenerationResult generateSetlist({
    required LessonPlan draft,
    required List<Track> library,
  }) {
    return _generator.generateLessonSetlist(plan: draft, library: library);
  }

  Future<void> save(LessonPlan plan) => _db.upsertLesson(plan);

  Future<void> delete(String id) => _db.deleteLesson(id);
}
