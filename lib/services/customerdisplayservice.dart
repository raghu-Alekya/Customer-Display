import 'package:flutter/services.dart';

class CustomerDisplayService {
  static const MethodChannel _platform =
  MethodChannel('com.example.flutter_customer_display/sunmi_display');

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

      // Revert to welcome automatically
      Future.delayed(Duration(seconds: delaySeconds), () async {
        print("🔄 [CustomerDisplayService] Reverting to welcome screen");
        await showWelcome();
      });
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show Thank You: $e");
    }
  }

  /// 🔹 Show welcome screen with store info and optional logo
  static Future<void> showWelcomeWithStore({
    required String storeId,
    required String storeName,
    String? storeLogoUrl,
    String? storeBaseUrl, // new optional param
  }) async {
    try {
      print(
          "📢 [CustomerDisplayService] showWelcomeWithStore → storeId=$storeId, storeName=$storeName, logo=$storeLogoUrl, baseUrl=$storeBaseUrl");

      await _platform.invokeMethod('showWelcomeWithStore', {
        "storeId": storeId,
        "storeName": storeName,
        "storeLogoUrl": storeLogoUrl ?? "",
        "storeBaseUrl": storeBaseUrl ?? "",
      });

      print("✅ [CustomerDisplayService] Store welcome displayed");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show store welcome: $e");
    }
  }

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
    required double cashbackFee,
    String loyaltyContact = "", // ✅ NEW
    String orderDate = '',
    String orderTime = '',
    String storeId = '',
    String storeName = '',
    String? storeLogoUrl,
  }) async {
    try {
      print("📢 [CustomerDisplayService] showCustomerData() called");
      print("📝 orderId: $orderId, items count: ${items.length}");
      print(
          "📝 grossTotal: $grossTotal, discount: $discount, merchantDiscount: $merchantDiscount, netTotal: $netTotal, tax: $tax, netPayable: $netPayable, cashbackFee: $cashbackFee");
      print("📝 store: $storeName ($storeId), logo: $storeLogoUrl");

      final safeItems = items.map((item) {
        return {
          "name": item["name"] ?? "Unknown",
          "qty": item["qty"] ?? 0,
          "price": item["price"] ?? 0.0,
          "image": item["image"] ?? "",
        };
      }).toList();

      await _platform.invokeMethod('showCustomerData', {
        "orderId": orderId,
        "items": safeItems,
        "grossTotal": grossTotal,
        "discount": discount,
        "merchantDiscount": merchantDiscount,
        "netTotal": netTotal,
        "tax": tax,
        "netPayable": netPayable,
        "cashbackFee": cashbackFee,
        "orderDate": orderDate,
        "orderTime": orderTime,
        "storeId": storeId,
        "storeName": storeName,
        "storeLogoUrl": storeLogoUrl ?? "",
        "loyaltyContact": loyaltyContact,

      });

      print("✅ [CustomerDisplayService] Customer data sent successfully");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to send data: $e");
    }
  }
}
