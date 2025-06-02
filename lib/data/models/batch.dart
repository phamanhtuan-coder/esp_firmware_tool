class Batch {
  final String id;
  final String name;
  final String planningId;
  final String templateId;

  Batch({
    required this.id,
    required this.name,
    required this.planningId,
    required this.templateId,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['production_batch_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      planningId: json['planning_id']?.toString() ?? '',
      templateId: json['template_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'production_batch_id': id,
      'name': name,
      'planning_id': planningId,
      'template_id': templateId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Batch && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

