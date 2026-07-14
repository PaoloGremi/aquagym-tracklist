import 'package:flutter/material.dart';

/// Tema dell'app: palette ad alto contrasto e tipografia grande, pensata
/// per essere leggibile a distanza (bordo vasca, luce riflessa sull'acqua,
/// istruttore che non può avvicinarsi troppo al telefono).
///
/// Palette ripresa dal branding "Aquamore": teal su sfondo quasi nero.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF1FB6A8); // teal "Aquamore"
  static const Color _backgroundDark = Color(0xFF121417);
  static const Color _surfaceDark = Color(0xFF1B1F22);
  static const Color warmupColor = Color(0xFFFFA000); // arancio: riscaldamento
  static const Color coreColor = Color(0xFFE53935); // rosso: core/intensità
  static const Color stretchColor = Color(0xFF43A047); // verde: stretching

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(surface: _surfaceDark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundDark,
        foregroundColor: scheme.onSurface,
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
        color: _surfaceDark,
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
