class DeviceActivationRequest {
  final String activationCode;
  final String deviceFingerprint;
  final String appVersion;
  final String platform;

  const DeviceActivationRequest({
    required this.activationCode,
    required this.deviceFingerprint,
    required this.appVersion,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
        'activationCode': activationCode,
        'deviceFingerprint': deviceFingerprint,
        'appVersion': appVersion,
        'platform': platform,
      };
}

class DeviceActivationResult {
  final String deviceToken;
  final String merchantId;
  final String storeId;
  final String deviceId;
  final String status;

  const DeviceActivationResult({
    required this.deviceToken,
    required this.merchantId,
    required this.storeId,
    required this.deviceId,
    required this.status,
  });

  factory DeviceActivationResult.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    return DeviceActivationResult(
      deviceToken: (map['deviceToken'] as String?) ??
          (map['device_token'] as String?) ??
          (map['token'] as String?) ??
          '',
      merchantId: (map['merchantId'] as String?) ??
          (map['merchant_id'] as String?) ??
          '',
      storeId: (map['storeId'] as String?) ??
          (map['store_id'] as String?) ??
          '',
      deviceId: (map['deviceId'] as String?) ??
          (map['device_id'] as String?) ??
          '',
      status: (map['status'] as String?) ?? 'ACTIVE',
    );
  }
}
