/// Le tre fasi fisse di una lezione di acquagym.
enum PhaseType { warmup, core, stretching }

extension PhaseTypeX on PhaseType {
  String get label {
    switch (this) {
      case PhaseType.warmup:
        return 'Riscaldamento';
      case PhaseType.core:
        return 'Core allenamento';
      case PhaseType.stretching:
        return 'Stretching finale';
    }
  }

  /// Range BPM suggerito di default quando l'istruttore crea una nuova
  /// lezione da zero. Restano comunque modificabili nel Lesson Builder.
  (int, int) get defaultBpmRange {
    switch (this) {
      case PhaseType.warmup:
        return (100, 115);
      case PhaseType.core:
        return (125, 140);
      case PhaseType.stretching:
        return (80, 95);
    }
  }

  /// Quota di default della durata totale della lezione, usata per
  /// pre-compilare il form quando l'utente inserisce solo la durata totale.
  double get defaultShareOfTotal {
    switch (this) {
      case PhaseType.warmup:
        return 0.2;
      case PhaseType.core:
        return 0.6;
      case PhaseType.stretching:
        return 0.2;
    }
  }
}
