import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';

abstract class ApiRepository {
  Future<List<Planning>> fetchPlannings();
  Future<List<Batch>> fetchBatches(String? planningId);
  Future<List<Device>> fetchDevices(String batchId);
  Future<List<Firmware>> fetchFirmwares(int templateId);
  Future<String?> fetchFirmwareFile(String firmwareId);
  Future<void> updateDeviceStatus(
    String deviceId,
    String status, {
    String? reason,
  });
  Future<Map<String, dynamic>> updateDeviceStatusWithResult({
    required String deviceSerial,
    required bool isSuccessful,
  });
  Future<Firmware?> getDefaultFirmware(int templateId, int? batchFirmwareId);
}
