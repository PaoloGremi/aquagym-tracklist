import 'dart:math';

import 'package:aquagym_tracklist/domain/models/phase_type.dart';

import '../models/lesson_phase.dart';
import '../models/lesson_plan.dart';
import '../models/track.dart';

/// Esito della generazione: la lezione con le scalette popolate + eventuali
/// avvisi (es. "non ci sono abbastanza brani taggati per riempire il core").
class SetlistGenerationResult {
  final LessonPlan plan;
  final List<String> warnings;

  const SetlistGenerationResult({required this.plan, required this.warnings});
}

/// Algoritmo di generazione automatica della scaletta.
///
/// Per ciascuna fase:
/// 1. filtra i brani della libreria che sono taggati con BPM e rientrano nel
///    range [bpmMin, bpmMax] della fase;
/// 2. dà priorità ai brani non ancora usati in altre fasi della stessa
///    lezione (per evitare ripetizioni), ma permette il riuso se altrimenti
///    non si raggiungerebbe la durata target;
/// 3. mescola i candidati (per variare la scaletta a ogni generazione) e li
///    accoda finché la durata totale copre la durata target entro la
///    tolleranza indicata, evitando di sforare eccessivamente l'ultima
///    aggiunta.
///
/// Se anche usando tutti i candidati disponibili non si copre la fase,
/// la scaletta risultante è "best effort" (tutti i candidati disponibili)
/// e viene generato un warning: la UI deve mostrarlo e invitare l'istruttore
/// a taggare altri brani in quel range di BPM.
class GenerateSetlistUseCase {
  final Random _random;

  GenerateSetlistUseCase({Random? random}) : _random = random ?? Random();

  List<Track> generateForPhase({
    required List<Track> library,
    required LessonPhase phase,
    required Set<String> alreadyUsedTrackIds,
    Duration tolerance = const Duration(seconds: 20),
  }) {
    final allCandidates = library
        .where((t) => t.matchesBpmRange(phase.bpmMin, phase.bpmMax))
        .toList();

    final unused = allCandidates
        .where((t) => !alreadyUsedTrackIds.contains(t.spotifyId))
        .toList()
      ..shuffle(_random);
    final used = allCandidates
        .where((t) => alreadyUsedTrackIds.contains(t.spotifyId))
        .toList()
      ..shuffle(_random);

    // Preferiamo sempre brani non ancora usati; se non bastano, peschiamo
    // anche da quelli già usati altrove pur di riempire la fase.
    final orderedCandidates = [...unused, ...used];

    final selected = <Track>[];
    var accumulated = Duration.zero;

    for (final track in orderedCandidates) {
      if (accumulated >= phase.targetDuration - tolerance) break;

      // Evita di sforare troppo: se aggiungendo questo brano si supera la
      // durata target di più della tolleranza E abbiamo già almeno un
      // brano selezionato, proviamo prima a cercare un brano più corto
      // tra i rimanenti prima di accettare lo sforamento.
      final wouldBe = accumulated + track.duration;
      if (selected.isNotEmpty &&
          wouldBe > phase.targetDuration + tolerance) {
        final shorterAlt = orderedCandidates.firstWhere(
          (t) =>
              !selected.contains(t) &&
              accumulated + t.duration <= phase.targetDuration + tolerance,
          orElse: () => track,
        );
        selected.add(shorterAlt);
        accumulated += shorterAlt.duration;
        continue;
      }

      selected.add(track);
      accumulated += track.duration;
    }

    return selected;
  }

  SetlistGenerationResult generateLessonSetlist({
    required LessonPlan plan,
    required List<Track> library,
    Duration tolerance = const Duration(seconds: 20),
  }) {
    final warnings = <String>[];
    final usedIds = <String>{};
    final newPhases = <LessonPhase>[];

    for (final phase in plan.phases) {
      final tracks = generateForPhase(
        library: library,
        phase: phase,
        alreadyUsedTrackIds: usedIds,
        tolerance: tolerance,
      );
      usedIds.addAll(tracks.map((t) => t.spotifyId));

      final updatedPhase = phase.copyWith(tracks: tracks);
      newPhases.add(updatedPhase);

      if (!updatedPhase.isFilled(tolerance: tolerance)) {
        final missing = updatedPhase.shortfall;
        warnings.add(
          'Fase "${phase.type.label}": mancano brani taggati nel range '
          '${phase.bpmMin}-${phase.bpmMax} BPM. Coperti '
          '${_fmt(updatedPhase.actualDuration)} su ${_fmt(phase.targetDuration)} '
          '(mancano ~${_fmt(missing)}). Tagga altri brani in questo range.',
        );
      }
    }

    return SetlistGenerationResult(
      plan: plan.copyWith(phases: newPhases),
      warnings: warnings,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
