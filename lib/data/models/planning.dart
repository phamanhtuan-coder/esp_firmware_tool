class Planning {
  final String id;
  final String? name;
  final String? description;
  final int? templateId;
  final int? firmwareId;

  Planning({
    required this.id,
    this.name,
    this.description,
    this.templateId,
    this.firmwareId,
  });

  factory Planning.fromJson(Map<String, dynamic> json) {
    return Planning(
      id: json['planning_id']?.toString() ?? '',
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      templateId: json['template_id'] as int?,
      firmwareId: json['firmware_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planning_id': id,
      'name': name,
      'description': description,
      'template_id': templateId,
      'firmware_id': firmwareId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Planning && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
