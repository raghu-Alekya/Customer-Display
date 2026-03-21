// models/store_validation_model.dart
import 'dart:convert';

class StoreValidationResponse { //Build #1.0.42: Added by Naveen
  final bool success;
  final String message;
  final int userId;
  final String username;
  final String email;
  final String storeId;
  final String subscriptionType;
  final String storeInfo;
  final String storeName;
  final String storeLogo; // ✅ Added storeLogo
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
    required this.storeId,
    required this.subscriptionType,
    required this.storeInfo,
    required this.storeName,
    required this.storeLogo, // ✅ constructor
    required this.expirationDate,
    required this.deviceImeis,
    required this.storeBaseUrl,
    required this.storeAddress,
    required this.storePhone,
    required this.licenseKey,
    required this.licenseStatus,
  });

  /// Best label for customer display / MQTT when API uses odd keys or `store_name` is empty / generic.
  String get displayStoreName {
    final fromInfo = _parseNameFromStoreInfo(storeInfo);
    final primary = storeName.trim();

    // Prefer a non-empty real name; skip generic API placeholder "Merchant" if we have better data.
    if (primary.isNotEmpty && primary.toLowerCase() != 'merchant') {
      return primary;
    }
    if (fromInfo != null && fromInfo.isNotEmpty) {
      return fromInfo;
    }
    final u = username.trim();
    if (u.isNotEmpty) return u;
    final sid = storeId.trim();
    if (sid.isNotEmpty) return 'Store $sid';
    if (primary.isNotEmpty) return primary;
    return '';
  }

  static String? _parseNameFromStoreInfo(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return _firstNonEmptyInMap(Map<String, dynamic>.from(raw));
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      final decoded = json.decode(s);
      if (decoded is Map) {
        return _firstNonEmptyInMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  static String? _firstNonEmptyInMap(Map<String, dynamic> map) {
    const keys = [
      'store_name',
      'name',
      'storeName',
      'company_name',
      'site_name',
      'blogname',
      'store',
      'title',
    ];
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  static String _readStoreNameFromJson(Map<String, dynamic> json) {
    const keys = [
      'store_name',
      'name',
      'storeName',
      'company_name',
      'site_name',
    ];
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    final fromInfo = _parseNameFromStoreInfo(json['store_info']);
    return fromInfo ?? '';
  }

  factory StoreValidationResponse.fromJson(Map<String, dynamic> json) {
    return StoreValidationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      storeId: json['store_id'] ?? '',
      subscriptionType: json['subscription_type'] ?? '',
      storeInfo: json['store_info']?.toString() ?? '',
      storeName: _readStoreNameFromJson(json),
      storeLogo: json['store_logo'] ?? '', // ✅ map JSON
      expirationDate: json['expiration_date'] ?? '',
      deviceImeis: json['device_imeis'] ?? [],
      storeBaseUrl: json['store_base_url'] ?? '',
      storeAddress: json['store_address'] ?? '',
      storePhone: json['store_phone'] ?? '',
      licenseKey: json['license_key'] ?? '',
      licenseStatus: json['license_status'] ?? '',
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
      'store_logo': storeLogo, // ✅ include in JSON
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
