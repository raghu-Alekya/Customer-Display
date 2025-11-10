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

  /// 🔹 Update customer display for a given order (offline + online supported)
  static Future<void> updateCustomerDisplay(int serverOrderId) async {
    try {
      print("🟡 [CD] START updateCustomerDisplay → serverOrderId=$serverOrderId");

      final db = await DBHelper.instance.database;
      final offlineBox = Hive.box('offlineOrders');

      // ---------------------------------------------
      // ✅ 1. Resolve offline/local order mapping
      // ---------------------------------------------
      String orderKey = serverOrderId.toString();
      dynamic rawOfflineOrder = offlineBox.get(orderKey);

      print("🗃 [CD] Checking Hive for key=$orderKey → found=${rawOfflineOrder != null}");

      // ✅ Resolve Woo → Local mapping
      if (rawOfflineOrder is Map && rawOfflineOrder["__map_to_local__"] != null) {
        final String mappedKey = rawOfflineOrder["__map_to_local__"].toString();
        print("🔄 [CD] Woo → Local mapping detected → Woo=$orderKey → Local=$mappedKey");

        rawOfflineOrder = offlineBox.get(mappedKey);
        orderKey = mappedKey;

        print("🗃 [CD] Loaded local order from Hive key=$orderKey");
      }

      // ---------------------------------------------
      // ✅ 2. Load items
      // ---------------------------------------------
      List<Map<String, dynamic>> items = [];

      if (rawOfflineOrder != null) {
        print("📦 [CD] Offline order found. Parsing products...");

        final offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);
        final List products = (offlineOrder['products'] as List?)?.toList() ?? [];

        items = products.map((p) {
          return {
            AppDBConst.itemName: p['name'],
            AppDBConst.itemCount: p['quantity'] ?? 0,
            AppDBConst.itemImage: p['image'] ?? '',
            AppDBConst.itemPrice: p['unit_price'] ?? p['price'] ?? 0.0,
            AppDBConst.itemType: p['type'] ?? 'product',
          };
        }).toList();

        print("✅ [CD] Offline items parsed: count=${items.length}");
      } else {
        print("🔍 [CD] No offline data. Fetching items from SQLite...");
        items = await OrderHelper().getOrderItems(serverOrderId);
        print("✅ [CD] SQLite items fetched: count=${items.length}");
      }

      // ---------------------------------------------
      // ✅ 3. Calculate item totals
      // ---------------------------------------------
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
        });

        print("🛒 [CD] Item → ${item[AppDBConst.itemName]} | qty=$qty | price=$price | total=$total");
        grossTotal += total;
      }

      print("💰 [CD] Gross total → $grossTotal");

      // ---------------------------------------------
      // ✅ 4. Load order totals (Woo-tax override logic)
      // ---------------------------------------------
      final orderData = await db.query(
        AppDBConst.orderTable,
        where: '${AppDBConst.orderServerId} = ?',
        whereArgs: [serverOrderId],
      );

      double discount = 0.0;
      double merchantDiscount = 0.0;
      double tax = 0.0;
      double netTotal = grossTotal;
      double netPayable = grossTotal;

      // ✅ First priority: Woo offline tax
      double? wooTax;
      double? wooTotal;

      final offlineData = offlineBox.get(orderKey);
      if (offlineData != null) {
        wooTax = offlineData["wooTax"] as double?;
        wooTotal = offlineData["wooTotal"] as double?;
      }

      if (wooTax != null) {
        // ✅ Woo tax override ALWAYS WINS
        tax = wooTax;
        netTotal = (wooTotal ?? grossTotal) - tax;
        netPayable = wooTotal ?? grossTotal;

        print("✅ [CD] Using Woo tax override → tax=$tax | netTotal=$netTotal | netPayable=$netPayable");
      }
      else if (orderData.isNotEmpty) {
        // ✅ Fall back to DB only if Woo tax is missing
        print("🗄️ [CD] No Woo tax found. Loading DB totals...");

        final row = orderData.first;
        discount = row[AppDBConst.orderDiscount] as double? ?? 0.0;
        merchantDiscount = row["merchant_discount"] as double? ?? 0.0;
        tax = row[AppDBConst.orderTax] as double? ?? 0.0;

        netTotal = row["net_total"] as double? ?? grossTotal;
        netPayable = row["net_payable"] as double? ?? (netTotal + tax);

        print("✅ [CD] DB totals → tax=$tax | net=$netTotal | payable=$netPayable");
      }
      else {
        print("⚠️ [CD] No DB + No Woo tax. Using gross only.");
      }

      // ---------------------------------------------
      // ✅ 5. Send data to customer display
      // ---------------------------------------------
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
