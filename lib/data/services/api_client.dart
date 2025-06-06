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

          final List<Planning> plannings = planningsData.map((data) => Planning.fromJson(data)).toList();

          _logService.addLog(
            message: 'Đã tải ${plannings.length} kế hoạch',
            level: LogLevel.success,
            step: ProcessStep.productBatch,
            origin: 'system',
          );

          DebugLogger.d(
            'Successfully fetched ${plannings.length} plannings',
            className: 'ApiService',
            methodName: 'fetchPlannings',
          );

          return plannings;
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
  Future<List<Batch>> fetchBatches() async {
    try {
      DebugLogger.d('Fetching batches...', className: 'ApiService');

      _logService.addLog(
        message: 'Đang tải danh sách lô sản xuất...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _httpClient.get(
        Uri.parse('$baseUrl/production-tracking/info-need-upload-firmware/batch/null/null'),
        headers: _headers,
      );

      DebugLogger.http('GET', '/batch/null/null', response: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> batchesData = responseData['data'] as List;

          final Map<String, Batch> uniqueBatches = {};
          for (var data in batchesData) {
            final batch = Batch.fromJson(data);
            uniqueBatches[batch.id] = batch;
          }

          DebugLogger.d('Fetched ${uniqueBatches.length} batches', className: 'ApiService');
          return uniqueBatches.values.toList();
        }

        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('Error fetching batches: $errorMessage');
        return [];
      } else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('Error fetching batches: $errorMessage');
        return [];
      }
    } catch (e, stackTrace) {
      DebugLogger.e('Exception in fetchBatches', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Future<List<Device>> fetchDevices(String batchId) async {
    try {
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

      print('Devices Response status: ${response.statusCode}');
      print('Devices Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> devicesData = responseData['data'] as List;

          // Convert response to Device objects and remove duplicates
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

          return uniqueDevices.values.toList();
        }
        final errorMessage = responseData['message'] ?? 'Unknown error occurred';
        DebugLogger.e('Error fetching batches: $errorMessage');
        _logService.addLog(
          message: 'Error fetching devices: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
      else {
        final errorMessage = 'HTTP Error: ${response.statusCode}';
        DebugLogger.e('Error fetching devices: $errorMessage');
        _logService.addLog(
          message: 'Error fetching devices: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      print('Exception in fetchDevices: $e');
      _logService.addLog(
        message: 'Exception fetching devices: $e',
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
      _logService.addLog(
        message: 'Fetching firmwares for template $templateId...',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/firmware/by-template/$templateId'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        final firmwares = data.map((json) => Firmware.fromJson(json)).toList();
        _logService.addLog(
          message:
              'Fetched ${firmwares.length} firmwares for template $templateId',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return firmwares;
      } else {
        _logService.addLog(
          message: 'Error fetching firmwares: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception fetching firmwares: $e',
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
      _logService.addLog(
        message: 'Fetching firmware file for ID $firmwareId...',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/firmware/detail/$firmwareId'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body)['data'];
        final sourceCode = data['file_path'] as String?;
        if (sourceCode == null || sourceCode.isEmpty) {
          _logService.addLog(
            message: 'Error: Firmware file path is empty',
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );
          return null;
        }
        _logService.addLog(
          message: 'Fetched firmware file for ID $firmwareId',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return sourceCode;
      } else {
        _logService.addLog(
          message: 'Error fetching firmware file: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return null;
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception fetching firmware file: $e',
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
