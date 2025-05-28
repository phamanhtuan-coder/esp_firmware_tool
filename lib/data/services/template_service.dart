import 'dart:io';
import 'dart:math' as math; // Import dart:math with an alias
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class TemplateService {
  static const String templateAssetPath = 'lib/firmware_template/led_template.ino';

  /// Loads the template firmware code and replaces placeholders with actual values
  Future<String> prepareTemplate({
    required String serialNumber,
    String? ssid,
    String? password,
    String? serverHost,
    int serverPort = 3000,
  }) async {
    try {
      // Load the template from assets
      final templateContent = await rootBundle.loadString(templateAssetPath);

      // Generate a UUID for this device
      final uuid = Uuid();
      final deviceUuid = uuid.v4();

      // Create an AP SSID based on the serial number
      final apSsid = 'ESP_${serialNumber.substring(math.max(0, serialNumber.length - 6))}';

      // Replace all placeholders in the template
      final processedTemplate = templateContent
          .replaceAll('{{DEVICE_ID}}', serialNumber)
          .replaceAll('{{DEVICE_UUID}}', deviceUuid)
          .replaceAll('{{AP_SSID}}', apSsid)
          .replaceAll('{{DEFAULT_SSID}}', ssid ?? 'YourNetwork')
          .replaceAll('{{DEFAULT_PASSWORD}}', password ?? 'YourPassword')
          .replaceAll('{{SERVER_HOST}}', serverHost ?? '192.168.1.100')
          .replaceAll('{{SERVER_PORT}}', serverPort.toString());

      // Create a temporary file with the processed template
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, 'processed_template.ino');

      final file = File(tempPath);
      await file.writeAsString(processedTemplate);

      return tempPath;
    } catch (e) {
      throw Exception('Failed to prepare template: $e');
    }
  }
}