class Device {
  final String id;
  final String name;
  final String status; // Connected, Compiling, Flashing, Done, Error
  final String? serialNumber;
  final String? firmwareVersion;
  final String? usbPort; // Added USB port field

  Device({
    required this.id,
    required this.name,
    required this.status,
    this.serialNumber,
    this.firmwareVersion,
    this.usbPort,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      serialNumber: json['serialNumber'],
      firmwareVersion: json['firmwareVersion'],
      usbPort: json['usbPort'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'serialNumber': serialNumber,
      'firmwareVersion': firmwareVersion,
      'usbPort': usbPort,
    };
  }
}