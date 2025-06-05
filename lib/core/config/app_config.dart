class AppConfig {
  static const String socketUrl = 'http://localhost:3000';
  static const int socketTimeout = 5000;
  static const int socketReconnectAttempts = 3;

  // Device Status Messages
  static const String deviceConnected = 'Device connected successfully';
  static const String deviceDisconnected = 'Device disconnected';
  static const String compilationStarted = 'Starting compilation';
  static const String compilationCompleted = 'Compilation completed';
  static const String flashingStarted = 'Starting firmware flash';
  static const String flashingCompleted = 'Firmware flash completed';
  static const String errorOccurred = 'An error occurred';

  // UI Constants
  static const double maxContentWidth = 500.0;
  static const double cardBorderRadius = 12.0;
  static const double defaultPadding = 16.0;

  // File Types
  static const List<String> allowedTemplateExtensions = ['.bin', '.hex'];
}