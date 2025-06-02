class Planning {
  final String id;
  final String? name;
  final String? description;

  Planning({
    required this.id,
    this.name,
    this.description,
  });

  factory Planning.fromJson(Map<String, dynamic> json) {
    return Planning(
      id: json['planning_id']?.toString() ?? '',
      // Name is optional and will be null if not provided
      name: json['name']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planning_id': id,
      'name': name,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Planning && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
