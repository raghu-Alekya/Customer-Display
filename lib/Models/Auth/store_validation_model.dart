// models/store_validation_model.dart

class StoreValidationResponse {
  //Build #1.0.42: Added by Naveen
  final bool success;
  final String message;
  final int userId;
  final String username;
  final String email;
  final String merchantId; // PCH: required for x-merchant-id headers
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

  StoreValidationResponse({
    required this.success,
    required this.message,
    required this.userId,
    required this.username,
    required this.email,
    this.merchantId = '',
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
  });

  factory StoreValidationResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> dataMap = {};
    if (json['data'] is Map<String, dynamic>) {
      dataMap = json['data'] as Map<String, dynamic>;
    } else {
      dataMap = json;
    }

    Map<String, dynamic> merchantMap = {};
    if (dataMap['merchant'] is Map<String, dynamic>) {
      merchantMap = dataMap['merchant'] as Map<String, dynamic>;
    }

    Map<String, dynamic> storeMap = {};
    if (dataMap['store'] is Map<String, dynamic>) {
      storeMap = dataMap['store'] as Map<String, dynamic>;
    }

    final String extractedMerchantId = merchantMap['id']?.toString() ??
        merchantMap['merchantId']?.toString() ??
        dataMap['merchantId']?.toString() ??
        dataMap['merchant_id']?.toString() ??
        '';

    final String extractedStoreId = storeMap['id']?.toString() ??
        dataMap['store_id']?.toString() ??
        dataMap['storeId']?.toString() ??
        storeMap['storeCode']?.toString() ??
        '';

    final storeName = storeMap['storeName']?.toString() ??
        storeMap['name']?.toString() ??
        dataMap['store_name']?.toString() ??
        dataMap['storeName']?.toString() ??
        '';

    return StoreValidationResponse(
      success: json['success'] ?? dataMap['success'] ?? true,
      message: (json['message'] ?? dataMap['message'] ?? '').toString(),
      userId: int.tryParse((dataMap['user_id'] ?? json['user_id'] ?? 0).toString()) ?? 0,
      username: (dataMap['username'] ?? json['username'] ?? merchantMap['identifier'] ?? '').toString(),
      email: (dataMap['email'] ?? json['email'] ?? merchantMap['email'] ?? '').toString(),
      merchantId: extractedMerchantId,
      storeId: extractedStoreId,
      subscriptionType: (dataMap['subscription_type'] ?? json['subscription_type'] ?? '').toString(),
      storeInfo: (dataMap['store_info'] ?? storeMap['storeInfo'] ?? '').toString(),
      storeName: storeName,
      storeLogo: (dataMap['store_logo'] ?? storeMap['logo'] ?? json['store_logo'] ?? '').toString(),
      expirationDate: (dataMap['expiration_date'] ?? json['expiration_date'] ?? '').toString(),
      deviceImeis: dataMap['device_imeis'] ?? json['device_imeis'] ?? [],
      storeBaseUrl: (dataMap['store_base_url'] ?? storeMap['baseUrl'] ?? json['store_base_url'] ?? '').toString(),
      storeAddress: (dataMap['store_address'] ?? storeMap['address'] ?? '').toString(),
      storePhone: (dataMap['store_phone'] ?? storeMap['phone'] ?? '').toString(),
      licenseKey: (dataMap['license_key'] ?? json['license_key'] ?? '').toString(),
      licenseStatus: (dataMap['license_status'] ?? json['license_status'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'user_id': userId,
      'username': username,
      'email': email,
      'merchant_id': merchantId,
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
    };
  }
}
