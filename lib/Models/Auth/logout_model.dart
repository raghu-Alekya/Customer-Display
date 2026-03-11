// Build #1.0.163: Added Logout Model
class LogoutResponse {
  final bool success;
  final int statusCode;
  final String code;
  final String message;
  final List<dynamic> data;

  LogoutResponse({
    required this.success,
    required this.statusCode,
    required this.code,
    required this.message,
    required this.data,
  });

  factory LogoutResponse.fromJson(Map<String, dynamic> json) {
    return LogoutResponse(
      success: json['success'] ?? false,
      statusCode: json['statusCode'] ?? 0,
      code: json['code'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] ?? [],
    );
  }
}

// Build #1.0.166: Added LogoutRequest Model
class LogoutRequest {
  final int empLoginPin;

  LogoutRequest(this.empLoginPin);

  Map<String, dynamic> toJson() => {'emp_login_pin': empLoginPin};
}