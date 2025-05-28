import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing firmware templates
class TemplateService {
  /// Base directory for storing firmware templates
  String? _templatesDir;

  /// Constructor initializes the templates directory
  TemplateService() {
    _initTemplatesDir();
  }

  /// Initialize the templates directory
  Future<void> _initTemplatesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _templatesDir = path.join(appDir.path, 'firmware_templates');

    // Create directory if it doesn't exist
    final dir = Directory(_templatesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Get a firmware template - will download if not available locally
  Future<String?> getFirmwareTemplate(
    String firmwareVersion,
    String deviceType,
  ) async {
    // First, check if we have the template locally
    final localPath = await _getLocalTemplatePath(firmwareVersion, deviceType);
    if (localPath != null && await File(localPath).exists()) {
      return localPath;
    }

    // If not available locally, try to download it
    return await _downloadTemplate(firmwareVersion, deviceType);
  }

  /// Get the local path for a template if it exists
  Future<String?> _getLocalTemplatePath(
    String firmwareVersion,
    String deviceType,
  ) async {
    if (_templatesDir == null) {
      await _initTemplatesDir();
    }

    final deviceTypeDir = path.join(_templatesDir!, deviceType);
    final directoryExists = await Directory(deviceTypeDir).exists();

    if (!directoryExists) {
      return null;
    }

    // Construct file name from version
    final fileName = '${firmwareVersion.replaceAll('.', '_')}.ino';
    final filePath = path.join(deviceTypeDir, fileName);

    // Check if file exists
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    return null;
  }

  /// Download a firmware template from the API
  Future<String?> _downloadTemplate(
    String firmwareVersion,
    String deviceType,
  ) async {
    try {
      // In a real implementation, you would fetch from your actual API
      // For now, we'll just return a mock template or use a local default

      // Create device type directory if needed
      final deviceTypeDir = path.join(_templatesDir!, deviceType);
      final directory = Directory(deviceTypeDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Target file path
      final fileName = '${firmwareVersion.replaceAll('.', '_')}.ino';
      final filePath = path.join(deviceTypeDir, fileName);

      // Check if we have a default template to copy
      final defaultTemplatePath = await _getDefaultTemplatePath(deviceType);
      if (defaultTemplatePath != null) {
        // Copy the default template
        await File(defaultTemplatePath).copy(filePath);
        return filePath;
      }

      // If no default, create a simple template
      final file = File(filePath);
      await file.writeAsString(_getDefaultTemplateContent(firmwareVersion, deviceType));
      return filePath;
    } catch (e) {
      print('Error downloading template: $e');
      return null;
    }
  }

  /// Get the path to a default template based on device type
  Future<String?> _getDefaultTemplatePath(String deviceType) async {
    try {
      // Look for a default template in the app's assets
      final directories = [
        'lib/firmware_template',
        'assets/firmware_template',
      ];

      for (final dir in directories) {
        final defaultTemplate = File('$dir/${deviceType.toLowerCase()}_template.ino');
        if (await defaultTemplate.exists()) {
          return defaultTemplate.path;
        }
      }

      // If no device-specific template, try a generic one
      for (final dir in directories) {
        final genericTemplate = File('$dir/led_template.ino');
        if (await genericTemplate.exists()) {
          return genericTemplate.path;
        }
      }

      return null;
    } catch (e) {
      print('Error finding default template: $e');
      return null;
    }
  }

  /// Generate a simple default template if no other template is available
  String _getDefaultTemplateContent(String version, String deviceType) {
    return '''
// Default firmware template for $deviceType - version $version
// Generated automatically

String deviceSerial = "{{SERIAL_NUMBER}}";

void setup() {
  Serial.begin(115200);
  Serial.println("Device initialized");
  Serial.print("Device Serial: ");
  Serial.println(deviceSerial);
  
  // Initialize pins
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  // Simple blink pattern
  digitalWrite(LED_BUILTIN, HIGH);
  delay(500);
  digitalWrite(LED_BUILTIN, LOW);
  delay(500);
}
''';
  }

  /// List all available firmware versions for a device type
  Future<List<String>> listAvailableFirmwareVersions(String deviceType) async {
    final result = <String>[];

    // Check the directory for this device type
    if (_templatesDir == null) {
      await _initTemplatesDir();
    }

    final deviceTypeDir = path.join(_templatesDir!, deviceType);
    final directory = Directory(deviceTypeDir);

    if (await directory.exists()) {
      await for (final file in directory.list()) {
        if (file is File && file.path.endsWith('.ino')) {
          // Extract version from filename
          final fileName = path.basename(file.path);
          final version = fileName.replaceAll('_', '.').replaceAll('.ino', '');
          result.add(version);
        }
      }
    }

    // Add some default versions if empty
    if (result.isEmpty) {
      result.addAll(['1.0.0', '1.1.0', '2.0.0']);
    }

    return result;
  }

  /// Delete a firmware template
  Future<bool> deleteTemplate(String firmwareVersion, String deviceType) async {
    final templatePath = await _getLocalTemplatePath(firmwareVersion, deviceType);
    if (templatePath != null) {
      final file = File(templatePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    }
    return false;
  }

  /// Prepare a firmware template by replacing placeholders with actual values
  Future<String?> prepareFirmwareTemplate(
    String templatePath,
    String serialNumber,
    String deviceId,
  ) async {
    try {
      // Read the template
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        print('Template file not found: $templatePath');
        return null;
      }

      // Read template content
      String templateContent = await templateFile.readAsString();

      // Replace placeholders - assuming {{SERIAL_NUMBER}} is the placeholder
      templateContent = templateContent.replaceAll('{{SERIAL_NUMBER}}', serialNumber);

      // Create a temporary file for compilation
      final tempDir = await getTemporaryDirectory();
      final compilePath = path.join(tempDir.path, 'compile_$serialNumber.ino');
      final compileFile = File(compilePath);
      await compileFile.writeAsString(templateContent);

      print('Template prepared for device $serialNumber');
      return compilePath;
    } catch (e) {
      print('Error preparing template: $e');
      return null;
    }
  }
}