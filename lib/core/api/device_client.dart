import 'package:dio/dio.dart';

import 'models/device_activation.dart';
import 'pch_client.dart';
import 'pch_exception.dart';

class DeviceClient {
  final PchClient client;

  DeviceClient(this.client);

  Future<DeviceActivationResult> activate(DeviceActivationRequest request) async {
    try {
      final response = await client.dio.post(
        '/v1/device-activations',
        data: request.toJson(),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const PchException(
          code: 'INVALID_RESPONSE',
          message: 'Unexpected response from device activation.',
        );
      }

      return DeviceActivationResult.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  PchException _mapDioError(DioException error) {
    final correlationId = error.response?.headers.value('X-Correlation-Id');
    final data = error.response?.data;

    if (data != null) {
      return PchException.fromResponseData(
        data is Map<String, dynamic> ? data : {'message': data.toString()},
        fallbackCorrelationId: correlationId,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return PchException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Unable to reach PCH. Check your connection and try again.',
        correlationId: correlationId,
      );
    }

    return PchException(
      code: 'UNKNOWN_ERROR',
      message: error.message ?? 'Device activation failed.',
      correlationId: correlationId,
    );
  }
}
