import 'dart:convert';

import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import '../Database/order_panel_db_helper.dart';
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
    final activeId = OrderHelper().activeOrderId;

    // ✅ ONLY show welcome if no active order
    if (activeId != null) {
      print("⛔ Skipping welcome — active order exists");
      return;
    }

    await CustomerDisplayService.showWelcomeWithStore(
      storeId: storeId,
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      storeBaseUrl: storeBaseUrl,
    );
  }

  static Future<void> clearOrder() async {
    try {
      await CustomerDisplayService.showWelcome();
      print("🧹 Customer display cleared (order reset)");
    } catch (e) {
      print("❌ Failed to clear customer display: $e");
    }
  }


  static Future<void> updateCustomerDisplay(
      int serverOrderId, {
        bool summaryEnabled = false,
        double redeemedValue = 0.0,
      }) async {
    try {

      final int? activeId = OrderHelper().activeOrderId;

// ❌ BLOCK if no active order
      if (activeId == null) {
        print("⛔ [CD] No active order → skipping display update");
        return;
      }

// ❌ BLOCK stale updates
      if (activeId != serverOrderId) {
        print("🟥 [CD] Ignoring stale display update");
        return;
      }

      print("🟡 [CD] START updateCustomerDisplay → serverOrderId=$serverOrderId");

      final offlineBox = StorageProvider.offlineOrders;
      final raw = await offlineBox.get(serverOrderId.toString());

      print("🗃 [CD] Checking Hive for key=$serverOrderId → found=${raw != null}");

      if (raw == null) {
        print("🟡 [CD] No Hive data yet → showing empty order");

        await CustomerDisplayService.showCustomerData(
          orderId: serverOrderId,
          items: [],
          grossTotal: 0.0,
          discount: 0.0,
          merchantDiscount: 0.0,
          netTotal: 0.0,
          tax: 0.0,
          netPayable: 0.0,
          orderDate: "",
          orderTime: "",
          cashbackFee: 0.0,
          loyaltyContact: "",
          summaryEnabled: summaryEnabled,
          discountType: "NONE",
          discountValue: 0.0,
        );

        return;
      }

      final data = Map<String, dynamic>.from(raw);

      // 🔥 SOURCE OF TRUTH — DISCOUNT LINES
      final Map<String, dynamic> discountLines =
      (data["discount_lines"] is Map)
          ? Map<String, dynamic>.from(data["discount_lines"])
          : {};

      print("🧠 DISCOUNT LINES FROM HIVE → $discountLines");


      // 🔥 Fetch WooCommerce Order ID stored earlier after sync
      final wooOrderId = data["wooOrderId"];

      print("🟣 [CD] Woo Order ID fetched from Hive → $wooOrderId");


      Future<double> _getAutoDiscountPerUnit(int productId, int qty) async {
        try {
          final box = StorageProvider.productCache;
          final allEntries = await box.toMap();

          for (var key in allEntries.keys) {
            if (!key.toString().startsWith("products_")) continue;

            final cached = allEntries[key];
            if (cached == null) continue;

            List products;
            if (cached is List) {
              products = cached;
            } else if (cached is Map && cached['data'] != null) {
              products = json.decode(cached['data'].toString());
            } else {
              continue;
            }

            final product = products.cast<Map>().firstWhere(
                  (p) =>
              p['fast_key_product_id'] == productId ||
                  p['id'] == productId,
              orElse: () => <String, dynamic>{},
            );

            if (product.isEmpty) continue;

            final bool enabled = product['auto_discount_enabled'] == true;
            final double discount =
                double.tryParse(product['discount_amount']?.toString() ?? '0') ?? 0.0;

            if (!enabled || discount <= 0 || qty <= 0) return 0.0;

            return discount; // 👈 per-unit discount
          }
        } catch (e) {
          print("❌ [CD] Auto discount error → $e");
        }
        return 0.0;
      }


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

      if (productsRaw.isEmpty) {
        print("🟡 [CD] Empty order → showing order with no items");

        await CustomerDisplayService.showCustomerData(
          orderId: serverOrderId,
          items: [],
          grossTotal: 0.0,
          discount: 0.0,
          merchantDiscount: 0.0,
          netTotal: 0.0,
          tax: 0.0,
          netPayable: 0.0,
          orderDate: "",
          orderTime: "",
          cashbackFee: 0.0,
          loyaltyContact: "",
          summaryEnabled: summaryEnabled,
          discountType: "NONE",
          discountValue: 0.0,
        );

        return;
      }

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

      double _getUnitPrice(Map<String, dynamic> p) {

        final type = (p["type"] ?? "").toString().toLowerCase();
        if (type == "weighted") {
          final selling = p["price"];
          if (selling is num && selling > 0) {
            return selling.toDouble();
          }
        }
        final unit = p["unit_price"];
        if (unit is num && unit > 0) {
          return unit.toDouble();
        }

        final sales = p["sales_price"];
        if (sales is num && sales > 0) {
          return sales.toDouble();
        }
        final price = p["price"];
        if (price is num) {
          return price.toDouble();
        }

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
          final qty =
              int.tryParse(item["quantity"]?.toString() ?? "1") ?? 1;

          final unitPrice = _getUnitPrice(item);

          final pid = item["product_id"]?.toString() ?? "";

// read from discount_lines instead of item
          final discountMeta =
          discountLines.containsKey(pid)
              ? Map<String, dynamic>.from(discountLines[pid])
              : {};

          final double totalDiscount =
              (discountMeta["amount"] as num?)?.toDouble() ?? 0.0;

          final double perUnitDiscount =
          qty > 0 ? totalDiscount / qty : 0.0;

          print("""
🟠 [CD] RESOLVED DISCOUNT
 product : ${item["name"]}
 productId : $pid
 meta : $discountMeta
 perUnit : $perUnitDiscount
""");

          print("""
🔴 [CD] RAW PRODUCT ITEM FROM HIVE
  name        : ${item["name"]}
  quantity    : ${item["quantity"]}
  price(raw)  : ${item["price"]}
  unit_price  : ${item["unit_price"]}
  discount_meta : ${item["discount_meta"]}
""");

          return {
            "name": item["name"] ?? "",
            "qty": qty.toDouble(),
            "price": unitPrice,
            "original_price": unitPrice,
            "auto_discount": totalDiscount,
            "discount_type": discountMeta["type"] ?? "",
            "unit_discount": perUnitDiscount,
            "discount_source": discountMeta["source"] ?? "",
            "rule_id": discountMeta["rule_id"] ?? "",
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
      double productTotal = parsedItems
          .where((i) => i["name"] != "Payout" && i["name"] != "Cashback")
          .fold(0.0, (sum, i) {
        final qty = (i["qty"] as num?)?.toDouble() ?? 1.0;
        final price = (i["price"] as num?)?.toDouble() ?? 0.0;
        final totalDiscount = (i["auto_discount"] as num?)?.toDouble() ?? 0.0;
        return sum + ((price * qty) - totalDiscount);

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
      (data["tax_discount"] is num)
          ? (data["tax_discount"] as num).toDouble()
          : 0.0;


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
      // final int safeOrderId =
      //     int.tryParse(wooOrderId?.toString() ?? "") ?? serverOrderId;
      final int safeOrderId = serverOrderId;

      final double totalItemDiscount = parsedItems.fold(
        0.0,
            (sum, i) => sum + ((i["auto_discount"] ?? 0.0) as num),
      );


      final String appliedDiscountType = parsedItems
          .map((i) => i["discount_type"])
          .firstWhere(
            (t) => t != null && t.toString().isNotEmpty,
        orElse: () => "NONE",
      );
      await CustomerDisplayService.showCustomerData(
        orderId: safeOrderId,
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
        summaryEnabled: summaryEnabled,
        discountType: appliedDiscountType,
        discountValue: totalItemDiscount,

      );


      print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }
}
