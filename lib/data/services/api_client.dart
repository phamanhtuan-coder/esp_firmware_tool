import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/domain/repositories/api_repository.dart';
import 'package:get_it/get_it.dart';

class ApiService implements ApiRepository {
  final String baseUrl =
      'https://iothomeconnectapiv2-production.up.railway.app/api';
  final http.Client _httpClient = http.Client();
  final LogService _logService = GetIt.instance<LogService>();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  final Map<int, List<Firmware>> _firmwareCache = {};

  @override
  Future<List<Planning>> fetchPlannings() async {
    try {
      DebugLogger.d('🔄 Đang tải danh sách kế hoạch...', className: 'ApiService', methodName: 'fetchPlannings');

      _logService.addLog(
        message: 'Đang tải danh sách kế hoạch...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _httpClient.get(
        Uri.parse('$baseUrl/production-tracking/info-need-upload-firmware/planning/null/null'),
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> planningsData = responseData['data'] as List;

          // Use LinkedHashMap to preserve order while removing duplicates
          final uniquePlannings = LinkedHashMap<String, Planning>.fromIterable(
            planningsData.map((data) => Planning.fromJson(data)),
            key: (planning) => (planning as Planning).id,
            value: (planning) => planning as Planning,
          );

          DebugLogger.d(
            '✅ Đã tải thành công ${uniquePlannings.length} kế hoạch',
            className: 'ApiService',
            methodName: 'fetchPlannings',
          );

          return uniquePlannings.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('❌ Lỗi tải kế hoạch: $errorMessage', className: 'ApiService', methodName: 'fetchPlannings');
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('❌ Lỗi tải kế hoạch: $errorMessage', className: 'ApiService', methodName: 'fetchPlannings');
      }
      return [];
    } catch (e) {
      DebugLogger.e('❌ Lỗi ngoại lệ trong fetchPlannings: $e',
        className: 'ApiService',
        methodName: 'fetchPlannings');
      return [];
    }
  }

  @override
  Future<List<Batch>> fetchBatches(String? planningId) async {
    try {
      DebugLogger.d(
        '🔄 Đang tải danh sách lô cho kế hoạch $planningId...',
        className: 'ApiService',
        methodName: 'fetchBatches'
      );

      _logService.addLog(
        message: 'Đang tải danh sách lô sản xuất...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final endpoint = planningId != null
          ? '$baseUrl/production-tracking/info-need-upload-firmware/batch/$planningId/null'
          : '$baseUrl/production-tracking/info-need-upload-firmware/batch/null/null';

      final response = await _httpClient.get(
        Uri.parse(endpoint),
        headers: _headers,
      );

      // DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> batchesData = responseData['data'] as List;

          // Use LinkedHashMap to preserve order while removing duplicates
          final uniqueBatches = LinkedHashMap<String, Batch>.fromIterable(
            batchesData.map((data) => Batch.fromJson(data))
                .where((batch) => planningId == null || batch.planningId == planningId),
            key: (batch) => (batch as Batch).id,
            value: (batch) => batch as Batch,
          );

          DebugLogger.d(
            '✅ Đã tải ${uniqueBatches.length} lô cho kế hoạch $planningId',
            className: 'ApiService',
            methodName: 'fetchBatches',
          );

          return uniqueBatches.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('❌ Lỗi tải lô: $errorMessage', className: 'ApiService', methodName: 'fetchBatches');
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('❌ Lỗi tải lô: $errorMessage', className: 'ApiService', methodName: 'fetchBatches');
        return [];
      }
    } catch (e) {
      DebugLogger.e('❌ Lỗi ngoại lệ trong fetchBatches: $e',
        className: 'ApiService',
        methodName: 'fetchBatches');
      return [];
    }
  }

  @override
  Future<List<Device>> fetchDevices(String batchId) async {
    try {
      // // DebugLogger.d(
      //   'Fetching devices for batch ID: $batchId',
      //   className: 'ApiService',
      //   methodName: 'fetchDevices',
      // );

      _logService.addLog(
        message: 'Đang tải danh sách thiết bị cho l��� $batchId...',
        level: LogLevel.info,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );

      final response = await _httpClient.get(
        Uri.parse('$baseUrl/production-tracking/info-need-upload-firmware/tracking/null/$batchId'),
        headers: _headers,
      );

      // // DebugLogger.http('GET', '/tracking/null/$batchId', response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> devicesData = responseData['data'] as List;

          // Use LinkedHashMap to preserve order while removing duplicates
          final uniqueDevices = LinkedHashMap<String, Device>.fromIterable(
            devicesData.map((data) => Device.fromJson(data)),
            key: (device) => (device as Device).serial,
            value: (device) => device as Device,
          );

          _logService.addLog(
            message: 'Đã tải ${uniqueDevices.length} thiết bị cho lô $batchId',
            level: LogLevel.success,
            step: ProcessStep.deviceRefresh,
            origin: 'system',
          );

          // // DebugLogger.d(
          //   'Successfully fetched ${uniqueDevices.length} devices for batch $batchId',
          //   className: 'ApiService',
          //   methodName: 'fetchDevices',
          // );

          return uniqueDevices.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        // DebugLogger.e('Error fetching devices: $errorMessage');
        _logService.addLog(
          message: 'Lỗi khi tải danh s��ch thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        // DebugLogger.e('Error fetching devices: $errorMessage');
        _logService.addLog(
          message: 'Lỗi khi tải danh sách thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      // DebugLogger.e(
      //   'Exception in fetchDevices',
      //   error: e,
      //   stackTrace: stackTrace,
      // );
      _logService.addLog(
        message: 'Lỗi khi tải danh sách thiết bị: $e',
        level: LogLevel.error,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );
      return [];
    }
  }

  @override
  Future<List<Firmware>> fetchFirmwares(int templateId) async {
    if (_firmwareCache.containsKey(templateId)) {
      return _firmwareCache[templateId]!;
    }

    try {
      // DebugLogger.d(
      //   'Fetching firmwares for template $templateId...',
      //   className: 'ApiService',
      //   methodName: 'fetchFirmwares',
      // );

      _logService.addLog(
        message: 'Đang tải danh sách firmware cho template $templateId...',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      final endpoint = '$baseUrl/firmware/by-template/$templateId';
      final response = await _httpClient.get(
        Uri.parse(endpoint),
        headers: _headers,
      );

      // DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          if (data is List) {
            final firmwares = data
                .map((json) => Firmware.fromJson(json))
                .where((fw) => !fw.isDeleted)
                .toList();

            // Cache the results
            _firmwareCache[templateId] = firmwares;

            _logService.addLog(
              message: 'Đã tải ${firmwares.length} firmware cho template $templateId',
              level: LogLevel.success,
              step: ProcessStep.firmwareDownload,
              origin: 'system',
            );

            return firmwares;
          }
        }
      }

      _logService.addLog(
        message: 'Không có firmware nào cho template $templateId',
        level: LogLevel.warning,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return [];
    } catch (e) {
      DebugLogger.e('❌ Lỗi ngoại lệ trong fetchFirmwares: $e',
        className: 'ApiService',
        methodName: 'fetchFirmwares');
      return [];
    }
  }

  @override
  Future<Firmware?> getDefaultFirmware(int templateId, int? batchFirmwareId) async {
    final firmwares = await fetchFirmwares(templateId);

    // First try to find firmware specified in batch
    if (batchFirmwareId != null) {
      final batchFirmware = firmwares.firstWhere(
        (fw) => fw.firmwareId == batchFirmwareId,
        orElse: () => firmwares.first,
      );
      return batchFirmware;
    }

    // If no batch firmware, try to find mandatory approved firmware
    return firmwares.firstWhere(
      (fw) => fw.isMandatory && fw.isApproved,
      orElse: () => firmwares.firstWhere(
        (fw) => fw.isApproved,
        orElse: () => firmwares.first,
      ),
    );
  }

  @override
  Future<String?> fetchFirmwareFile(String firmwareId) async {
    try {
      // DebugLogger.d(
      //   'Fetching firmware file for ID: $firmwareId',
      //   className: 'ApiService',
      //   methodName: 'fetchFirmwareFile',
      // );

      _logService.addLog(
        message: 'Đang tải file firmware $firmwareId...',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      final endpoint = '$baseUrl/firmware/detail/$firmwareId';
      final response = await _httpClient.get(
        Uri.parse(endpoint),
        headers: _headers,
      );

      // DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'];
        final sourceCode = data['file_path'] as String?;

        if (sourceCode == null || sourceCode.isEmpty) {
          const errorMessage = 'Firmware file path is empty';
          // DebugLogger.e(errorMessage);
          _logService.addLog(
            message: 'Lỗi: $errorMessage',
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );
          return null;
        }

        _logService.addLog(
          message: 'Đã tải file firmware $firmwareId',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );

        // DebugLogger.d(
        //   'Successfully fetched firmware file for ID $firmwareId',
        //   className: 'ApiService',
        //   methodName: 'fetchFirmwareFile',
        // );

        return sourceCode;
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        // DebugLogger.e('Error fetching firmware file: $errorMessage');
        _logService.addLog(
          message: 'Lỗi tải file firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }
    } catch (e) {
      DebugLogger.e('❌ Lỗi ngoại lệ trong fetchFirmwareFile: $e',
        className: 'ApiService',
        methodName: 'fetchFirmwareFile');
      return null;
    }
  }

  @override
  Future<void> updateDeviceStatus(
    String deviceId,
    String status, {
    String? reason,
  }) async {
    try {
      _logService.addLog(
        message: 'Updating device $deviceId status to $status...',
        level: LogLevel.info,
        step: ProcessStep.deviceStatus,
        origin: 'system',
      );
      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/devices/$deviceId'),
        headers: _headers,
        body: jsonEncode({'status': status, 'reason': reason}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logService.addLog(
          message: 'Updated device $deviceId status to $status',
          level: LogLevel.success,
          step: ProcessStep.deviceStatus,
          origin: 'system',
        );
      } else {
        _logService.addLog(
          message: 'Error updating device status: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.deviceStatus,
          origin: 'system',
        );
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception updating device status: $e',
        level: LogLevel.error,
        step: ProcessStep.deviceStatus,
        origin: 'system',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateDeviceStatusWithResult({
    required String deviceSerial,
    required bool isSuccessful,
  }) async {
    final String status = isSuccessful ? 'firmware_uploading' : 'firmware_failed';
    final String logMessage = isSuccessful
        ? 'Marking device $deviceSerial as successful'
        : 'Marking device $deviceSerial as failed';

    _logService.addLog(
      message: logMessage,
      level: LogLevel.info,
      step: ProcessStep.deviceStatus,
      origin: 'system',
      deviceId: deviceSerial,
    );

    try {
      final Map<String, dynamic> body = {
        'device_serial': deviceSerial,
        'stage': 'assembly',
        'status': status,
      };

      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/production-tracking/update-serial'),
        headers: _headers,
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);
      final bool isSuccess = responseData['success'] == true;
      final String resultMessage = responseData['message'] ??
        (isSuccess ? 'Device status updated successfully' : 'Failed to update device status');

      _logService.addLog(
        message: resultMessage,
        level: isSuccess ? LogLevel.success : LogLevel.error,
        step: ProcessStep.deviceStatus,
        origin: 'system',
        deviceId: deviceSerial,
      );

      return responseData;
    } catch (e) {
      final errorMessage = 'Error updating device status: $e';
      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.deviceStatus,
        origin: 'system',
        deviceId: deviceSerial,
      );

      return {
        'success': false,
        'message': errorMessage,
        'errorCode': 'exception',
      };
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
