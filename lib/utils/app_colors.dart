import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1976D2);
  static const Color accent = Color(0xFF42A5F5);
  static const Color background = Color(0xFFF5F5F5);
  static const Color text = Color(0xFF212121);

  // Status colors
  static const Color connected = Color(0xFF2196F3); // Blue
  static const Color compiling = Color(0xFFFFA726); // Orange
  static const Color flashing = Color(0xFF9C27B0); // Purple
  static const Color done = Color(0xFF4CAF50); // Green
  static const Color error = Color(0xFFE53935); // Red
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107); // Yellow
  static const Color info = Color(0xFF2196F3); // Blue

  // Additional UI colors
  static const Color idle = Color(0xFF757575); // Grey
  static const Color cardBackground = Colors.white;
  static const Color shadowColor = Color(0x1F000000); // 12% black
  static const Color dividerColor = Color(0xFFEEEEEE);
  static const Color buttonPressed = Color(
    0xFF1565C0,
  ); // Darker blue for pressed state
  static const Color buttonDisabled = Color(0xFFBDBDBD);
  static const Color buttonHover = Color(
    0xFF90CAF9,
  ); // Lighter blue for hover state
  static const Color findFile = Color(0xFF42A5F5); // Blue
  static const Color selectVersion = Color(0xFF4CAF50); // Green
  static const Color refresh = Color(0xFFFFA726); // Orange
  static const Color scanQr = Color(0xFF9C27B0); // Purple

  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212); // Material dark background
  static const Color darkSurface = Color(0xFF1E1E1E); // Dark surface color
  static const Color darkCardBackground = Color(0xFF2D2D2D); // Slightly lighter than surface
  static const Color darkDivider = Color(0xFF3D3D3D);
  static const Color darkHeaderBackground = Color(0xFF0D47A1); // Deeper blue for headers in dark mode
  static const Color darkTabBackground = Color(0xFF333333);
  static const Color darkPanelBackground = Color(0xFF252525);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);
}