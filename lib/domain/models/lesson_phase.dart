import 'phase_type.dart';
import 'track.dart';

/// Una fase della lezione (riscaldamento / core / stretching) con la sua
/// durata target, il range di BPM richiesto e la scaletta di brani assegnata.
class LessonPhase {
  final PhaseType type;
  final Duration targetDuration;
  final int bpmMin;
  final int bpmMax;
  final List<Track> tracks;

  const LessonPhase({
    required this.type,
    required this.targetDuration,
    required this.bpmMin,
    required this.bpmMax,
    this.tracks = const [],
  });

  Duration get actualDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);

  Duration get shortfall {
    final diff = targetDuration - actualDuration;
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Vero se la scaletta attuale copre la durata richiesta entro la
  /// tolleranza passata (di default 20s, vedi AppConfig).
  bool isFilled({Duration tolerance = const Duration(seconds: 20)}) {
    return actualDuration >= targetDuration - tolerance;
  }

  LessonPhase copyWith({
    Duration? targetDuration,
    int? bpmMin,
    int? bpmMax,
    List<Track>? tracks,
  }) {
    return LessonPhase(
      type: type,
      targetDuration: targetDuration ?? this.targetDuration,
      bpmMin: bpmMin ?? this.bpmMin,
      bpmMax: bpmMax ?? this.bpmMax,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'type': type.name,
      'targetSeconds': targetDuration.inSeconds,
      'bpmMin': bpmMin,
      'bpmMax': bpmMax,
      'trackIds': tracks.map((t) => t.spotifyId).toList(),
    };
  }

  /// [trackResolver] recupera un [Track] completo (con eventuale BPM
  /// aggiornato) a partire dal suo id, leggendo dalla libreria locale.
  /// Se un brano salvato in una lezione non esiste più in libreria viene
  /// semplicemente scartato dalla scaletta ricostruita.
  factory LessonPhase.fromDbMap(
    Map map,
    Track? Function(String spotifyId) trackResolver,
  ) {
    final ids = List<String>.from(map['trackIds'] as List? ?? const []);
    final tracks = ids.map(trackResolver).whereType<Track>().toList();
    return LessonPhase(
      type: PhaseType.values.byName(map['type'] as String),
      targetDuration: Duration(seconds: map['targetSeconds'] as int),
      bpmMin: map['bpmMin'] as int,
      bpmMax: map['bpmMax'] as int,
      tracks: tracks,
    );
  }
}
