import '../../Helper/url_helper.dart';

/// PCH API configuration. Point [baseUrl] at the PCH gateway when available.
class PchConfig {
  PchConfig._();

  /// Default PCH REST base URL (legacy guide host).
  static const String baseUrl = 'https://api.pinakacommerce.com';

  /// Attendance / POS APIs use the same connector base as the rest of the app
  /// (https://pch.alektasolutions.com/connector/api/v1/).
  /// Falls back to [baseUrl] only if UrlHelper is not initialized.
  static String get attendanceBaseUrl {
    try {
      final url = UrlHelper.baseUrl;
      if (url.trim().isNotEmpty) return url;
    } catch (_) {}
    return baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
