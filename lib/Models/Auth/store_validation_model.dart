// models/store_validation_model.dart
class StoreValidationResponse {
  //Build #1.0.42: Added by Naveen
  final bool success;
  final String message;
  final int userId;
  final String username;
  final String email;
  final String storeId;
  final String subscriptionType;
  final String storeInfo;
  final String storeName;
  final String storeLogo;
  final String expirationDate;
  final List<dynamic> deviceImeis;
  final String storeBaseUrl;
  final String storeAddress;
  final String storePhone;
  final String licenseKey;
  final String licenseStatus;
  // Build #offline: terminal identity
  final String deviceDisplayName;
  final String deviceTableId;
  final String storeGstin;

  StoreValidationResponse({
    required this.success,
    required this.message,
    required this.userId,
    required this.username,
    required this.email,
    required this.storeId,
    required this.subscriptionType,
    required this.storeInfo,
    required this.storeName,
    required this.storeLogo,
    required this.expirationDate,
    required this.deviceImeis,
    required this.storeBaseUrl,
    required this.storeAddress,
    required this.storePhone,
    required this.licenseKey,
    required this.licenseStatus,
    this.deviceDisplayName = '',
    this.deviceTableId = '',
    this.storeGstin = '',
  });

  factory StoreValidationResponse.fromJson(Map<String, dynamic> json) {
    return StoreValidationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      storeId: json['store_id'] ?? '',
      subscriptionType: json['subscription_type'] ?? '',
      storeInfo: json['store_info'] ?? '',
      storeName: json['store_name'] ?? '',
      storeLogo: json['store_logo'] ?? '',
      expirationDate: json['expiration_date'] ?? '',
      deviceImeis: json['device_imeis'] ?? [],
      storeBaseUrl: json['store_base_url'] ?? '',
      storeAddress: json['store_address'] ?? '',
      storePhone: json['store_phone'] ?? '',
      licenseKey: json['license_key'] ?? '',
      licenseStatus: json['license_status'] ?? '',
      // Build #offline
      deviceDisplayName: json['device_display_name'] as String? ?? '',
      deviceTableId: json['device_table_id']?.toString() ?? '',
      storeGstin: json['store_gstin'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'user_id': userId,
      'username': username,
      'email': email,
      'store_id': storeId,
      'subscription_type': subscriptionType,
      'store_info': storeInfo,
      'store_name': storeName,
      'store_logo': storeLogo,
      'expiration_date': expirationDate,
      'device_imeis': deviceImeis,
      'store_base_url': storeBaseUrl,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'license_key': licenseKey,
      'license_status': licenseStatus,
      'device_display_name': deviceDisplayName,
      'device_table_id': deviceTableId,
      'store_gstin': storeGstin,
    };
  }
}
