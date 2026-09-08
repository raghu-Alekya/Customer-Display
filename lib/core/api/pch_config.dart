/// PCH API configuration. Point [baseUrl] at the PCH gateway when available.
class PchConfig {
  PchConfig._();

  /// PCH REST base URL (guide: https://api.pinakacommerce.com).
  static const String baseUrl = 'https://api.pinakacommerce.com';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
