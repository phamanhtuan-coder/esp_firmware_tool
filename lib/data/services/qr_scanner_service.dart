import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';

/// Class to parse QR code data
class QrData {
  final String serialNumber;
  final String? batchProductionId;
  final String? templateId;

  QrData({
    required this.serialNumber,
    this.batchProductionId,
    this.templateId,
  });

  factory QrData.fromJson(Map<String, dynamic> json) {
    return QrData(
      serialNumber: json['serial_number'] as String? ?? '',
      batchProductionId: json['batch_production_id'] as String?,
      templateId: json['template_id'] as String?,
    );
  }

  @override
  String toString() => 'QrData(serialNumber: $serialNumber, batchId: $batchProductionId, templateId: $templateId)';
}

/// Service to handle QR code scanning functionality
class QrScannerService {
  final LogService _logService;

  QrScannerService() : _logService = GetIt.instance<LogService>();

  /// Parse QR code data from raw string
  QrData? parseQrData(String rawData) {
    try {
      // Try to parse as JSON
      try {
        final json = jsonDecode(rawData);
        if (json is Map<String, dynamic>) {
          return QrData.fromJson(json);
        }
      } catch (e) {
        // Not JSON format, continue to try other formats
      }

      // If not JSON, check if it's just a serial number string
      if (rawData.startsWith('SERL')) {
        return QrData(serialNumber: rawData);
      }

      _logService.addLog(
        message: 'Không thể phân tích mã QR: Định dạng không hỗ trợ',
        level: LogLevel.warning,
        step: ProcessStep.deviceSelection,
        origin: 'system',
      );
      return null;
    } catch (e) {
      DebugLogger.e('Error parsing QR data: $e', className: 'QrScannerService', methodName: 'parseQrData');
      _logService.addLog(
        message: 'Lỗi xử lý mã QR: $e',
        level: LogLevel.error,
        step: ProcessStep.deviceSelection,
        origin: 'system',
      );
      return null;
    }
  }

  /// Show QR input dialog and return scanned data
  Future<QrData?> showQrScannerDialog(BuildContext context) async {
    final result = await showDialog<QrData>(
      context: context,
      builder: (context) => QrInputDialog(),
    );

    if (result != null) {
      _logService.addLog(
        message: 'Đã nhận được mã thiết bị: ${result.serialNumber}',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'system',
      );
    }

    return result;
  }

  /// Import QR data from file (image or text)
  Future<QrData?> importQrDataFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        final qrData = parseQrData(content);
        if (qrData != null) {
          _logService.addLog(
            message: 'Đã nhập serial từ file: ${result.files.single.name}',
            level: LogLevel.success,
            step: ProcessStep.deviceSelection,
            origin: 'system',
          );
        }
        return qrData;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Lỗi khi nhập file: $e',
        level: LogLevel.error,
        step: ProcessStep.deviceSelection,
        origin: 'system',
      );
    }
    return null;
  }

  void dispose() {
    // No resources to dispose
  }
}

/// Dialog to input serial number manually or import from file
class QrInputDialog extends StatefulWidget {
  @override
  _QrInputDialogState createState() => _QrInputDialogState();
}

class _QrInputDialogState extends State<QrInputDialog> {
  final TextEditingController _controller = TextEditingController();
  final QrScannerService _service = GetIt.instance<QrScannerService>();
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleImportFromFile() async {
    final qrData = await _service.importQrDataFromFile();
    if (qrData != null) {
      Navigator.of(context).pop(qrData);
    } else {
      setState(() {
        _errorMessage = 'Không thể đọc mã từ file. Vui lòng thử lại hoặc nhập thủ công.';
      });
    }
  }

  void _handleManualSubmit() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã serial';
      });
      return;
    }

    // Try to parse as JSON if it looks like JSON
    if (input.startsWith('{') && input.endsWith('}')) {
      try {
        final jsonData = jsonDecode(input);
        if (jsonData['serial_number'] != null) {
          Navigator.of(context).pop(QrData.fromJson(jsonData));
          return;
        }
      } catch (e) {
        // Not valid JSON, continue as plain text
      }
    }

    // If input is just the serial number
    if (input.startsWith('SERL') || input.length > 5) {
      Navigator.of(context).pop(QrData(serialNumber: input));
    } else {
      setState(() {
        _errorMessage = 'Mã serial không hợp lệ. Mã phải bắt đầu bằng SERL hoặc có độ dài phù hợp.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhập mã thiết bị',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Information text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.blueGrey.shade800 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bạn có thể nhập trực tiếp mã serial của thiết bị hoặc nhập dữ liệu JSON từ file.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error message if any
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
                  ],
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 20),

            // Manual input field
            const Text('Nhập mã thủ công:'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'SERL123456789 hoặc dữ liệu JSON',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: _handleManualSubmit,
                ),
              ),
              onSubmitted: (_) => _handleManualSubmit(),
            ),

            const SizedBox(height: 20),
            const Text('Hoặc nhập từ file:'),
            const SizedBox(height: 8),

            // Import from file button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Nhập từ file (TXT, JSON)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _handleImportFromFile,
              ),
            ),

            const SizedBox(height: 20),

            // Cancel and Submit buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _handleManualSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkTheme ? AppColors.accent : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
