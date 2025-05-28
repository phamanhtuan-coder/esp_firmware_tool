import 'dart:async';
import 'dart:math' as math;

/// A mock service for USB port detection to help with testing
class UsbServiceMock {
  final List<String> _mockPorts = [
    'COM1', 'COM3', 'COM4', 'COM7',
    '/dev/ttyUSB0', '/dev/ttyUSB1',
    '/dev/cu.usbserial-1410'
  ];

  /// Returns a Future with mock USB port detection results
  Future<Map<String, dynamic>> scanPorts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Randomly select 0-3 ports to simulate available ports
    final availablePorts = <String>[];
    final random = math.Random();
    final numPorts = random.nextInt(4); // 0 to 3 ports

    if (numPorts > 0) {
      // Shuffle the ports and take the first few
      final shuffledPorts = List<String>.from(_mockPorts)..shuffle();
      availablePorts.addAll(shuffledPorts.take(numPorts));
    }

    return {
      'success': true,
      'ports': availablePorts,
      'message': availablePorts.isEmpty
          ? 'No USB devices detected'
          : 'Found ${availablePorts.length} device(s)'
    };
  }

  /// Simulates checking if a specific device is connected with given serial number
  Future<Map<String, dynamic>> checkDeviceBySerial(String serialNumber) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));

    final random = math.Random();
    final isConnected = random.nextBool() || serialNumber.contains('TEST');

    if (isConnected) {
      final portIndex = random.nextInt(_mockPorts.length);
      return {
        'success': true,
        'connected': true,
        'port': _mockPorts[portIndex],
        'device': {
          'id': 'device-${serialNumber.hashCode}',
          'name': 'ESP Device $serialNumber',
          'status': 'connected',
          'port': _mockPorts[portIndex],
          'serialNumber': serialNumber
        }
      };
    }

    return {
      'success': false,
      'connected': false,
      'error': 'Device with serial number $serialNumber not found'
    };
  }
}