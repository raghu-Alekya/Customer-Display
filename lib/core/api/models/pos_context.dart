class PosContext {
  final String merchantId;
  final String storeId;
  final String deviceId;
  final String? userId;

  const PosContext({
    required this.merchantId,
    required this.storeId,
    required this.deviceId,
    this.userId,
  });

  PosContext copyWith({String? userId}) => PosContext(
        merchantId: merchantId,
        storeId: storeId,
        deviceId: deviceId,
        userId: userId ?? this.userId,
      );

  Map<String, dynamic> toJson() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'deviceId': deviceId,
        'userId': userId,
      };

  factory PosContext.fromJson(Map<String, dynamic> json) => PosContext(
        merchantId: json['merchantId'] as String,
        storeId: json['storeId'] as String,
        deviceId: json['deviceId'] as String,
        userId: json['userId'] as String?,
      );
}
