import 'lesson_phase.dart';
import 'phase_type.dart';
import 'track.dart';

/// Una lezione: nome, durata totale e le tre fasi (sempre in ordine
/// warmup -> core -> stretching) ciascuna con la propria scaletta.
class LessonPlan {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<LessonPhase> phases;

  const LessonPlan({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.phases,
  });

  Duration get totalTargetDuration =>
      phases.fold(Duration.zero, (sum, p) => sum + p.targetDuration);

  Duration get totalActualDuration =>
      phases.fold(Duration.zero, (sum, p) => sum + p.actualDuration);

  LessonPhase phaseOf(PhaseType type) =>
      phases.firstWhere((p) => p.type == type);

  List<Track> get allTracksInOrder => phases.expand((p) => p.tracks).toList();

  bool get isFullyFilled => phases.every((p) => p.isFilled());

  LessonPlan copyWith({
    String? name,
    List<LessonPhase>? phases,
  }) {
    return LessonPlan(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      phases: phases ?? this.phases,
    );
  }

  /// Sostituisce la fase di un certo tipo con una nuova versione
  /// (utile per l'editor manuale della scaletta).
  LessonPlan withPhase(LessonPhase updated) {
    return copyWith(
      phases: [
        for (final p in phases) if (p.type == updated.type) updated else p,
      ],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'phases': phases.map((p) => p.toDbMap()).toList(),
    };
  }

  factory LessonPlan.fromDbMap(
    Map map,
    Track? Function(String spotifyId) trackResolver,
  ) {
    final rawPhases = List<Map>.from(map['phases'] as List);
    return LessonPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      phases: rawPhases
          .map((p) => LessonPhase.fromDbMap(p, trackResolver))
          .toList(),
    );
  }
}
