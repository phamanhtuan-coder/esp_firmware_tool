class Firmware {
  final String firmwareId;
  final String version;
  final String name;
  final String filePath;
  final String templateId;
  final bool isMandatory;
  final DateTime? createdAt;  // Made nullable
  final DateTime? updatedAt;  // Made nullable
  final bool isDeleted;
  final DateTime? testedAt;
  final bool isApproved;
  final String? note;
  final dynamic logs;  // Changed to dynamic to handle raw JSON
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
    // Helper function to convert int to bool
    bool intToBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    return Firmware(
      firmwareId: json['firmware_id']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      templateId: json['template_id']?.toString() ?? '',
      isMandatory: intToBool(json['is_mandatory']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isDeleted: intToBool(json['is_deleted']),
      testedAt: json['tested_at'] != null ? DateTime.parse(json['tested_at']) : null,
      isApproved: intToBool(json['is_approved']),
      note: json['note']?.toString(),
      logs: json['logs'],
      templateName: json['template_name']?.toString() ?? '',
      templateIsDeleted: intToBool(json['template_is_deleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firmware_id': firmwareId,
      'version': version,
      'name': name,
      'file_path': filePath,
      'template_id': templateId,
      'is_mandatory': isMandatory ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'tested_at': testedAt?.toIso8601String(),
      'is_approved': isApproved ? 1 : 0,
      'note': note,
      'logs': logs,
      'template_name': templateName,
      'template_is_deleted': templateIsDeleted ? 1 : 0,
    };
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
