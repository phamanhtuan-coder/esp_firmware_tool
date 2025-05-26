class Firmware {
  final String id;
  final String name;
  final String version;
  final String path;

  Firmware({
    required this.id,
    required this.name,
    required this.version,
    required this.path,
  });

  factory Firmware.fromJson(Map<String, dynamic> json) {
    return Firmware(
      id: json['id'],
      name: json['name'],
      version: json['version'],
      path: json['path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'path': path,
    };
  }
}