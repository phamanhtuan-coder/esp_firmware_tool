class Device {
  final String id;
  final String serial;
  final String batchId;
  final String status;

  Device({
    required this.id,
    required this.serial,
    required this.batchId,
    required this.status,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final serial = json['device_serial']?.toString() ?? '';
    return Device(
      id: serial, // Using device_serial as ID since it's unique
      serial: serial,
      batchId: json['production_batch_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_serial': serial,
      'production_batch_id': batchId,
      'status': status,
    };
  }

  bool get hasError => status == 'firmware_failed';
  bool get isCompleted => status == 'firmware_uploaded';
  bool get isInProgress => status == 'in_progress';
  bool get isWaitingForQr => status == 'firmware_upload';
}
