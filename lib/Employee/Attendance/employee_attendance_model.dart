class AttendanceEmployee {
  const AttendanceEmployee({
    required this.employeeCode,
    required this.name,
    this.isRegistered = true,
  });

  /// Use employees.employee_code here, not the employee UUID.
  final String employeeCode;
  final String name;
  final bool isRegistered;
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

  bool get isOpen => clockOut == null && status.toUpperCase() == 'PRESENT';

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
}
