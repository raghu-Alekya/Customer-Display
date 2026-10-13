class EmployeeSession {
  final String userId;
  final String accessToken;
  final String refreshToken;

  const EmployeeSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });
}

class PosLoginRequest {
  final String employeePin;
  final String deviceId;
  final String storeId;

  const PosLoginRequest({
    required this.employeePin,
    required this.deviceId,
    required this.storeId,
  });

  Map<String, dynamic> toJson() => {
        'employeePin': employeePin,
        'deviceId': deviceId,
        'storeId': storeId,
      };
}

class PosLoginResult {
  final EmployeeSession session;

  const PosLoginResult({required this.session});
}

class OfflineLoginPolicy {
  final bool offlineLoginEnabled;
  final int offlineCredentialTtlHours;

  const OfflineLoginPolicy({
    this.offlineLoginEnabled = true,
    this.offlineCredentialTtlHours = 72,
  });
}
