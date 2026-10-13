import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'auth_client.dart';
import 'pch_config.dart';
import 'pos_context_provider.dart';
import 'token_storage.dart';

class PchClient {
  final Dio dio;
  final TokenStorage tokenStorage;
  final PosContextProvider contextProvider;

  AuthClient? _authClient;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshWaiters = [];

  PchClient({
    required String baseUrl,
    required this.tokenStorage,
    required this.contextProvider,
    String? appVersion,
    String? platform,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: PchConfig.connectTimeout,
            receiveTimeout: PchConfig.receiveTimeout,
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getAccessToken();
          final deviceToken = await tokenStorage.getDeviceToken();
          final context = await contextProvider.getContext();

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          } else if (deviceToken != null) {
            options.headers['Authorization'] = 'Bearer $deviceToken';
          }

          if (context != null) {
            options.headers['X-Merchant-Id'] = context.merchantId;
            options.headers['X-Store-Id'] = context.storeId;
            options.headers['X-Device-Id'] = context.deviceId;
            if (context.userId != null) {
              options.headers['X-User-Id'] = context.userId;
            }
          }

          options.headers['X-Correlation-Id'] =
              options.extra['correlationId'] ?? const Uuid().v4();
          if (appVersion != null) {
            options.headers['X-App-Version'] = appVersion;
          }
          if (platform != null) {
            options.headers['X-Platform'] = platform.toLowerCase();
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final data = error.response?.data;
          final code = data is Map ? data['code'] as String? : null;
          final isExpired =
              error.response?.statusCode == 401 || code == 'TOKEN_EXPIRED';

          if (isExpired && _authClient != null) {
            final refreshed = await _refreshTokenSingleFlight();
            if (refreshed) {
              final request = error.requestOptions;
              final newToken = await tokenStorage.getAccessToken();
              request.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(request);
                return handler.resolve(response);
              } catch (_) {
                // fall through
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  void attachAuthClient(AuthClient authClient) {
    _authClient = authClient;
  }

  Future<bool> _refreshTokenSingleFlight() async {
    if (_authClient == null) return false;

    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshWaiters.add(completer);
      await completer.future;
      return (await tokenStorage.getAccessToken()) != null;
    }

    _isRefreshing = true;
    try {
      final refreshed = await _authClient!.refreshToken();
      for (final waiter in _refreshWaiters) {
        waiter.complete();
      }
      _refreshWaiters.clear();
      return refreshed;
    } finally {
      _isRefreshing = false;
    }
  }
}
