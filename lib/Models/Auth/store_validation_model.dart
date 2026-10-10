// models/store_validation_model.dart

class StoreValidationResponse {
  //Build #1.0.42: Added by Naveen
  final bool success;
  final String message;
  final int userId;
  final String username;
  final String email;
  final String merchantId;
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
    this.deviceDisplayName = '',
    this.deviceTableId = '',
    this.storeGstin = '',
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

    final storeBaseUrl = dataMap['storeUrl']?.toString() ??
        storeMap['storeWebsiteUrl']?.toString() ??
        dataMap['store_base_url']?.toString() ??
        '';

    final email = merchantMap['email']?.toString() ??
        dataMap['email']?.toString() ??
        '';

    final username = merchantMap['businessDisplayName']?.toString() ??
        dataMap['username']?.toString() ??
        '';

    return StoreValidationResponse(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      userId: int.tryParse(dataMap['user_id']?.toString() ?? '') ?? 0,
      username: username,
      email: email,
      merchantId: extractedMerchantId,
      storeId: extractedStoreId,
      subscriptionType: dataMap['subscription_type']?.toString() ?? '',
      storeInfo: dataMap['store_info']?.toString() ?? '',
      storeName: storeName,
      storeLogo: storeMap['storeLogo']?.toString() ?? dataMap['store_logo']?.toString() ?? '',
      expirationDate: dataMap['expiration_date']?.toString() ?? '',
      deviceImeis: dataMap['device_imeis'] is List ? dataMap['device_imeis'] as List : [],
      storeBaseUrl: storeBaseUrl,
      storeAddress: storeMap['addressLine1']?.toString() ?? dataMap['store_address']?.toString() ?? '',
      storePhone: merchantMap['phone']?.toString() ?? dataMap['store_phone']?.toString() ?? '',
      licenseKey: dataMap['license_key']?.toString() ?? '',
      licenseStatus: dataMap['license_status']?.toString() ?? '',
      deviceDisplayName: dataMap['device_display_name'] as String? ?? '',
      deviceTableId: dataMap['device_table_id']?.toString() ?? '',
      storeGstin: dataMap['store_gstin'] as String? ?? '',
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
      'device_display_name': deviceDisplayName,
      'device_table_id': deviceTableId,
      'store_gstin': storeGstin,
    };
  }
}
