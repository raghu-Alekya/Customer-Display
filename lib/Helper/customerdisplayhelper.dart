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
      print("🟡 [CustomerDisplayHelper] Fetching order items for serverOrderId=$serverOrderId");

      final db = await DBHelper.instance.database;

      // 🧩 Detect if this order exists in offlineOrders Hive
      final offlineBox = Hive.box('offlineOrders');
      final String orderKey = serverOrderId.toString();
      final rawOfflineOrder = offlineBox.get(orderKey);

      List<Map<String, dynamic>> items = [];

      if (rawOfflineOrder != null) {
        print("📦 Detected offline order ($serverOrderId)");
        final offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);

        final List<Map<String, dynamic>> products = (offlineOrder['products'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
            [];

        items = products.map((p) {
          return {
            AppDBConst.itemName: p['name'],
            AppDBConst.itemCount: p['quantity'] ?? 0,
            AppDBConst.itemImage: p['image'] ?? '',
            AppDBConst.itemPrice: p['unit_price'] ?? p['price'] ?? 0.0,
            AppDBConst.itemType: p['type'] ?? 'product',
          };
        }).toList();
      } else {
        // 🧩 Fallback to database if not offline
        items = await OrderHelper().getOrderItems(serverOrderId);
      }

      print("📦 Order Items Fetched → ${items.length} items");

      // 🏪 Fetch store info
      Future<Map<String, dynamic>?> getStoreInfo() async {
        try {
          final result = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='store_table'");
          if (result.isEmpty) return null;

          final storeData = await db.query("store_table", limit: 1);
          return storeData.isNotEmpty ? storeData.first : null;
        } catch (e) {
          print("⚠️ store_table missing or query failed: $e");
          return null;
        }
      }

      final store = await getStoreInfo();

      // 🧾 Parse items and calculate totals
      List<Map<String, dynamic>> parsedItems = [];
      double grossTotal = 0.0;

      for (var item in items) {
        final itemType = item[AppDBConst.itemType] ?? '';
        final name = item[AppDBConst.itemName] ?? 'Unknown';
        final qty = item[AppDBConst.itemCount] as int? ?? 0;
        final image = item[AppDBConst.itemImage] ?? '';

        if (itemType.toLowerCase() == 'coupon') {
          final discountValue = (item["item_discount"] as double?) ??
              (item[AppDBConst.itemPrice] as double? ?? 0.0);

          parsedItems.add({
            "name": "Coupon",
            "qty": 1,
            "price": -discountValue,
            "image": "",
          });

          print("🎟 Coupon Parsed → $name | -$discountValue");
          continue;
        }

        final salesPrice = (item["item_sales_price"] as double?) ?? 0.0;
        final unitPrice = salesPrice > 0
            ? salesPrice
            : item["item_unit_price"] as double? ??
            item[AppDBConst.itemPrice] as double? ??
            0.0;

        final itemTotal = unitPrice * qty;

        parsedItems.add({
          "name": name,
          "qty": qty,
          "price": itemTotal,
          "image": image,
        });

        grossTotal += itemTotal;
        print("🛒 Item Parsed → $name | qty=$qty | unitPrice=$unitPrice | total=$itemTotal");
      }

      print("💰 Gross Total Calculated: $grossTotal");

      // 🧮 Fetch order totals from DB (if exists)
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
      String orderDate = '';
      String orderTime = '';

      if (orderData.isNotEmpty) {
        final row = orderData.first;
        discount = row[AppDBConst.orderDiscount] as double? ?? 0.0;
        merchantDiscount = row["merchant_discount"] as double? ?? 0.0;
        tax = row[AppDBConst.orderTax] as double? ?? 0.0;
        netTotal =
            row["net_total"] as double? ?? (grossTotal - discount - merchantDiscount);
        netPayable = row["net_payable"] as double? ?? (netTotal + tax);

        final dateTimeStr = row[AppDBConst.orderDate]?.toString() ?? '';
        if (dateTimeStr.isNotEmpty) {
          final dateTime = DateTime.tryParse(dateTimeStr);
          if (dateTime != null) {
            orderDate =
            "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
            final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
            final minute = dateTime.minute.toString().padLeft(2, '0');
            final second = dateTime.second.toString().padLeft(2, '0');
            final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
            orderTime = "$hour:$minute:$second $amPm";
          }
        }
      } else {
        // 🕒 Fallback for offline orders (generate time from system)
        final now = DateTime.now();
        orderDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
        final minute = now.minute.toString().padLeft(2, '0');
        final second = now.second.toString().padLeft(2, '0');
        final amPm = now.hour >= 12 ? 'PM' : 'AM';
        orderTime = "$hour:$minute:$second $amPm";
      }

      print(
          "✅ Final Totals → netTotal=$netTotal, netPayable=$netPayable, discount=$discount, merchantDiscount=$merchantDiscount, tax=$tax");

      // 🖥️ Send data to Customer Display
      await CustomerDisplayService.showCustomerData(
        orderId: serverOrderId,
        items: parsedItems,
        grossTotal: grossTotal,
        discount: discount,
        merchantDiscount: merchantDiscount,
        netTotal: netTotal,
        tax: tax,
        netPayable: netPayable,
        orderDate: orderDate,
        orderTime: orderTime,
        storeId: store?["id"]?.toString() ?? "",
        storeName: store?["name"]?.toString() ?? "",
        storeLogoUrl: store?["logoUrl"]?.toString(),
      );

    } catch (e, s) {
      print("❌ [CustomerDisplayHelper] Error in updateCustomerDisplay: $e");
      print("📌 StackTrace: $s");
    }
  }
}