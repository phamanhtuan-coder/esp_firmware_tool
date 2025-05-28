class Firmware {
  final String name;
  final String path;
  final String compiledBinaryPath;
  final FirmwareStatus status;

  Firmware({
    required this.name,
    required this.path,
    this.compiledBinaryPath = '',
    this.status = FirmwareStatus.notCompiled,
  });

  Firmware copyWith({
    String? name,
    String? path,
    String? compiledBinaryPath,
    FirmwareStatus? status,
  }) {
    return Firmware(
      name: name ?? this.name,
      path: path ?? this.path,
      compiledBinaryPath: compiledBinaryPath ?? this.compiledBinaryPath,
      status: status ?? this.status,
    );
  }
}

enum FirmwareStatus {
  notCompiled,
  compiling,
  compiled,
  error,
}