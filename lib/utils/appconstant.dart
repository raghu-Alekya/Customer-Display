class AppConstants {
  static String baseDomain = "";
  /// Fixed API namespace
  static const String apiNamespace = "pinaka-kiosk";

  /// Base API URL
  static String get baseUrl =>
      "$baseDomain/wp-json/$apiNamespace/v1";
  /// Merchant validation server
  static const String merchantBaseUrl =
      "https://test.alekyatechsolutions.com";

  /// Merchant Login API
  static String get merchantLoginEndpoint =>
      "$merchantBaseUrl/wp-json/custom/v1/validate-merchant";



  /// WooCommerce API Base
  static String get wcBaseUrl => "$baseDomain/wp-json/wc/v3";

  /// Store Details
  static String get storeDetailsEndpoint =>
      "$baseUrl/assets/store-details";

  /// Token API
  static String get tokenEndpoint =>
      "$baseUrl/token";

  /// Promotion Images
  static String get portraitPromotionImagesEndpoint =>
      "$baseUrl/orders/get-portrait-promotion-images";

  static String get fullScreenPromotionImagesEndpoint =>
      "$baseUrl/orders/get-full-screen-promotion-images";

  static String get bannerPromotionImagesEndpoint =>
      "$baseUrl/orders/get-banner-promotion-images";

  // Addon  this
  static String getModifiersByProductEndpoint(int productId) =>
      "$baseUrl/modifiers-addons/get-modifiers-by-product-id?product_id=$productId";


  // Payment API
  static String get createPaymentEndpoint =>
      "$baseUrl/payments/create-payment";

  /// Categories Endpoint
  static String get categoriesEndpoint =>
      "$wcBaseUrl/products/categories";
  /// Orders
  static String get ordersEndpoint =>
      "$baseUrl/orders";
  // products
  static String get productsByCategoryEndpoint =>
      "$baseUrl/products-by-category";

  static String get wcProductsEndpoint =>
      "$wcBaseUrl/products";

}