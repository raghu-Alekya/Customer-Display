class PchException implements Exception {
  final String code;
  final String message;
  final String? correlationId;

  const PchException({
    required this.code,
    required this.message,
    this.correlationId,
  });

  factory PchException.fromResponseData(
    dynamic data, {
    String? fallbackCorrelationId,
  }) {
    if (data is Map<String, dynamic>) {
      return PchException(
        code: (data['code'] as String?) ?? 'UNKNOWN_ERROR',
        message: (data['message'] as String?) ?? 'Something went wrong',
        correlationId:
            (data['correlationId'] as String?) ?? fallbackCorrelationId,
      );
    }
    return PchException(
      code: 'NETWORK_UNAVAILABLE',
      message: data?.toString() ?? 'Unable to reach the server',
      correlationId: fallbackCorrelationId,
    );
  }

  bool get isTokenExpired => code == 'TOKEN_EXPIRED';
  bool get isDeviceSuspended => code == 'DEVICE_SUSPENDED';
  bool get isStoreSuspended => code == 'STORE_SUSPENDED';
  bool get isNotAuthorized => code == 'EMPLOYEE_NOT_AUTHORIZED';
  bool get isNetworkError => code == 'NETWORK_UNAVAILABLE';

  @override
  String toString() =>
      'PchException($code): $message [correlationId=$correlationId]';
}
