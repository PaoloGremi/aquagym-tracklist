import 'package:flutter/material.dart';

/// Tema dell'app: palette ad alto contrasto e tipografia grande, pensata
/// per essere leggibile a distanza (bordo vasca, luce riflessa sull'acqua,
/// istruttore che non può avvicinarsi troppo al telefono).
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF00B8D9); // azzurro "acqua"
  static const Color warmupColor = Color(0xFFFFA000); // arancio: riscaldamento
  static const Color coreColor = Color(0xFFE53935); // rosso: core/intensità
  static const Color stretchColor = Color(0xFF43A047); // verde: stretching

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Colore associato a ciascuna fase lezione, usato in tutta la UI
  /// (badge, progress indicator, schermata live) per riconoscimento immediato.
  static Color colorForPhase(String phaseTypeName) {
    switch (phaseTypeName) {
      case 'warmup':
        return warmupColor;
      case 'core':
        return coreColor;
      case 'stretching':
        return stretchColor;
      default:
        return _seed;
    }
  }
}
