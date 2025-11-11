import 'package:hive/hive.dart';
import '../services/CustomerDisplayService.dart';

class CustomerDisplayHelper {
  /// 🔹 Show welcome after login success, including optional logo
  static Future<void> updateWelcomeWithStore(String storeId,
      String storeName, {
        String? storeLogoUrl,
        String? storeBaseUrl,
      }) async {
    print(
        "🟢 [CustomerDisplayHelper] Updating welcome → storeId: $storeId, storeName: $storeName, logo: $storeLogoUrl, baseUrl: $storeBaseUrl");

    await CustomerDisplayService.showWelcomeWithStore(
      storeId: storeId,
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      storeBaseUrl: storeBaseUrl,
    );
  }

  static Future<void> showEmptyOrder() async {
    print("🟡 [CD] showEmptyOrder → sending empty order state");

    await CustomerDisplayService.showCustomerData(
      orderId: 0,
      items: [],
      grossTotal: 0.0,
      discount: 0.0,
      merchantDiscount: 0.0,
      netTotal: 0.0,
      tax: 0.0,
      netPayable: 0.0,
      orderDate: "",
      orderTime: "",
    );
  }

  static Future<void> updateCustomerDisplay(int serverOrderId) async {
    try {
      print("🟡 [CD] START updateCustomerDisplay → serverOrderId=$serverOrderId");

      final offlineBox = Hive.box('offlineOrders');
      final raw = offlineBox.get(serverOrderId.toString());

      print("🗃 [CD] Checking Hive for key=$serverOrderId → found=${raw != null}");

      if (raw == null) {
        print("❌ [CD] No offline order found in Hive.");
        return;
      }

      final data = Map<String, dynamic>.from(raw);

      // ✅ Extract offline created_at timestamp
      String orderDate = "";
      String orderTime = "";

      final createdAt = data["created_at"]?.toString() ?? "";
      if (createdAt.isNotEmpty) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {
          orderDate =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final minute = dt.minute.toString().padLeft(2, '0');
          final second = dt.second.toString().padLeft(2, '0');
          final amPm = dt.hour >= 12 ? "PM" : "AM";

          orderTime = "$hour:$minute:$second $amPm";
        }
      }

      // ✅ Extract product and payout lists
      final products = ((data["products"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final payouts = ((data["payouts"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final parsedItems = [
        ...products.map((item) => {
          "name": item["name"] ?? "",
          "qty": (item["quantity"] ?? 1).toDouble(),
          "price": (item["price"] ?? 0).toDouble(),
          "image": item['image'] ?? "",
        }),
        ...payouts.map((p) => {
          "name": "Payout",
          "qty": 1.0,
          "price": (p["amount"] ?? 0).toDouble(),
          "image": "assets/svg/payout.svg",
        }),
      ];

      print("✅ [CD] Items parsed = ${parsedItems.length}");

      // ✅ Totals
      double productTotal = 0;
      for (var item in products) {
        final price = (item["price"] ?? 0).toDouble();
        final qty = (item["quantity"] ?? 1).toDouble();
        productTotal += price * qty;
      }

      double payoutTotal = 0;
      for (var p in payouts) {
        payoutTotal += (p["amount"] ?? 0).toDouble();
      }

      double grossTotal = productTotal + payoutTotal;

      double orderDiscount =
      (data["orderDiscount"] is num) ? (data["orderDiscount"] as num).toDouble() : 0.0;

      double merchantDiscountStored =
      (data["merchantDiscount"] is num) ? (data["merchantDiscount"] as num).toDouble() : 0.0;

      bool merchantIsPercentage = (data["merchantDiscountIsPercentage"] as bool?) ?? false;
      double merchantDiscount = merchantDiscountStored;

      double orderTax = (data["wooTax"] is num) ? (data["wooTax"] as num).toDouble() : 0.0;

      double netTotal = grossTotal - orderDiscount - merchantDiscount;
      double netPayable = netTotal + orderTax;

      print("✅ [CD] UI Calculation:");
      print(" productTotal = $productTotal");
      print(" payoutTotal = $payoutTotal");
      print(" grossTotal = $grossTotal");
      print(" orderDiscount = $orderDiscount");
      print(
          " merchantDiscount = $merchantDiscount (${merchantIsPercentage ? "Percentage" : "Fixed"})");
      print(" orderTax = $orderTax");
      print(" netTotal = $netTotal");
      print(" netPayable = $netPayable");
      print(" orderDate = $orderDate");
      print(" orderTime = $orderTime");
      await CustomerDisplayService.showCustomerData(
        orderId: serverOrderId,
        items: parsedItems,
        grossTotal: grossTotal,
        discount: orderDiscount,
        merchantDiscount: merchantDiscount,
        netTotal: netTotal,
        tax: orderTax,
        netPayable: netPayable,
        orderDate: orderDate,
        orderTime: orderTime,
      );

      print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }
}
