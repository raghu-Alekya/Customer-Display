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
// ------------------ REMOVE DISCOUNT ITEMS ------------------
      final productsRaw = (data["products"] ?? []) as List;

      final products = productsRaw
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) {
        final name = (p["name"] ?? "").toString().toLowerCase();
        // Remove discount/coupon items
        return !(name.contains("discount") || name.contains("coupon"));
      })
          .toList();


// Extract payouts
      final payouts = ((data["payouts"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

// Extract cashbacks
      final cashbacks = ((data["cashbacks"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

// Cashback fee
      double cashbackFee =
      (data["cashbackFee"] is num) ? (data["cashbackFee"] as num).toDouble() : 0.0;


// Build items list
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

        ...cashbacks.map((c) => {
          "name": "Cashback",
          "qty": 1.0,
          "price": (c["amount"] ?? 0).toDouble(),
          "image": c["product_image"] ?? "",
        }),
      ];


      double productTotal = products.fold(0, (sum, p) =>
      sum + (p["price"] ?? 0).toDouble() * (p["quantity"] ?? 1).toDouble());

      double payoutTotal = payouts.fold(0, (sum, p) =>
      sum + (p["amount"] ?? 0).toDouble());

      double cashbackTotal = cashbacks.fold(0, (sum, c) =>
      sum - (c["amount"] ?? 0).toDouble()); // cashback is negative

      double grossTotal = productTotal - payoutTotal + cashbackTotal;

      double orderDiscount =
      (data["orderDiscount"] is num) ? (data["orderDiscount"] as num).toDouble() : 0.0;

      double merchantDiscountStored =
      (data["merchantDiscount"] is num) ? (data["merchantDiscount"] as num).toDouble() : 0.0;

      bool merchantIsPercentage = (data["merchantDiscountIsPercentage"] as bool?) ?? false;
      double merchantDiscount = merchantDiscountStored;

      double orderTax = (data["wooTax"] is num) ? (data["wooTax"] as num).toDouble() : 0.0;

      double netTotal = grossTotal - orderDiscount;
      double netPayable = netTotal + cashbackFee + orderTax - merchantDiscount;

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
        cashbackFee: cashbackFee,
      );

      print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }
}
