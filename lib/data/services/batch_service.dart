import 'dart:async';
import 'dart:io';

import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';

/// Service responsible for managing batches, devices, and firmware operations
class BatchService {
  final LogService _logService;
  final ArduinoCliService _arduinoCliService;

  // Track connections between device IDs and ports
  final Map<String, String> _devicePortMap = {};

  BatchService({
    required LogService logService,
    required ArduinoCliService arduinoCliService,
  }) :
    _logService = logService,
    _arduinoCliService = arduinoCliService;

  /// Fetches the list of available batches
  ///
  /// Returns a list of maps with batch information
  Future<List<Map<String, String>>> fetchBatches() async {
    // TODO: Implement actual API call to fetch batches
    _logService.addLog(
      message: 'Fetching batches',
      level: LogLevel.info,
      step: ProcessStep.productBatch,
      origin: 'system',
    );

    // Returning mock data for now
    return [
      {'id': '1', 'name': 'Batch 001'},
      {'id': '2', 'name': 'Batch 002'},
      {'id': '3', 'name': 'Batch 003'},
    ];
  }

  /// Fetches batches associated with a specific planning
  ///
  /// Returns a list of maps with batch information filtered by planning ID
  Future<List<Map<String, String>>> fetchBatchesForPlanning(String planningId) async {
    // TODO: Implement actual API call to fetch batches for a specific planning
    _logService.addLog(
      message: 'Fetching batches for planning ID: $planningId',
      level: LogLevel.info,
      step: ProcessStep.productBatch,
      origin: 'system',
    );

    // Returning filtered mock data based on the planning ID
    switch (planningId) {
      case '1': // Planning 2025 Q1
        return [
          {'id': '101', 'name': 'Q1-Batch-001'},
          {'id': '102', 'name': 'Q1-Batch-002'},
          {'id': '103', 'name': 'Q1-Batch-003'},
        ];
      case '2': // Planning 2025 Q2
        return [
          {'id': '201', 'name': 'Q2-Batch-001'},
          {'id': '202', 'name': 'Q2-Batch-002'},
        ];
      case '3': // Planning 2025 Q3
        return [
          {'id': '301', 'name': 'Q3-Batch-001'},
          {'id': '302', 'name': 'Q3-Batch-002'},
          {'id': '303', 'name': 'Q3-Batch-003'},
          {'id': '304', 'name': 'Q3-Batch-004'},
        ];
      case '4': // Planning 2025 Q4
        return [
          {'id': '401', 'name': 'Q4-Batch-001'},
        ];
      default:
        return [];
    }
  }

  /// Fetches serial numbers associated with a specific batch
  ///
  /// Returns a list of serial numbers as strings
  Future<List<String>> fetchSerialsForBatch(String batchId) async {
    // TODO: Implement actual API call to fetch serials for a batch
    _logService.addLog(
      message: 'Fetching serials for batch ID: $batchId',
      level: LogLevel.info,
      step: ProcessStep.deviceSelection,
      origin: 'system',
    );

    // Returning mock data for now
    return [
      'SN00001$batchId',
      'SN00002$batchId',
      'SN00003$batchId',
    ];
  }

  Future<String?> fetchVersionFirmware({
    required String batchId,
  }) async {
    return "";
    // TODO: gọi API hoặc backend để lấy sourceCode từ phiên bản firmware
  }


}