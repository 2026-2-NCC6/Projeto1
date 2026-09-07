import 'package:flutter/material.dart';

/// Paleta inspirada no Spotify: fundo preto, verde de destaque, texto branco.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color surfaceElevated2 = Color(0xFF212121);
  static const Color border = Color(0xFF2A2A2A);

  static const Color green = Color(0xFF1DB954);
  static const Color greenDark = Color(0xFF169C46);
  static const Color greenBright = Color(0xFF1ED760);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF6A6A6A);

  static const Color error = Color(0xFFE84545);
  static const Color warning = Color(0xFFF2B705);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A3324), Color(0xFF000000)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenBright, greenDark],
  );
}
