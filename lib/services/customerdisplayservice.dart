import 'package:flutter/services.dart';

class CustomerDisplayService {
  static const MethodChannel _platform =
  MethodChannel('com.alekta.pinakapos/sunmi_display');

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
      // Future.delayed(Duration(seconds: delaySeconds), () async {
      //   print("🔄 [CustomerDisplayService] Reverting to welcome screen");
      //   await showWelcome();
      // });
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to show Thank You: $e");
    }
  }
  static Future<void> resetDisplay() async {
    try {
      print("📢 [CustomerDisplayService] resetDisplay() called");
      await _platform.invokeMethod('resetDisplay');
      print("✅ [CustomerDisplayService] Display reset");
    } catch (e) {
      print("⚠️ [CustomerDisplayService] Failed to reset display: $e");
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
    // required double redeemedAmount,

    double redeemedAmount = 0.0,
    String loyaltyContact = "",
    String orderDate = '',
    String orderTime = '',
    String storeId = '',
    String storeName = '',
    String? storeLogoUrl,
    bool summaryEnabled = true,
    String discountType = "",
    double discountValue = 0.0,
  }) async {
    try {
      print("📢 showCustomerData called");

      final safeItems = items.map((item) {
        return {
          "name": item["name"] ?? "Unknown",
          "qty": item["qty"] ?? 0,
          "price": item["price"] ?? 0.0,
          "original_price": item["original_price"] ?? item["price"] ?? 0.0,
          "auto_discount": item["auto_discount"] ?? 0.0,
          "combo_discount": item["combo_discount"] ?? 0.0,
          "multipack_discount": item["multipack_discount"] ?? 0.0,
          "discount_type": item["discount_type"] ?? "",
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
        "redeemedAmount": redeemedAmount,
        "orderDate": orderDate,
        "orderTime": orderTime,
        "storeId": storeId,
        "storeName": storeName,
        "storeLogoUrl": storeLogoUrl ?? "",
        "loyaltyContact": loyaltyContact,
        "summaryEnabled": summaryEnabled,
        "discountType": discountType,
        "discountValue": discountValue,
      });
    } catch (e) {
      print("Customer display error: $e");
    }
  }
/// 🔹 Update redeem / summary state on customer display
// static Future<void> customerDisplayResult({
//   required bool success,
//   required double redeemedAmount,
//   required int points,
//   String message = "",
// }) async {
//   try {
//     print(
//       "📢 customerDisplayResult → "
//           "success=$success, redeemedAmount=$redeemedAmount, points=$points",
//     );
//
//     await _platform.invokeMethod(
//       'customerDisplayResult',
//       {
//         "success": success,
//         "redeemedAmount": redeemedAmount,
//         "points": points,
//         "message": message,
//       },
//     );
//
//     print("✅ customerDisplayResult sent");
//   } catch (e) {
//     print("⚠️ customerDisplayResult error: $e");
//   }
// }
}