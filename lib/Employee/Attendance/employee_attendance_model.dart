class AttendanceEmployee {
  const AttendanceEmployee({
    required this.employeeCode,
    required this.name,
    this.isRegistered = true,
    this.loginPin,
    this.roleName,
  });

  final String employeeCode;
  final String name;
  final bool isRegistered;
  final String? loginPin;
  final String? roleName;

  factory AttendanceEmployee.fromJson(Map<String, dynamic> json) {
    final firstName = (json['firstName'] ?? '').toString().trim();
    final lastName = (json['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    return AttendanceEmployee(
      employeeCode: (json['employeeCode'] ?? '').toString(),
      name: fullName.isNotEmpty
          ? fullName
          : (json['name'] ?? json['username'] ?? 'Employee').toString(),
      isRegistered: json['pinSet'] == true ||
          json['loginPin'] != null ||
          json['isRegistered'] == true,
      loginPin: json['loginPin']?.toString(),
      roleName: json['roleName']?.toString() ?? 'Staff',
    );
  }

  Map<String, dynamic> toJson() => {
    'employeeCode': employeeCode,
    'name': name,
    'isRegistered': isRegistered,
    if (loginPin != null) 'loginPin': loginPin,
    if (roleName != null) 'roleName': roleName,
  };
}

class EmployeeAttendanceRecord {
  const EmployeeAttendanceRecord({
    required this.id,
    required this.employeeCode,
    required this.employeeName,
    required this.clockIn,
    required this.status,
    this.clockOut,
  });

  final String id;
  final String employeeCode;
  final String employeeName;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String status;

  bool get isOpen => clockOut == null && (status.toUpperCase() == 'PRESENT' || status.toUpperCase() == 'INCOMPLETE');

  factory EmployeeAttendanceRecord.fromJson(Map<String, dynamic> json) {
    final clockInValue = json['clockIn'] ?? json['clock_in'];
    final clockIn = DateTime.tryParse(clockInValue?.toString() ?? '');
    if (clockIn == null) {
      throw const FormatException('Attendance response has no valid clockIn.');
    }

    return EmployeeAttendanceRecord(
      id: (json['id'] ?? '').toString(),
      employeeCode:
      (json['employeeCode'] ?? json['employee_code'] ?? '').toString(),
      employeeName:
      (json['employeeName'] ?? json['employee_name'] ?? '').toString(),
      clockIn: clockIn,
      clockOut: DateTime.tryParse(
        (json['clockOut'] ?? json['clock_out'])?.toString() ?? '',
      ),
      status: (json['status'] ?? 'INCOMPLETE').toString().toUpperCase(),
    );
  }

  EmployeeAttendanceRecord copyWith({
    String? id,
    String? employeeCode,
    String? employeeName,
    DateTime? clockIn,
    DateTime? clockOut,
    String? status,
  }) {
    return EmployeeAttendanceRecord(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      employeeName: employeeName ?? this.employeeName,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      status: status ?? this.status,
    );
  }
}
//
// class EmployeeAttendanceRecord {
//   const EmployeeAttendanceRecord({
//     required this.id,
//     required this.employeeCode,
//     required this.employeeName,
//     required this.clockIn,
//     required this.status,
//     this.clockOut,
//   });
//
//   final String id;
//   final String employeeCode;
//   final String employeeName;
//   final DateTime clockIn;
//   final DateTime? clockOut;
//   final String status;
//
//   bool get isOpen => clockOut == null && status.toUpperCase() == 'PRESENT';
//
//   factory EmployeeAttendanceRecord.fromJson(Map<String, dynamic> json) {
//     final clockInValue = json['clockIn'] ?? json['clock_in'];
//     final clockIn = DateTime.tryParse(clockInValue?.toString() ?? '');
//     if (clockIn == null) {
//       throw const FormatException('Attendance response has no valid clockIn.');
//     }
//
//     return EmployeeAttendanceRecord(
//       id: (json['id'] ?? '').toString(),
//       employeeCode:
//       (json['employeeCode'] ?? json['employee_code'] ?? '').toString(),
//       employeeName:
//       (json['employeeName'] ?? json['employee_name'] ?? '').toString(),
//       clockIn: clockIn,
//       clockOut: DateTime.tryParse(
//         (json['clockOut'] ?? json['clock_out'])?.toString() ?? '',
//       ),
//       status: (json['status'] ?? 'INCOMPLETE').toString().toUpperCase(),
//     );
//   }
// }
