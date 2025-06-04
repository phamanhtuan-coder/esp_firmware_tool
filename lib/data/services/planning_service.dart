import 'dart:developer' as developer;
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';

class PlanningService {
  final ApiClient _apiClient;
  final LogService _logService;
  // Cache để lưu firmware cho mỗi template
  final Map<int, List<Firmware>> _firmwareCache = {};

  PlanningService({
    required ApiClient apiClient,
    required LogService logService,
  })  : _apiClient = apiClient,
        _logService = logService;

  /// Fetches the list of plannings from the API
  ///
  /// Returns a list of plannings that can be used in dropdowns
  /// Each planning contains an id and name
  Future<List<Map<String, String>>> fetchPlannings() async {
    try {
      developer.log('Fetching plannings list', name: 'PlanningService');

      _logService.addLog(
        message: 'Đang tải danh sách kế hoạch...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/planning/null/null',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> planningsData = response['data'] as List;

        // Convert response to Planning objects first and remove duplicates
        final Map<String, Planning> uniquePlannings = {};
        for (var data in planningsData) {
          final planning = Planning.fromJson(data);
          uniquePlannings[planning.id] = planning;
        }

        // Log success
        _logService.addLog(
          message: 'Đã tải ${uniquePlannings.length} kế hoạch',
          level: LogLevel.success,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Successfully fetched ${uniquePlannings.length} plannings',
          name: 'PlanningService',
        );

        // Convert to dropdown format with unique entries, using ID as both id and name
        return uniquePlannings.values.map((planning) => {
          'id': planning.id,
          'name': planning.id, // Since name isn't available, use ID for display
        }).toList();
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';

        _logService.addLog(
          message: 'Lỗi khi tải danh sách kế hoạch: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Error fetching plannings: $errorMessage',
          name: 'PlanningService',
          error: errorMessage,
        );

        return [];
      }
    } catch (e, stackTrace) {
      final errorMessage = 'Exception when fetching plannings: $e';

      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      developer.log(
        errorMessage,
        name: 'PlanningService',
        error: e,
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  /// Fetches a single planning by ID
  ///
  /// Parameters:
  /// - planningId: The ID of the planning to fetch
  ///
  /// Returns the planning details or null if not found
  Future<Planning?> fetchPlanningById(String planningId) async {
    try {
      developer.log(
        'Fetching planning details for ID: $planningId',
        name: 'PlanningService',
      );

      _logService.addLog(
        message: 'Đang tải thông tin kế hoạch $planningId...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/planning/$planningId/null',
      );

      if (response['success'] == true && response['data'] != null) {
        final planningData = response['data'];
        final planning = Planning.fromJson(planningData);

        _logService.addLog(
          message: 'Đã tải thông tin kế hoạch ${planning.name}',
          level: LogLevel.success,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        return planning;
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';

        _logService.addLog(
          message: 'Lỗi khi tải thông tin kế hoạch: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        return null;
      }
    } catch (e, stackTrace) {
      final errorMessage = 'Exception when fetching planning details: $e';

      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      developer.log(
        errorMessage,
        name: 'PlanningService',
        error: e,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  /// Fetches batches for a specific planning
  ///
  /// Parameters:
  /// - planningId: The ID of the planning to fetch batches for
  ///
  /// Returns a list of batches or empty list if failed
  Future<List<Batch>> fetchBatches(String planningId) async {
    try {
      developer.log(
        'Fetching batches for planning ID: $planningId',
        name: 'PlanningService',
      );

      _logService.addLog(
        message: 'Đang tải danh sách lô cho kế hoạch $planningId...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/batch/$planningId/null',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> batchesData = response['data'] as List;

        // Remove duplicates based on batch ID
        final Map<String, Batch> uniqueBatches = {};
        for (var data in batchesData) {
          final batch = Batch.fromJson(data);
          uniqueBatches[batch.id] = batch;
        }

        final batches = uniqueBatches.values.toList();

        _logService.addLog(
          message: 'Đã tải ${batches.length} lô cho kế hoạch $planningId',
          level: LogLevel.success,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Successfully fetched ${batches.length} batches for planning $planningId',
          name: 'PlanningService',
        );

        return batches;
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';

        _logService.addLog(
          message: 'Lỗi khi tải danh sách lô: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Error fetching batches: $errorMessage',
          name: 'PlanningService',
          error: errorMessage,
        );

        return [];
      }
    } catch (e, stackTrace) {
      final errorMessage = 'Exception when fetching batches: $e';

      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      developer.log(
        errorMessage,
        name: 'PlanningService',
        error: e,
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  /// Fetches devices for a specific batch
  ///
  /// Parameters:
  /// - batchId: The ID of the batch to fetch devices for
  ///
  /// Returns a list of devices or empty list if failed
  Future<List<Device>> fetchDevices(String batchId) async {
    try {
      developer.log(
        'Fetching devices for batch ID: $batchId',
        name: 'PlanningService',
      );

      _logService.addLog(
        message: 'Đang tải danh sách thiết bị cho lô $batchId...',
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/tracking/null/$batchId',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> devicesData = response['data'] as List;
        final devices = devicesData.map((data) => Device.fromJson(data)).toList();

        // Remove duplicates based on device serial
        final uniqueDevices = <String, Device>{};
        for (var device in devices) {
          uniqueDevices[device.serial] = device;
        }

        _logService.addLog(
          message: 'Đã tải ${uniqueDevices.length} thiết bị cho lô $batchId',
          level: LogLevel.success,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Successfully fetched ${uniqueDevices.length} devices for batch $batchId',
          name: 'PlanningService',
        );

        return uniqueDevices.values.toList();
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';

        _logService.addLog(
          message: 'Lỗi khi tải danh sách thiết bị: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.productBatch,
          origin: 'system',
        );

        developer.log(
          'Error fetching devices: $errorMessage',
          name: 'PlanningService',
          error: errorMessage,
        );

        return [];
      }
    } catch (e, stackTrace) {
      final errorMessage = 'Exception when fetching devices: $e';

      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      );

      developer.log(
        errorMessage,
        name: 'PlanningService',
        error: e,
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  /// Fetches and caches firmware list for a template
  Future<List<Firmware>> fetchAndCacheFirmwares(int templateId) async {
    try {
      final response = await _apiClient.fetchFirmwareByTemplate(templateId);

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> firmwareData = response['data'] as List;
        final firmwares = firmwareData.map((json) => Firmware.fromJson(json)).toList();

        // Cập nhật cache
        _firmwareCache[templateId] = firmwares;

        _logService.addLog(
          message: 'Đã tải ${firmwares.length} phiên bản firmware cho template $templateId',
          level: LogLevel.success,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );

        return firmwares;
      } else {
        final String errorMessage = response['message'] ?? 'Unknown error occurred';
        _logService.addLog(
          message: 'Lỗi khi tải danh sách firmware: $errorMessage',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        );
        return [];
      }
    } catch (e, stackTrace) {
      _logService.addLog(
        message: 'Lỗi ngoại lệ khi tải firmware: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );
      return [];
    }
  }

  /// Lấy firmware từ cache hoặc tải mới nếu chưa có
  Future<List<Firmware>> getFirmwares(int templateId) async {
    if (_firmwareCache.containsKey(templateId)) {
      return _firmwareCache[templateId]!;
    }
    return fetchAndCacheFirmwares(templateId);
  }

  /// Lấy firmware mặc định (firmware bắt buộc) cho template
  Future<Firmware?> getDefaultFirmware(int templateId) async {
    final firmwares = await getFirmwares(templateId);
    return firmwares.firstWhere(
      (fw) => fw.isMandatory && fw.isApproved,
      orElse: () => firmwares.firstWhere(
        (fw) => fw.isApproved,
        orElse: () => firmwares.first,
      ),
    );
  }

  /// Fetches devices and firmwares when a batch is selected
  Future<Map<String, dynamic>> loadBatchData(String batchId, String planningId) async {
    try {
      // Fetch devices for the batch
      final devices = await fetchDevices(batchId);

      // Find the batch to get its template ID
      final response = await _apiClient.get(
        '/production-tracking/info-need-upload-firmware/batch/$planningId/null',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> batchesData = response['data'] as List;
        final selectedBatch = batchesData.firstWhere(
          (data) => data['production_batch_id'] == batchId,
          orElse: () => null,
        );

        if (selectedBatch != null && selectedBatch['template_id'] != null) {
          final templateId = selectedBatch['template_id'] as int;

          // Load firmwares for the template
          final firmwares = await getFirmwares(templateId);

          _logService.addLog(
            message: 'Đã tải ${firmwares.length} phiên bản firmware cho template $templateId',
            level: LogLevel.success,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          );

          return {
            'devices': devices,
            'firmwares': firmwares,
            'templateId': templateId,
          };
        }
      }

      // Return devices only if batch or template info not found
      return {
        'devices': devices,
        'firmwares': <Firmware>[],
        'templateId': null,
      };

    } catch (e, stackTrace) {
      _logService.addLog(
        message: 'Lỗi khi tải dữ liệu cho batch: $e',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      );

      developer.log(
        'Error loading batch data',
        error: e,
        stackTrace: stackTrace,
        name: 'PlanningService',
      );

      return {
        'devices': <Device>[],
        'firmwares': <Firmware>[],
        'templateId': null,
      };
    }
  }
}
