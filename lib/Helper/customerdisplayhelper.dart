import 'package:hive/hive.dart';

import '../Database/db_helper.dart';
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

      final db = await DBHelper.instance.database;
      final offlineBox = Hive.box('offlineOrders');

      String orderKey = serverOrderId.toString();
      dynamic rawOfflineOrder = offlineBox.get(orderKey);

      print("🗃 [CD] Checking Hive for key=$orderKey → found=${rawOfflineOrder != null}");

      // ✅ Woo → Local mapping
      if (rawOfflineOrder is Map && rawOfflineOrder["__map_to_local__"] != null) {
        final String mappedKey = rawOfflineOrder["__map_to_local__"].toString();
        print("🔄 [CD] Woo → Local mapping detected → Woo=$orderKey → Local=$mappedKey");

        rawOfflineOrder = offlineBox.get(mappedKey);
        orderKey = mappedKey;

        print("🗃 [CD] Loaded local order from Hive key=$orderKey");
      }

      List<Map<String, dynamic>> items = [];

      // ✅ Parse offline items + payout lines
      if (rawOfflineOrder != null) {
        print("📦 [CD] Offline order found. Parsing products...");

        final offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);

        final List products = (offlineOrder['products'] as List?)?.toList() ?? [];
        final List payouts = (offlineOrder['payouts'] as List?)?.toList() ?? [];

        items = products.map((p) {
          return {
            AppDBConst.itemName: p['name'],
            AppDBConst.itemCount: p['quantity'] ?? 0,
            AppDBConst.itemImage: p['image'] ?? '',
            AppDBConst.itemPrice: p['unit_price'] ?? p['price'] ?? 0.0,
            AppDBConst.itemType: "product",
          };
        }).toList();

        for (var p in payouts) {
          final amt = (p["amount"] ?? 0.0).toDouble();

          items.add({
            AppDBConst.itemName: "Payout",
            AppDBConst.itemCount: 1,
            AppDBConst.itemImage: "",
            AppDBConst.itemPrice: amt,     // usually negative
            AppDBConst.itemType: "payout",
          });

          print("🟣 [CD] Payout → amount=$amt added as line item");
        }

        print("✅ [CD] Offline items parsed: count=${items.length}");
      }

      // -------------------------
      // ✅ Build parsedItems (INCLUDING PAYOUTS)
      // -------------------------
      double grossTotal = 0.0;
      List<Map<String, dynamic>> parsedItems = [];

      for (var item in items) {
        final qty = item[AppDBConst.itemCount] ?? 0;
        final price = item[AppDBConst.itemPrice] ?? 0.0;
        final total = qty * price;

        parsedItems.add({
          "name": item[AppDBConst.itemName],
          "qty": qty,
          "price": total,
          "image": item[AppDBConst.itemImage],
          "type": item[AppDBConst.itemType],   // ✅ keep type (payout/product)
        });

        print("🛒 [CD] Item → ${item[AppDBConst.itemName]} | qty=$qty | price=$price | total=$total");
        grossTotal += total;
      }

      print("💰 [CD] Gross total → $grossTotal");

      // -------------------------
      // ✅ Load offline totals (discount, merchantDiscount, payouts)
      // -------------------------
      final offlineData = offlineBox.get(orderKey);

      double discount = 0.0;
      double merchantDiscount = 0.0;
      double tax = 0.0;
      double netTotal = grossTotal;
      double netPayable = grossTotal;

      double? wooTax = offlineData?["wooTax"] as double?;
      double? wooTotal = offlineData?["wooTotal"] as double?;

      double payoutTotal = 0.0;

      if (offlineData != null) {
        merchantDiscount = (offlineData["merchantDiscount"] as num?)?.toDouble() ?? 0.0;
        discount = (offlineData["orderDiscount"] as num?)?.toDouble() ?? 0.0;

        payoutTotal = (offlineData["payoutTotal"] as num?)?.toDouble() ?? 0.0;

        if (payoutTotal != 0.0) {
          grossTotal += payoutTotal;
          print("✅ [CD] Offline payout applied → payout=$payoutTotal → newGross=$grossTotal");
        }

        print("✅ [CD] Offline discounts → merchant=$merchantDiscount | discount=$discount");
      }

      // -------------------------
      // ✅ OFFLINE OVERRIDE → If offlineData exists, DO NOT use DB totals
      // -------------------------
      if (offlineData != null) {
        print("✅ [CD] Using OFFLINE totals only");

        netTotal = grossTotal - discount - merchantDiscount;
        netPayable = netTotal + (wooTax ?? 0.0);

        print("✅ [CD] Final offline totals → net=$netTotal | payable=$netPayable");
      }

      // -------------------------
      // ✅ Woo tax override (optional)
      // -------------------------
      else if (wooTax != null) {
        tax = wooTax;

        netTotal = (wooTotal ?? grossTotal) - tax - discount - merchantDiscount;
        netPayable = (wooTotal ?? grossTotal);

        print("✅ [CD] Woo tax override → net=$netTotal | payable=$netPayable");
      }

      // -------------------------
      // ✅ Only fallback to DB totals when NO offline order exists
      // -------------------------
      else {
        final orderData = await db.query(
          AppDBConst.orderTable,
          where: '${AppDBConst.orderServerId} = ?',
          whereArgs: [serverOrderId],
        );

        if (orderData.isNotEmpty) {
          print("🗄️ [CD] Using DB totals...");

          final row = orderData.first;

          discount = row[AppDBConst.orderDiscount] as double? ?? 0.0;
          merchantDiscount = row["merchant_discount"] as double? ?? 0.0;
          tax = row[AppDBConst.orderTax] as double? ?? 0.0;

          netTotal = grossTotal - discount - merchantDiscount;
          netPayable = netTotal + tax;

          print("✅ [CD] DB totals → tax=$tax | net=$netTotal | payable=$netPayable");
        }
      }

      // -------------------------
      // ✅ Send to Customer Display
      // -------------------------
      print("📤 [CD] Sending data to Customer Display...");
      print("👉 orderId=$serverOrderId");
      print("👉 grossTotal=$grossTotal");
      print("👉 discount=$discount");
      print("👉 merchantDiscount=$merchantDiscount");
      print("👉 netTotal=$netTotal");
      print("👉 tax=$tax");
      print("👉 netPayable=$netPayable");

      await CustomerDisplayService.showCustomerData(
        orderId: serverOrderId,
        items: parsedItems,
        grossTotal: grossTotal,
        discount: discount,
        merchantDiscount: merchantDiscount,
        netTotal: netTotal,
        tax: tax,
        netPayable: netPayable,
        orderDate: "",
        orderTime: "",
        storeId: "",
        storeName: "",
        storeLogoUrl: "",
      );

      print("✅ [CD] Completed updateCustomerDisplay → orderId=$serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }
}
