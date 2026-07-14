import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Timer a caratteri grandi, pensato per essere letto a distanza (bordo
/// vasca). Mostra mm:ss con font monospaziato per evitare che i numeri
/// "ballino" larghezza a ogni tick.
class BigTimerWidget extends StatelessWidget {
  final Duration remaining;
  final String label;
  final Color color;

  const BigTimerWidget({
    super.key,
    required this.remaining,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    final text = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w800,
            fontFeatures: [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
