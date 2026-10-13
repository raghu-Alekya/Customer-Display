// models/store_validation_model.dart
<<<<<<< HEAD
class StoreValidationResponse { //Build #1.0.42: Added by Naveen
=======

class StoreValidationResponse {
  //Build #1.0.42: Added by Naveen
>>>>>>> origin/Grocery_pch_api_integration
  final bool success;
  final String message;
  final int userId;
  final String username;
  final String email;
<<<<<<< HEAD
=======
  final String merchantId;
>>>>>>> origin/Grocery_pch_api_integration
  final String storeId;
  final String subscriptionType;
  final String storeInfo;
  final String storeName;
<<<<<<< HEAD
  final String storeLogo; // ✅ Added storeLogo
=======
  final String storeLogo;
>>>>>>> origin/Grocery_pch_api_integration
  final String expirationDate;
  final List<dynamic> deviceImeis;
  final String storeBaseUrl;
  final String storeAddress;
  final String storePhone;
  final String licenseKey;
  final String licenseStatus;
<<<<<<< HEAD
=======
  // Build #offline: terminal identity
  final String deviceDisplayName;
  final String deviceTableId;
  final String storeGstin;
>>>>>>> origin/Grocery_pch_api_integration

  StoreValidationResponse({
    required this.success,
    required this.message,
    required this.userId,
    required this.username,
    required this.email,
<<<<<<< HEAD
=======
    this.merchantId = '',
>>>>>>> origin/Grocery_pch_api_integration
    required this.storeId,
    required this.subscriptionType,
    required this.storeInfo,
    required this.storeName,
<<<<<<< HEAD
    required this.storeLogo, // ✅ constructor
=======
    required this.storeLogo,
>>>>>>> origin/Grocery_pch_api_integration
    required this.expirationDate,
    required this.deviceImeis,
    required this.storeBaseUrl,
    required this.storeAddress,
    required this.storePhone,
    required this.licenseKey,
    required this.licenseStatus,
<<<<<<< HEAD
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
      storeLogo: json['store_logo'] ?? '', // ✅ map JSON
      expirationDate: json['expiration_date'] ?? '',
      deviceImeis: json['device_imeis'] ?? [],
      storeBaseUrl: json['store_base_url'] ?? '',
      storeAddress: json['store_address'] ?? '',
      storePhone: json['store_phone'] ?? '',
      licenseKey: json['license_key'] ?? '',
      licenseStatus: json['license_status'] ?? '',
=======
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
>>>>>>> origin/Grocery_pch_api_integration
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'user_id': userId,
      'username': username,
      'email': email,
<<<<<<< HEAD
=======
      'merchant_id': merchantId,
>>>>>>> origin/Grocery_pch_api_integration
      'store_id': storeId,
      'subscription_type': subscriptionType,
      'store_info': storeInfo,
      'store_name': storeName,
<<<<<<< HEAD
      'store_logo': storeLogo, // ✅ include in JSON
=======
      'store_logo': storeLogo,
>>>>>>> origin/Grocery_pch_api_integration
      'expiration_date': expirationDate,
      'device_imeis': deviceImeis,
      'store_base_url': storeBaseUrl,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'license_key': licenseKey,
      'license_status': licenseStatus,
<<<<<<< HEAD
=======
      'device_display_name': deviceDisplayName,
      'device_table_id': deviceTableId,
      'store_gstin': storeGstin,
>>>>>>> origin/Grocery_pch_api_integration
    };
  }
}
