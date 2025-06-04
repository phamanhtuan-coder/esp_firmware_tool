import 'dart:developer' as developer;
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';

class DeviceStatusService {
  final ApiClient _apiClient;
  final LogService _logService;

  DeviceStatusService({
    required ApiClient apiClient,
    required LogService logService,
  })  : _apiClient = apiClient,
        _logService = logService;

  /// Updates the device status in the production tracking system
  ///
  /// Parameters:
  /// - deviceSerial: The serial number of the device
  /// - isSuccessful: Whether the firmware was successfully uploaded
  ///
  /// Returns a map containing:
  /// - success: Whether the API call was successful
  /// - message: A message describing the result
  /// - errorCode: Error code if applicable
  Future<Map<String, dynamic>> updateDeviceStatus({
    required String deviceSerial,
    required bool isSuccessful,
  }) async {
    final String status = isSuccessful ? 'firmware_uploading' : 'firmware_failed';
    final String logMessage = isSuccessful
        ? 'Marking device $deviceSerial as successful'
        : 'Marking device $deviceSerial as failed';

    // Log the operation
    _logService.addLog(
      message: logMessage,
      level: LogLevel.info,
      step: ProcessStep.updateStatus,
      origin: 'system',
      deviceId: deviceSerial,
    );

    developer.log(
      'Updating device status: Serial=$deviceSerial, Status=$status',
      name: 'DeviceStatusService'
    );

    try {
      // Prepare request body
      final Map<String, dynamic> body = {
        'device_serial': deviceSerial,
        'stage': 'assembly',
        'status': status,
      };

      // Make API call
      final response = await _apiClient.patch(
        '/production-tracking/update-serial',
        body: body,
      );

      // Log the result
      final bool isSuccess = response['success'] == true;
      final String resultMessage = response['message'] ?? (isSuccess
          ? 'Device status updated successfully'
          : 'Failed to update device status');

      _logService.addLog(
        message: resultMessage,
        level: isSuccess ? LogLevel.success : LogLevel.error,
        step: ProcessStep.updateStatus,
        origin: 'system',
        deviceId: deviceSerial,
      );

      developer.log(
        'Update status result: $resultMessage',
        name: 'DeviceStatusService'
      );

      return response;
    } catch (e, stackTrace) {
      // Log any exceptions
      final errorMessage = 'Error updating device status: $e';
      _logService.addLog(
        message: errorMessage,
        level: LogLevel.error,
        step: ProcessStep.updateStatus,
        origin: 'system',
        deviceId: deviceSerial,
      );

      developer.log(
        errorMessage,
        name: 'DeviceStatusService',
        error: e,
        stackTrace: stackTrace,
      );

      // Return an error response to ensure the method always completes
      return {
        'success': false,
        'message': 'Error updating device status: $e',
        'errorCode': 'exception',
      };
    }
  }
}
