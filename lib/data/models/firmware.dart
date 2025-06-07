class Firmware {
  final int firmwareId;
  final String version;
  final String name;
  final String filePath;
  final int templateId;
  final bool isMandatory;
  final DateTime? createdAt;  // Made nullable
  final DateTime? updatedAt;  // Made nullable
  final bool isDeleted;
  final DateTime? testedAt;
  final bool isApproved;
  final String? note;
  final List<dynamic> logs;  // Changed to List<dynamic> to handle raw JSON
  final String templateName;
  final bool templateIsDeleted;

  Firmware({
    required this.firmwareId,
    required this.version,
    required this.name,
    required this.filePath,
    required this.templateId,
    required this.isMandatory,
    this.createdAt,  // Made optional
    this.updatedAt,  // Made optional
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
      firmwareId: json['firmware_id'] ?? 0,
      version: json['version'] ?? '',
      name: json['name'] ?? '',
      filePath: json['file_path'] ?? '',
      templateId: json['template_id'] ?? 0,
      isMandatory: json['is_mandatory'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isDeleted: json['is_deleted'] == 1,
      testedAt: json['tested_at'] != null ? DateTime.parse(json['tested_at']) : null,
      isApproved: json['is_approved'] == 1,
      note: json['note'],
      logs: (json['logs'] as List<dynamic>?) ?? [],
      templateName: json['template_name'] ?? '',
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
