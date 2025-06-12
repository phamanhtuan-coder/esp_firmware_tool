class Planning {
  final String id;

  Planning({
    required this.id,
  });

  factory Planning.fromJson(Map<String, dynamic> json) {
    return Planning(
      id: json['planning_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planning_id': id,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Planning && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
