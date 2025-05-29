class Device {
  final int id;
  final int batchId;
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

  Device copyWith({
    int? id,
    int? batchId,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}