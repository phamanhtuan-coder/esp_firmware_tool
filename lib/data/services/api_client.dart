import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/domain/repositories/api_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';

class ApiService implements ApiRepository {
  final String baseUrl =
      'https://iothomeconnectapiv2-production.up.railway.app/api';
  final http.Client _httpClient = http.Client();
  final LogService _logService = GetIt.instance<LogService>();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  Future<List<Planning>> fetchPlannings() async {
    try {
      DebugLogger.d('Fetching plannings list', className: 'ApiService', methodName: 'fetchPlannings');

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

          // Remove duplicates based on planning_id
          final Map<String, Planning> uniquePlannings = {};
          for (var data in planningsData) {
            final planning = Planning.fromJson(data);
            uniquePlannings[planning.id] = planning;
          }

          _logService.addLog(
            message: 'Đã tải ${uniquePlannings.length} kế hoạch',
            level: LogLevel.success,
            step: ProcessStep.productBatch,
            origin: 'system',
          );

          DebugLogger.d(
            'Successfully fetched ${uniquePlannings.length} plannings',
            className: 'ApiService',
            methodName: 'fetchPlannings',
          );

          return uniquePlannings.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Lỗi tải kế hoạch: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.other,
          origin: 'system',
        );
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        _logService.addLog(
          message: 'Lỗi tải kế hoạch: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.other,
          origin: 'system',
        );
      }
      return [];
    } catch (e, stackTrace) {
      DebugLogger.e('Exception in fetchPlannings', error: e, stackTrace: stackTrace);
      _logService.addLog(
        message: 'Lỗi tải kế hoạch: $e',
        level: LogLevel.error,
        step: ProcessStep.other,
        origin: 'system',
      );
      return [];
    }
  }

  @override
  Future<List<Batch>> fetchBatches(String? planningId) async {
    try {
      DebugLogger.d('Fetching batches for planning $planningId...', className: 'ApiService');

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

      DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> batchesData = responseData['data'] as List;

          // Use a map to automatically handle duplicates based on batch_id
          final Map<String, Batch> uniqueBatches = {};
          for (var data in batchesData) {
            final batch = Batch.fromJson(data);
            // Only add the batch if it belongs to the requested planning
            if (planningId == null || batch.planningId == planningId) {
              uniqueBatches[batch.id] = batch;
            }
          }

          _logService.addLog(
            message: 'Đã tải ${uniqueBatches.length} lô sản xuất cho kế hoạch $planningId',
            level: LogLevel.success,
            step: ProcessStep.productBatch,
            origin: 'system',
          );

          return uniqueBatches.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Lỗi tải lô sản xuất: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        _logService.addLog(
          message: 'Lỗi tải lô sản xuất: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );
        return [];
      }
    } catch (e, stackTrace) {
      DebugLogger.e('Exception in fetchBatches', error: e, stackTrace: stackTrace);
      _logService.addLog(
        message: 'Lỗi tải lô sản xuất: $e',
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      );
      return [];
    }
  }

  @override
  Future<List<Device>> fetchDevices(String batchId) async {
    try {
      DebugLogger.d(
        'Fetching devices for batch ID: $batchId',
        className: 'ApiService',
        methodName: 'fetchDevices',
      );

      _logService.addLog(
        message: 'Đang tải danh sách thiết bị cho lô $batchId...',
        level: LogLevel.info,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );

      final response = await _httpClient.get(
        Uri.parse('$baseUrl/production-tracking/info-need-upload-firmware/tracking/null/$batchId'),
        headers: _headers,
      );

      DebugLogger.http('GET', '/tracking/null/$batchId', response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> devicesData = responseData['data'] as List;

          // Remove duplicates based on device serial
          final Map<String, Device> uniqueDevices = {};
          for (var data in devicesData) {
            final device = Device.fromJson(data);
            uniqueDevices[device.serial] = device;
          }

          _logService.addLog(
            message: 'Đã tải ${uniqueDevices.length} thiết bị cho lô $batchId',
            level: LogLevel.success,
            step: ProcessStep.deviceRefresh,
            origin: 'system',
          );

          DebugLogger.d(
            'Successfully fetched ${uniqueDevices.length} devices for batch $batchId',
            className: 'ApiService',
            methodName: 'fetchDevices',
          );

          return uniqueDevices.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('Error fetching devices: $errorMessage');
        _logService.addLog(
          message: 'Lỗi khi tải danh sách thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('Error fetching devices: $errorMessage');
        _logService.addLog(
          message: 'Lỗi khi tải danh sách thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
    } catch (e, stackTrace) {
      DebugLogger.e(
        'Exception in fetchDevices',
        error: e,
        stackTrace: stackTrace,
      );
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
    try {
      DebugLogger.d(
        'Fetching firmwares for template $templateId...',
        className: 'ApiService',
        methodName: 'fetchFirmwares',
      );

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

      DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> firmwaresData = responseData['data'] as List;

          // Remove duplicates based on firmware_id
          final Map<int, Firmware> uniqueFirmwares = {};
          for (var data in firmwaresData) {
            final firmware = Firmware.fromJson(data);
            uniqueFirmwares[firmware.firmwareId] = firmware;
          }

          _logService.addLog(
            message: 'Đã tải ${uniqueFirmwares.length} firmware cho template $templateId',
            level: LogLevel.success,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );

          DebugLogger.d(
            'Successfully fetched ${uniqueFirmwares.length} firmwares for template $templateId',
            className: 'ApiService',
            methodName: 'fetchFirmwares',
          );

          return uniqueFirmwares.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('Error fetching firmwares: $errorMessage');
        _logService.addLog(
          message: 'Lỗi tải firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('Error fetching firmwares: $errorMessage');
        _logService.addLog(
          message: 'Lỗi tải firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return [];
      }
    } catch (e, stackTrace) {
      DebugLogger.e(
        'Exception in fetchFirmwares',
        error: e,
        stackTrace: stackTrace,
      );
      _logService.addLog(
        message: 'Lỗi tải firmware: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return [];
    }
  }

  @override
  Future<String?> fetchFirmwareFile(String firmwareId) async {
    try {
      DebugLogger.d(
        'Fetching firmware file for ID: $firmwareId',
        className: 'ApiService',
        methodName: 'fetchFirmwareFile',
      );

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

      DebugLogger.http('GET', endpoint, response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'];
        final sourceCode = data['file_path'] as String?;

        if (sourceCode == null || sourceCode.isEmpty) {
          const errorMessage = 'Firmware file path is empty';
          DebugLogger.e(errorMessage);
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

        DebugLogger.d(
          'Successfully fetched firmware file for ID $firmwareId',
          className: 'ApiService',
          methodName: 'fetchFirmwareFile',
        );

        return sourceCode;
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('Error fetching firmware file: $errorMessage');
        _logService.addLog(
          message: 'Lỗi tải file firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }
    } catch (e, stackTrace) {
      DebugLogger.e(
        'Exception in fetchFirmwareFile',
        error: e,
        stackTrace: stackTrace,
      );
      _logService.addLog(
        message: 'Lỗi tải file firmware: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
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

  void dispose() {
    _httpClient.close();
  }
}
