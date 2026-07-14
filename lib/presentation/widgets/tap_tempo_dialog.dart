import 'package:flutter/material.dart';

import '../../domain/models/phase_type.dart';
import '../../domain/models/track.dart';

/// Dialog per taggare manualmente il BPM di un brano: input numerico
/// diretto oppure calcolo tramite "tap tempo" (l'istruttore batte il tempo
/// a schermo e l'app calcola i BPM dall'intervallo medio tra i tap).
///
/// Ritorna una mappa {'bpm': int, 'preferredPhase': PhaseType?} se
/// confermato, altrimenti null.
class TapTempoDialog extends StatefulWidget {
  final Track track;

  const TapTempoDialog({super.key, required this.track});

  @override
  State<TapTempoDialog> createState() => _TapTempoDialogState();
}

class _TapTempoDialogState extends State<TapTempoDialog> {
  final List<DateTime> _taps = [];
  late final TextEditingController _bpmController;
  PhaseType? _preferredPhase;

  static const int _maxTapsConsidered = 8;

  @override
  void initState() {
    super.initState();
    _bpmController = TextEditingController(
      text: widget.track.bpm?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _onTap() {
    final now = DateTime.now();
    _taps.add(now);
    if (_taps.length > _maxTapsConsidered) {
      _taps.removeAt(0);
    }
    if (_taps.length >= 2) {
      final intervals = <Duration>[];
      for (var i = 1; i < _taps.length; i++) {
        intervals.add(_taps[i].difference(_taps[i - 1]));
      }
      final avgMs =
          intervals.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / intervals.length;
      if (avgMs > 0) {
        final bpm = (60000 / avgMs).round();
        _bpmController.text = bpm.clamp(30, 220).toString();
      }
    }
    setState(() {});
  }

  void _resetTaps() {
    _taps.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final parsedBpm = int.tryParse(_bpmController.text);

    return AlertDialog(
      title: Text('Tagga BPM · ${widget.track.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bpmController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'BPM'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _onTap,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
            child: Text(
              _taps.isEmpty ? 'Batti il tempo qui' : 'Tap! (${_taps.length})',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          if (_taps.isNotEmpty)
            TextButton(onPressed: _resetTaps, child: const Text('Ricomincia il tap tempo')),
          const SizedBox(height: 12),
          DropdownButtonFormField<PhaseType?>(
            value: _preferredPhase ?? widget.track.preferredPhase,
            decoration: const InputDecoration(labelText: 'Fase preferita (opzionale)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nessuna preferenza')),
              ...PhaseType.values.map(
                (p) => DropdownMenuItem(value: p, child: Text(p.label)),
              ),
            ],
            onChanged: (v) => setState(() => _preferredPhase = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: parsedBpm == null || parsedBpm <= 0
              ? null
              : () => Navigator.of(context).pop({
                    'bpm': parsedBpm,
                    'preferredPhase': _preferredPhase ?? widget.track.preferredPhase,
                  }),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
