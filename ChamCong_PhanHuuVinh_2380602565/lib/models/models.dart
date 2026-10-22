class UserModel {
  final String userName;
  final String fullName;
  final String role;
  final String accessToken;
  final int expiresInSeconds;

  UserModel({
    required this.userName,
    required this.fullName,
    required this.role,
    required this.accessToken,
    required this.expiresInSeconds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userName: json['userName'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'Employee',
      accessToken: json['accessToken'] ?? '',
      expiresInSeconds: json['expiresInSeconds'] ?? 1800,
    );
  }
}

class DepartmentModel {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      description: json['description'] ?? json['Description'],
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'isActive': isActive,
  };
}

class ShiftModel {
  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final bool isActive;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.isActive,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      startTime: json['startTime'] ?? json['StartTime'] ?? '',
      endTime: json['endTime'] ?? json['EndTime'] ?? '',
      graceMinutes: json['graceMinutes'] ?? json['GraceMinutes'] ?? 5,
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'startTime': startTime,
    'endTime': endTime,
    'graceMinutes': graceMinutes,
    'isActive': isActive,
  };
}

class WorkLocationModel {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int allowedRadiusMeters;
  final bool isActive;

  WorkLocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusMeters,
    required this.isActive,
  });

  factory WorkLocationModel.fromJson(Map<String, dynamic> json) {
    return WorkLocationModel(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      address: json['address'] ?? json['Address'] ?? '',
      latitude: (json['latitude'] ?? json['Latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['Longitude'] ?? 0.0).toDouble(),
      allowedRadiusMeters:
          json['allowedRadiusMeters'] ?? json['AllowedRadiusMeters'] ?? 100,
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'allowedRadiusMeters': allowedRadiusMeters,
    'isActive': isActive,
  };
}

class EmployeeModel {
  final int employeeId;
  final String employeeCode;
  final String userName;
  final String fullName;
  final String email;
  final bool emailConfirmed;
  final bool isActive;
  final bool? userActive;
  final int? departmentId;
  final String? departmentName;
  final String? hireDate;

  bool get isFullyActive => isActive && (userActive ?? isActive);

  EmployeeModel({
    required this.employeeId,
    required this.employeeCode,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.emailConfirmed,
    required this.isActive,
    this.userActive,
    this.departmentId,
    this.departmentName,
    this.hireDate,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      employeeId: json['employeeId'] ?? 0,
      employeeCode: json['employeeCode'] ?? '',
      userName: json['userName'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      emailConfirmed: json['emailConfirmed'] ?? false,
      isActive: json['isActive'] ?? false,
      userActive: json['userActive'],
      departmentId: json['departmentId'],
      departmentName: json['departmentName'],
      hireDate: json['hireDate'],
    );
  }
}

class ShiftAssignmentModel {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final int shiftId;
  final String shiftName;
  final String startTime;
  final String endTime;
  final int? graceMinutes;
  final int workLocationId;
  final String locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final int? allowedRadiusMeters;
  final String workDate;
  final String status;
  final bool hasAttendance;

  ShiftAssignmentModel({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.shiftId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    this.graceMinutes,
    required this.workLocationId,
    required this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.allowedRadiusMeters,
    required this.workDate,
    required this.status,
    required this.hasAttendance,
  });

  factory ShiftAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ShiftAssignmentModel(
      id: json['id'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      employeeCode: json['employeeCode'] ?? '',
      employeeName: json['employeeName'] ?? '',
      shiftId: json['shiftId'] ?? 0,
      shiftName: json['shiftName'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      graceMinutes: json['graceMinutes'],
      workLocationId: json['workLocationId'] ?? 0,
      locationName: json['locationName'] ?? '',
      locationAddress: json['locationAddress'],
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      allowedRadiusMeters: json['allowedRadiusMeters'],
      workDate: json['workDate'] ?? '',
      status: json['status'] ?? 'Scheduled',
      hasAttendance: json['hasAttendance'] ?? false,
    );
  }
}

class AttendanceRecordModel {
  final int id;
  final int shiftAssignmentId;
  final int? employeeId;
  final String? employeeCode;
  final String? employeeName;
  final String? departmentName;
  final String workDate;
  final String shiftName;
  final String locationName;
  final String? checkInUtc;
  final String? checkOutUtc;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? checkInStatus;

  AttendanceRecordModel({
    required this.id,
    required this.shiftAssignmentId,
    this.employeeId,
    this.employeeCode,
    this.employeeName,
    this.departmentName,
    required this.workDate,
    required this.shiftName,
    required this.locationName,
    this.checkInUtc,
    this.checkOutUtc,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInStatus,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] ?? 0,
      shiftAssignmentId: json['shiftAssignmentId'] ?? 0,
      employeeId: json['employeeId'],
      employeeCode: json['employeeCode'],
      employeeName: json['employeeName'],
      departmentName: json['departmentName'],
      workDate: json['workDate'] ?? '',
      shiftName: json['shiftName'] ?? '',
      locationName: json['locationName'] ?? '',
      checkInUtc: json['checkInUtc'],
      checkOutUtc: json['checkOutUtc'],
      checkInLatitude: json['checkInLatitude'] != null
          ? (json['checkInLatitude'] as num).toDouble()
          : null,
      checkInLongitude: json['checkInLongitude'] != null
          ? (json['checkInLongitude'] as num).toDouble()
          : null,
      checkOutLatitude: json['checkOutLatitude'] != null
          ? (json['checkOutLatitude'] as num).toDouble()
          : null,
      checkOutLongitude: json['checkOutLongitude'] != null
          ? (json['checkOutLongitude'] as num).toDouble()
          : null,
      checkInStatus: json['checkInStatus'],
    );
  }
}

class LocationShareModel {
  final int? id;
  final int? employeeId;
  final String? employeeCode;
  final String? fullName;
  final String? departmentName;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String sharedAtUtc;
  final String? note;

  LocationShareModel({
    this.id,
    this.employeeId,
    this.employeeCode,
    this.fullName,
    this.departmentName,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.sharedAtUtc,
    this.note,
  });

  factory LocationShareModel.fromJson(Map<String, dynamic> json) {
    final loc = json['latestLocation'] ?? json;
    return LocationShareModel(
      id: loc['id'] ?? loc['Id'],
      employeeId: json['employeeId'],
      employeeCode: json['employeeCode'],
      fullName: json['fullName'],
      departmentName: json['departmentName'],
      latitude: (loc['latitude'] ?? loc['Latitude'] ?? 0.0).toDouble(),
      longitude: (loc['longitude'] ?? loc['Longitude'] ?? 0.0).toDouble(),
      accuracyMeters: loc['accuracyMeters'] != null
          ? (loc['accuracyMeters'] as num).toDouble()
          : null,
      sharedAtUtc: loc['sharedAtUtc'] ?? loc['SharedAtUtc'] ?? '',
      note: loc['note'] ?? loc['Note'],
    );
  }
}

class AttendanceAppealModel {
  final int id;
  final int? employeeId;
  final String? employeeCode;
  final String? employeeName;
  final String? departmentName;
  final int shiftAssignmentId;
  final String workDate;
  final String shiftName;
  final String locationName;
  final String reason;
  final String status;
  final String? reviewNote;
  final String? reviewedBy;
  final String submittedAtUtc;
  final String? reviewedAtUtc;

  AttendanceAppealModel({
    required this.id,
    this.employeeId,
    this.employeeCode,
    this.employeeName,
    this.departmentName,
    required this.shiftAssignmentId,
    required this.workDate,
    required this.shiftName,
    required this.locationName,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.reviewedBy,
    required this.submittedAtUtc,
    this.reviewedAtUtc,
  });

  factory AttendanceAppealModel.fromJson(Map<String, dynamic> json) {
    return AttendanceAppealModel(
      id: json['id'] ?? 0,
      employeeId: json['employeeId'],
      employeeCode: json['employeeCode'],
      employeeName: json['employeeName'],
      departmentName: json['departmentName'],
      shiftAssignmentId: json['shiftAssignmentId'] ?? 0,
      workDate: json['workDate'] ?? '',
      shiftName: json['shiftName'] ?? '',
      locationName: json['locationName'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'Pending',
      reviewNote: json['reviewNote'],
      reviewedBy: json['reviewedBy'],
      submittedAtUtc: json['submittedAtUtc'] ?? '',
      reviewedAtUtc: json['reviewedAtUtc'],
    );
  }
}

class DashboardStatsModel {
  final int totalEmployees;
  final int activeEmployees;
  final int pendingEmployees;
  final int totalDepartments;
  final int totalShifts;
  final int totalLocations;

  DashboardStatsModel({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.pendingEmployees,
    required this.totalDepartments,
    required this.totalShifts,
    required this.totalLocations,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalEmployees: json['totalEmployees'] ?? 0,
      activeEmployees: json['activeEmployees'] ?? 0,
      pendingEmployees: json['pendingEmployees'] ?? 0,
      totalDepartments: json['totalDepartments'] ?? 0,
      totalShifts: json['totalShifts'] ?? 0,
      totalLocations: json['totalLocations'] ?? 0,
    );
  }
}

class AppealSuggestionModel {
  final int shiftAssignmentId;
  final String workDate;
  final String shiftName;
  final String locationName;
  final String anomalyType;
  final String anomalyDescription;
  final String suggestedReason;

  AppealSuggestionModel({
    required this.shiftAssignmentId,
    required this.workDate,
    required this.shiftName,
    required this.locationName,
    required this.anomalyType,
    required this.anomalyDescription,
    required this.suggestedReason,
  });

  factory AppealSuggestionModel.fromJson(Map<String, dynamic> json) {
    return AppealSuggestionModel(
      shiftAssignmentId: json['shiftAssignmentId'] ?? 0,
      workDate: json['workDate']?.toString() ?? '',
      shiftName: json['shiftName'] ?? '',
      locationName: json['locationName'] ?? '',
      anomalyType: json['anomalyType'] ?? '',
      anomalyDescription: json['anomalyDescription'] ?? '',
      suggestedReason: json['suggestedReason'] ?? '',
    );
  }
}
