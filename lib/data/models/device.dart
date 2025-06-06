class Device {
  final String id;
  final String batchId;
  final String serial;
  final String status;
  final String? reason;
  final String? imageUrl;

  Device({
    required this.id,
    required this.batchId,
    required this.serial,
    this.status = 'pending',
    this.reason,
    this.imageUrl,
  });

  bool get isReadyToFlash => status == 'firmware_uploading';
  bool get isCompleted => status == 'firmware_uploaded' || status == 'completed';
  bool get hasError => status == 'firmware_failed' || status == 'error';
  bool get isInProgress => status == 'in_progress' || status == 'firmware_upload';

  Device copyWith({
    String? id,
    String? batchId,
    String? serial,
    String? status,
    String? reason,
    String? imageUrl,
  }) {
    return Device(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      serial: serial ?? this.serial,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    String normalizeStatus(String? rawStatus) {
      switch (rawStatus?.toLowerCase()) {
        case 'firmware_uploading':
          return 'firmware_uploading';
        case 'firmware_upload':
        case 'firmware_uploaded':
          return 'firmware_uploaded';
        case 'in_progress':
          return 'in_progress';
        case 'error':
          return 'error';
        case 'completed':
          return 'completed';
        default:
          return 'pending';
      }
    }

    return Device(
      id: json['device_serial']?.toString() ?? '',
      batchId: json['production_batch_id']?.toString() ?? '',
      serial: json['device_serial']?.toString() ?? '',
      status: normalizeStatus(json['status']?.toString()),
      reason: json['reason']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_serial': id,
      'production_batch_id': batchId,
      'serial': serial,
      'status': status,
      'reason': reason,
      'image_url': imageUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
