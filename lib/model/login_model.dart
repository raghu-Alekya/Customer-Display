class LoginResponse {
  final bool success;
  final String message;
  final String storeName;
  final String storeLogo;
  final String licenseKey;

  LoginResponse({
    required this.success,
    required this.message,
    required this.storeName,
    required this.storeLogo,
    required this.licenseKey,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      storeName: json['store_name'] ?? '',
      storeLogo: (json['store_logo'] ?? '').toString().replaceAll('%22', ''),
      licenseKey: json['license_key'] ?? '',
    );
  }
}