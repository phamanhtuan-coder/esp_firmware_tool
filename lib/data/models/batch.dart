class Batch {
  final String id;
  final String name;
  final String planningId;
  final String templateId;
  final int? firmwareId;

  Batch({
    required this.id,
    required this.name,
    required this.planningId,
    required this.templateId,
    this.firmwareId,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    final batchId = json['production_batch_id']?.toString() ?? '';
    return Batch(
      id: batchId,
      name: json['name']?.toString() ?? batchId,
      planningId: json['planning_id']?.toString() ?? '',
      templateId: json['template_id']?.toString() ?? '',
      firmwareId: json['firmware_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'production_batch_id': id,
      'name': name,
      'planning_id': planningId,
      'template_id': templateId,
      'firmware_id': firmwareId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Batch && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
