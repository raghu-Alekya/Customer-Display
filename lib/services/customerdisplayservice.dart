import 'package:flutter/services.dart';

class CustomerDisplayService {
  static const MethodChannel _platform =
<<<<<<< HEAD
  MethodChannel('com.example.flutter_customer_display/sunmi_display');
=======
  MethodChannel('com.alekta.pinakapos/sunmi_display');
>>>>>>> origin/Grocery_pch_api_integration

  /// 🔹 Show default welcome screen
  static Future<void> showWelcome() async {
    try {
      print("📢 [CustomerDisplayService] showWelcome() called");
      await _platform.invokeMethod('showWelcome');
      print("✅ [CustomerDisplayService] Welcome screen displayed");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show welcome: $e");
    }
  }

  /// 🔹 Show Thank You screen, then revert to welcome after 5 seconds
  static Future<void> showThankYou({int delaySeconds = 5}) async {
    try {
      print("📢 [CustomerDisplayService] showThankYou() called");
      await _platform.invokeMethod('showThankYou');
      print("✅ [CustomerDisplayService] Thank You screen displayed");
<<<<<<< HEAD

      // Revert to welcome automatically
      Future.delayed(Duration(seconds: delaySeconds), () async {
        print("🔄 [CustomerDisplayService] Reverting to welcome screen");
        await showWelcome();
      });
=======
>>>>>>> origin/Grocery_pch_api_integration
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show Thank You: $e");
    }
  }

<<<<<<< HEAD
=======
  static Future<void> resetDisplay() async {
    try {
      print("📢 [CustomerDisplayService] resetDisplay() called");
      await _platform.invokeMethod('resetDisplay');
      print("✅ [CustomerDisplayService] Display reset");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to reset display: $e");
    }
  }

>>>>>>> origin/Grocery_pch_api_integration
  /// 🔹 Show welcome screen with store info and optional logo
  static Future<void> showWelcomeWithStore({
    required String storeId,
    required String storeName,
    String? storeLogoUrl,
<<<<<<< HEAD
  }) async {
    try {
      print(
          "📢 [CustomerDisplayService] showWelcomeWithStore → storeId=$storeId, storeName=$storeName, logo=$storeLogoUrl");

      await _platform.invokeMethod('showWelcomeWithStore', {
        "storeId": storeId,
        "storeName": storeName,
        "storeLogoUrl": storeLogoUrl ?? "",
=======
    String? storeBaseUrl,
    List<String>? slideshowUrls,
    List<String>? banners,
  }) async {
    try {
      final logoStr = storeLogoUrl ?? "";
      final baseUrlStr = storeBaseUrl ?? "";
      final bannersList = slideshowUrls ?? banners ?? const <String>[];

      print(
          "📢 [CustomerDisplayService] showWelcomeWithStore → storeId=$storeId, storeName=$storeName, logo=$logoStr, banners=${bannersList.length}");

      await _platform.invokeMethod('showWelcomeWithStore', {
        "storeId": storeId,
        "store_id": storeId,
        "storeName": storeName,
        "store_name": storeName,
        "storeLogoUrl": logoStr,
        "store_logo_url": logoStr,
        "storeLogo": logoStr,
        "store_logo": logoStr,
        "logo": logoStr,
        "logoUrl": logoStr,
        "storeBaseUrl": baseUrlStr,
        "store_base_url": baseUrlStr,
        "slideshowUrls": bannersList,
        "slideshow_urls": bannersList,
        "banners": bannersList,
>>>>>>> origin/Grocery_pch_api_integration
      });

      print("✅ [CustomerDisplayService] Store welcome displayed");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show store welcome: $e");
    }
  }
<<<<<<< HEAD
=======

>>>>>>> origin/Grocery_pch_api_integration
  /// 🔹 Send order data to customer display
  static Future<void> showCustomerData({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required double grossTotal,
    required double discount,
    required double merchantDiscount,
    required double netTotal,
    required double tax,
    required double netPayable,
<<<<<<< HEAD
=======
    required double cashbackFee,
    double redeemedAmount = 0.0,
    int availablePoints = 0,
    String loyaltyContact = "",
>>>>>>> origin/Grocery_pch_api_integration
    String orderDate = '',
    String orderTime = '',
    String storeId = '',
    String storeName = '',
    String? storeLogoUrl,
<<<<<<< HEAD
  }) async {
    try {
      print("📢 [CustomerDisplayService] showCustomerData() called");
      print("📝 orderId: $orderId, items count: ${items.length}");
      print(
          "📝 grossTotal: $grossTotal, discount: $discount, merchantDiscount: $merchantDiscount, netTotal: $netTotal, tax: $tax, netPayable: $netPayable");
      print("📝 store: $storeName ($storeId), logo: $storeLogoUrl");
      final safeItems = items.map((item) {
=======
    String? storeBaseUrl,
    List<String>? slideshowUrls,
    List<String>? banners,
    bool summaryEnabled = true,
    String discountType = "",
    double discountValue = 0.0,
  }) async {
    try {
      print("📢 showCustomerData() called, availablePoints=$availablePoints");

      final safeItems = items.map((item) {
        final bool ebtFlag = item["is_ebt_eligible"] == true ||
            item["isEbtEligible"] == true ||
            item["ebt_eligible"] == true ||
            item["is_ebt_eligible"] == 1 ||
            item["isEbtEligible"] == 1 ||
            item["ebt_eligible"] == 1 ||
            item["is_ebt_eligible"]?.toString() == "1" ||
            item["isEbtEligible"]?.toString() == "1" ||
            item["ebt_eligible"]?.toString() == "1" ||
            item["is_ebt_eligible"]?.toString() == "true" ||
            item["isEbtEligible"]?.toString() == "true" ||
            item["ebt_eligible"]?.toString() == "true";

>>>>>>> origin/Grocery_pch_api_integration
        return {
          "name": item["name"] ?? "Unknown",
          "qty": item["qty"] ?? 0,
          "price": item["price"] ?? 0.0,
<<<<<<< HEAD
          "image": item["image"] ?? "",
        };
      }).toList();

=======
          "original_price":
          item["original_price"] ?? item["price"] ?? 0.0,
          "auto_discount": item["auto_discount"] ?? 0.0,
          "combo_discount": item["combo_discount"] ?? 0.0,
          "multipack_discount": item["multipack_discount"] ?? 0.0,
          "discount_type": item["discount_type"] ?? "",
          "image": item["image"] ?? "",
          "is_ebt_eligible": ebtFlag,
          "isEbtEligible": ebtFlag,
          "ebt_eligible": ebtFlag,
        };
      }).toList();

      final logoStr = storeLogoUrl ?? "";
      final baseUrlStr = storeBaseUrl ?? "";
      final bannersList = slideshowUrls ?? banners ?? const <String>[];

>>>>>>> origin/Grocery_pch_api_integration
      await _platform.invokeMethod('showCustomerData', {
        "orderId": orderId,
        "items": safeItems,
        "grossTotal": grossTotal,
        "discount": discount,
        "merchantDiscount": merchantDiscount,
        "netTotal": netTotal,
        "tax": tax,
        "netPayable": netPayable,
<<<<<<< HEAD
        "orderDate": orderDate,
        "orderTime": orderTime,
        "storeId": storeId,
        "storeName": storeName,
        "storeLogoUrl": storeLogoUrl ?? "",
      });

      print("✅ [CustomerDisplayService] Customer data sent successfully");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to send data: $e");
    }
  }
}
=======
        "cashbackFee": cashbackFee,
        "redeemedAmount": redeemedAmount,
        "availablePoints": availablePoints,
        "orderDate": orderDate,
        "orderTime": orderTime,
        "storeId": storeId,
        "store_id": storeId,
        "storeName": storeName,
        "store_name": storeName,
        "storeLogoUrl": logoStr,
        "store_logo_url": logoStr,
        "storeLogo": logoStr,
        "store_logo": logoStr,
        "logo": logoStr,
        "logoUrl": logoStr,
        "storeBaseUrl": baseUrlStr,
        "store_base_url": baseUrlStr,
        "slideshowUrls": bannersList,
        "slideshow_urls": bannersList,
        "banners": bannersList,
        "loyaltyContact": loyaltyContact,
        "summaryEnabled": summaryEnabled,
        "discountType": discountType,
        "discountValue": discountValue,
      });
    } catch (e) {
      print("Customer display error: $e");
    }
  }

}
>>>>>>> origin/Grocery_pch_api_integration
