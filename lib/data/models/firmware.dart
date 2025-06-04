class Firmware {
  final int firmwareId;
  final String version;
  final String name;
  final String filePath;
  final int templateId;
  final bool isMandatory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? testedAt;
  final bool isApproved;
  final String? note;
  final List<FirmwareLog> logs;
  final String templateName;
  final bool templateIsDeleted;

  Firmware({
    required this.firmwareId,
    required this.version,
    required this.name,
    required this.filePath,
    required this.templateId,
    required this.isMandatory,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    this.testedAt,
    required this.isApproved,
    this.note,
    required this.logs,
    required this.templateName,
    required this.templateIsDeleted,
  });

  factory Firmware.fromJson(Map<String, dynamic> json) {
    return Firmware(
      firmwareId: json['firmware_id'] as int,
      version: json['version'] as String,
      name: json['name'] as String,
      filePath: json['file_path'] as String,
      templateId: json['template_id'] as int,
      isMandatory: json['is_mandatory'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] == 1,
      testedAt: json['tested_at'] != null ? DateTime.parse(json['tested_at'] as String) : null,
      isApproved: json['is_approved'] == 1,
      note: json['note'] as String?,
      logs: (json['logs'] as List<dynamic>).map((e) => FirmwareLog.fromJson(e)).toList(),
      templateName: json['template_name'] as String,
      templateIsDeleted: json['template_is_deleted'] == 1,
    );
  }
}

class FirmwareLog {
  final String employee;
  final String logType;
  final DateTime createdAt;
  final String? employeeId;
  final String logMessage;

  FirmwareLog({
    required this.employee,
    required this.logType,
    required this.createdAt,
    this.employeeId,
    required this.logMessage,
  });

  factory FirmwareLog.fromJson(Map<String, dynamic> json) {
    return FirmwareLog(
      employee: json['employee'] as String,
      logType: json['log_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      employeeId: json['employee_id'] as String?,
      logMessage: json['log_message'] as String,
    );
  }
}
