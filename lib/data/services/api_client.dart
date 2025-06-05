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

class ApiService implements ApiRepository {
  final String baseUrl =
      'https://iothomeconnectapiv2-production.up.railway.app/api';
  final http.Client _httpClient = http.Client();
  final LogService _logService = GetIt.instance<LogService>();

  @override
  Future<List<Planning>> fetchPlannings() async {
    try {
      _logService.addLog(
        message: 'Fetching plannings...',
        level: LogLevel.info,
        step: ProcessStep.other,
        origin: 'system',
      );
      final response = await _httpClient.get(Uri.parse('$baseUrl/plannings'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        final plannings = data.map((json) => Planning.fromJson(json)).toList();
        _logService.addLog(
          message: 'Fetched ${plannings.length} plannings',
          level: LogLevel.success,
          step: ProcessStep.other,
          origin: 'system',
        );
        return plannings;
      } else {
        _logService.addLog(
          message: 'Error fetching plannings: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.other,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception fetching plannings: $e',
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
      _logService.addLog(
        message: 'Fetching batches...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );
      final response = await _httpClient.get(Uri.parse('$baseUrl/batches'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        final batches = data.map((json) => Batch.fromJson(json)).toList();
        _logService.addLog(
          message: 'Fetched ${batches.length} batches',
          level: LogLevel.success,
          step: ProcessStep.productBatch,
          origin: 'system',
        );
        return batches;
      } else {
        _logService.addLog(
          message: 'Error fetching batches: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
      _logService.addLog(
        message: 'Exception fetching batches: $e',
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
      _logService.addLog(
        message: 'Fetching devices for batch $batchId...',
        level: LogLevel.info,
        step: ProcessStep.deviceRefresh,
        origin: 'system',
      );
      final response = await _httpClient.get(
        Uri.parse(
          '$baseUrl/production-tracking/info-need-upload-firmware/tracking/null/$batchId',
        ),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        final devices = data.map((json) => Device.fromJson(json)).toList();
        final uniqueDevices = <String, Device>{};
        for (var device in devices) {
          uniqueDevices[device.serial] = device;
        }
        _logService.addLog(
          message: 'Fetched ${uniqueDevices.length} devices for batch $batchId',
          level: LogLevel.success,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return uniqueDevices.values.toList();
      } else {
        _logService.addLog(
          message: 'Error fetching devices: ${response.body}',
          level: LogLevel.error,
          step: ProcessStep.deviceRefresh,
          origin: 'system',
        );
        return [];
      }
    } catch (e) {
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
        headers: {'Content-Type': 'application/json'},
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
