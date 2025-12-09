import 'package:hive/hive.dart';
import '../services/CustomerDisplayService.dart';

class CustomerDisplayHelper {
  /// 🔹 Show welcome after login success, including optional logo
  static Future<void> updateWelcomeWithStore(
    String storeId,
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

      // 🔥 Fetch WooCommerce Order ID stored earlier after sync
      final wooOrderId = data["wooOrderId"];

      print("🟣 [CD] Woo Order ID fetched from Hive → $wooOrderId");


      print("🔶🔶🔶 RAW HIVE ORDER DATA (FULL DUMP) 🔶🔶🔶");
      data.forEach((key, value) {
        print(" ▶ $key : $value");
      });
      print("🔶🔶🔶 END RAW HIVE ORDER DATA 🔶🔶🔶");

      // ------------------ DATE & TIME ------------------
      String orderDate = "";
      String orderTime = "";

      final createdAt = data["created_at"]?.toString() ?? "";

      if (createdAt.isNotEmpty) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {

          // 👉 Format: MM-DD-YYYY
          orderDate =
          "${dt.month.toString().padLeft(2, '0')}-"
              "${dt.day.toString().padLeft(2, '0')}-"
              "${dt.year}";

          // 👉 12-hour time with AM/PM
          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final minute = dt.minute.toString().padLeft(2, '0');
          final second = dt.second.toString().padLeft(2, '0');
          final amPm = dt.hour >= 12 ? "PM" : "AM";

          orderTime = "$hour:$minute:$second $amPm";
        }
      }

      // ------------------ FILTER PRODUCT LIST ------------------
      final productsRaw = (data["products"] ?? []) as List;


      print("🔵 [CD] RAW PRODUCTS FROM HIVE (BEFORE FILTER):");
      for (var p in productsRaw) {
        print(" → RAW ITEM: $p");
      }

      final products = productsRaw
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) {
        final type = (p["type"] ?? "").toString().toLowerCase();
        final productId = (p["product_id"] ?? 0);
        final price = (p["price"] ?? 0).toDouble();
        final name = (p["name"] ?? "").toString().toLowerCase();

        // 🚫 This is a coupon / non-real product line
        final isCouponLine =
            type == "coupon" ||
                productId == -1 ||
                name.contains("discount") ||
                name.contains("coupon") ||
                price < 0;

        return !isCouponLine;
      })
          .toList();

      // Helper to get correct unit price
      double _getUnitPrice(Map<String, dynamic> p) {
        final unit = p["unit_price"];
        if (unit is num) return unit.toDouble();

        final regular = p["regular_price"];
        if (regular is num) return regular.toDouble();

        final price = p["price"];
        if (price is num) return price.toDouble();

        return 0.0;
      }

      print("🟢 [CD] PRODUCTS AFTER FILTER:");
      for (var p in products) {
        print(
            " → ${p['name']} | qty=${p['quantity']} | unit_price=${_getUnitPrice(p)} | price=${p['price']}"
        );
      }

      // ------------------ PAYOUTS ------------------
      final payouts = ((data["payouts"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ------------------ CASHBACKS ------------------
      final cashbacks = ((data["cashbacks"] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ------------------ CASHBACK FEE ------------------
      double cashbackFee =
      (data["cashbackFee"] is num) ? (data["cashbackFee"] as num).toDouble() : 0.0;

      print("💰 cashbackFee = $cashbackFee");

      // ------------------ BUILD PARSED ITEMS LIST ------------------
      final parsedItems = [
        ...products.map((item) {
          final qty = (item["quantity"] ?? 1);
          final unitPrice = _getUnitPrice(item);

          return {
            "name": item["name"] ?? "",
            "qty": (qty is num ? qty.toDouble() : 1.0),
            // 👇 send per-unit price OR total? depends on display logic
            // If your display multiplies price * qty, this MUST be unit price
            "price": unitPrice,
            "image": item["image"] ?? "",
          };
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

      // ------------------ TOTALS ------------------
      double productTotal = products.fold(0, (sum, p) {
        final qty = (p["quantity"] ?? 1);
        final unitPrice = _getUnitPrice(p);
        final q = qty is num ? qty.toDouble() : 1.0;
        return sum + unitPrice * q;
      });

      double payoutTotal =
      payouts.fold(0, (sum, p) => sum + (p["amount"] ?? 0).toDouble());

      double cashbackTotal =
      cashbacks.fold(0, (sum, c) => sum + (c["amount"] ?? 0).toDouble());

      double grossTotal = productTotal + payoutTotal + cashbackTotal;

      // Discounts 🟡
      double orderDiscount =
      (data["orderDiscount"] is num) ? (data["orderDiscount"] as num).toDouble() : 0.0;

      double merchantDiscountStored =
      (data["merchantDiscount"] is num) ? (data["merchantDiscount"] as num).toDouble() : 0.0;

      bool merchantIsPercentage =
          (data["merchantDiscountIsPercentage"] as bool?) ?? false;

      double merchantDiscount = merchantDiscountStored;

      // Tax 🟡
      double orderTax =
      (data["wooTax"] is num) ? (data["wooTax"] as num).toDouble() : 0.0;

      // Final calculations
      double netTotal = grossTotal - orderDiscount;
      double netPayable = netTotal + cashbackFee + orderTax - merchantDiscount;

      // ------------------ LOGS ------------------
      print("✅ [CD] CALCULATION RESULTS");
      print(" productTotal = $productTotal");
      print(" payoutTotal = $payoutTotal");
      print(" cashbackTotal = $cashbackTotal");
      print(" grossTotal = $grossTotal");
      print(" orderDiscount = $orderDiscount");
      print(
          " merchantDiscount = $merchantDiscount (${merchantIsPercentage ? "Percentage" : "Fixed"})");
      print(" orderTax = $orderTax");
      print(" netTotal = $netTotal");
      print(" netPayable = $netPayable");
      print(" orderDate = $orderDate");
      print(" orderTime = $orderTime");
      // ------------------ LOYALTY CONTACT ------------------
      final loyaltyContact = data["loyaltyContact"]?.toString() ?? "";
      print("☎ Loyalty Contact = $loyaltyContact");


      // ------------------ PUSH TO CUSTOMER DISPLAY ------------------
      await CustomerDisplayService.showCustomerData(
        orderId: wooOrderId ?? serverOrderId,
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
        loyaltyContact: loyaltyContact,
      );

      print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }
}
