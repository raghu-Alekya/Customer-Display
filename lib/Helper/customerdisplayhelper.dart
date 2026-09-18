// import 'dart:convert';
//
// import 'package:pinaka_pos/Database/storage/storage_provider.dart';
// import '../Database/order_panel_db_helper.dart';
// import '../Preferences/pinaka_preferences.dart';
// import '../services/CustomerDisplayService.dart';
//
//
// class CustomerDisplayHelper {
//   static bool skipNextPendingOrderRefresh = false;
//   /// 🔹 Show welcome after login success, including optional logo
//   static Future<void> updateWelcomeWithStore(
//       String storeId,
//       String storeName, {
//         String? storeLogoUrl,
//         String? storeBaseUrl,
//       }) async {
//     print(
//         "🟢 [CustomerDisplayHelper] Updating welcome → storeId: $storeId, storeName: $storeName, logo: $storeLogoUrl, baseUrl: $storeBaseUrl");
//     final activeId = OrderHelper().activeOrderId;
//
//     // ✅ ONLY show welcome if no active order
//     if (activeId != null) {
//       print("⛔ Skipping welcome — active order exists");
//       return;
//     }
//
//     await CustomerDisplayService.showWelcomeWithStore(
//       storeId: storeId,
//       storeName: storeName,
//       storeLogoUrl: storeLogoUrl,
//       storeBaseUrl: storeBaseUrl,
//     );
//   }
//
//   static Future<void> clearOrder() async {
//     try {
//       await CustomerDisplayService.showWelcome();
//       print("🧹 Customer display cleared (order reset)");
//     } catch (e) {
//       print("❌ Failed to clear customer display: $e");
//     }
//   }
//
//
//   static Future<void> updateCustomerDisplay(
//       int serverOrderId, {
//         bool summaryEnabled = false,
//       }) async {
//     try {
//       if (skipNextPendingOrderRefresh) {
//         print("⛔ [CD] Skipping customer display refresh for pending order");
//         skipNextPendingOrderRefresh = false;
//         return;   // ← whole update silently dropped, ONE TIME
//       }
//
//       final int? activeId = OrderHelper().activeOrderId;
//
// // ❌ BLOCK if no active order
//       if (activeId == null) {
//         print("🟢 [CD] No active order → showing welcome");
//
//         final storeInfo = PinakaPreferences.getLoggedInStore();
//
//         if (storeInfo.isNotEmpty) {
//           await CustomerDisplayHelper.updateWelcomeWithStore(
//             storeInfo['storeId']!,
//             storeInfo['storeName']!,
//             storeLogoUrl: storeInfo['storeLogoUrl'],
//             storeBaseUrl: storeInfo['storeBaseUrl'],
//           );
//         } else {
//           await CustomerDisplayService.showWelcome();
//         }
//
//         return;
//       }
//
// // ❌ BLOCK stale updates
//       if (activeId != serverOrderId) {
//         print("🟥 [CD] Stale update detected");
//
//         if (activeId == null) {
//           await CustomerDisplayService.showWelcome();
//         }
//
//         return;
//       }
//
//       print("🟡 [CD] START updateCustomerDisplay → serverOrderId=$serverOrderId");
//
//       final offlineBox = StorageProvider.offlineOrders;
//       final raw = await offlineBox.get(serverOrderId.toString());
//
//       print("🗃 [CD] Checking Hive for key=$serverOrderId → found=${raw != null}");
//
//       if (raw == null) {
//         print("🟡 [CD] No Hive data yet → showing empty order");
//
//         await CustomerDisplayService.showCustomerData(
//           orderId: serverOrderId,
//           items: [],
//           grossTotal: 0.0,
//           discount: 0.0,
//           merchantDiscount: 0.0,
//           netTotal: 0.0,
//           tax: 0.0,
//           netPayable: 0.0,
//           orderDate: "",
//           orderTime: "",
//           cashbackFee: 0.0,
//           loyaltyContact: "",
//           summaryEnabled: summaryEnabled,
//           discountType: "NONE",
//           discountValue: 0.0,
//           redeemedAmount: 0.0,
//         );
//
//         return;
//       }
//
//       final data = Map<String, dynamic>.from(raw);
//
//       // 🔥 SOURCE OF TRUTH — DISCOUNT LINES
//       final Map<String, dynamic> discountLines =
//       (data["discount_lines"] is Map)
//           ? Map<String, dynamic>.from(data["discount_lines"])
//           : {};
//
//       print("🧠 DISCOUNT LINES FROM HIVE → $discountLines");
//
//
//       // 🔥 Fetch WooCommerce Order ID stored earlier after sync
//       final wooOrderId = data["wooOrderId"];
//
//       print("🟣 [CD] Woo Order ID fetched from Hive → $wooOrderId");
//
//
//       Future<double> _getAutoDiscountPerUnit(int productId, int qty) async {
//         try {
//           final box = StorageProvider.productCache;
//           final allEntries = await box.toMap();
//
//           for (var key in allEntries.keys) {
//             if (!key.toString().startsWith("products_")) continue;
//
//             final cached = allEntries[key];
//             if (cached == null) continue;
//
//             List products;
//             if (cached is List) {
//               products = cached;
//             } else if (cached is Map && cached['data'] != null) {
//               products = json.decode(cached['data'].toString());
//             } else {
//               continue;
//             }
//
//             final product = products.cast<Map>().firstWhere(
//                   (p) =>
//               p['fast_key_product_id'] == productId ||
//                   p['id'] == productId,
//               orElse: () => <String, dynamic>{},
//             );
//
//             if (product.isEmpty) continue;
//
//             final bool enabled = product['auto_discount_enabled'] == true;
//             final double discount =
//                 double.tryParse(product['discount_amount']?.toString() ?? '0') ?? 0.0;
//
//             if (!enabled || discount <= 0 || qty <= 0) return 0.0;
//
//             return discount; // 👈 per-unit discount
//           }
//         } catch (e) {
//           print("❌ [CD] Auto discount error → $e");
//         }
//         return 0.0;
//       }
//
//
//       print("🔶🔶🔶 RAW HIVE ORDER DATA (FULL DUMP) 🔶🔶🔶");
//       data.forEach((key, value) {
//         print(" ▶ $key : $value");
//       });
//       print("🔶🔶🔶 END RAW HIVE ORDER DATA 🔶🔶🔶");
//
//       // ------------------ DATE & TIME ------------------
//       String orderDate = "";
//       String orderTime = "";
//
//       final createdAt = data["created_at"]?.toString() ?? "";
//
//       if (createdAt.isNotEmpty) {
//         final dt = DateTime.tryParse(createdAt);
//         if (dt != null) {
//
//           // 👉 Format: MM-DD-YYYY
//           orderDate =
//           "${dt.month.toString().padLeft(2, '0')}-"
//               "${dt.day.toString().padLeft(2, '0')}-"
//               "${dt.year}";
//
//           // 👉 12-hour time with AM/PM
//           final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
//           final minute = dt.minute.toString().padLeft(2, '0');
//           final second = dt.second.toString().padLeft(2, '0');
//           final amPm = dt.hour >= 12 ? "PM" : "AM";
//
//           orderTime = "$hour:$minute:$second $amPm";
//         }
//       }
//
//       // ------------------ FILTER PRODUCT LIST ------------------
//       final productsRaw = (data["products"] ?? []) as List;
//
//       final payoutsRaw = (data["payouts"] ?? []) as List;
//       final cashbacksRaw = (data["cashbacks"] ?? []) as List;
//
//       if (productsRaw.isEmpty &&
//           payoutsRaw.isEmpty &&
//           cashbacksRaw.isEmpty) {
//         print("🟡 [CD] Empty order → showing order with no items");
//
//         await CustomerDisplayService.showCustomerData(
//             orderId: serverOrderId,
//             items: [],
//             grossTotal: 0.0,
//             discount: 0.0,
//             merchantDiscount: 0.0,
//             netTotal: 0.0,
//             tax: 0.0,
//             netPayable: 0.0,
//             orderDate: "",
//             orderTime: "",
//             cashbackFee: 0.0,
//             loyaltyContact: "",
//             summaryEnabled: summaryEnabled,
//             discountType: "NONE",
//             discountValue: 0.0,
//             redeemedAmount: 0.0
//         );
//
//         return;
//       }
//
//       print("🔵 [CD] RAW PRODUCTS FROM HIVE (BEFORE FILTER):");
//       for (var p in productsRaw) {
//         print(" → RAW ITEM: $p");
//       }
//
//       final products = productsRaw
//           .map((e) => Map<String, dynamic>.from(e))
//           .where((p) {
//         final type = (p["type"] ?? "").toString().toLowerCase();
//         final productId = (p["product_id"] ?? 0);
//         final price = (p["price"] ?? 0).toDouble();
//         final name = (p["name"] ?? "").toString().toLowerCase();
//
//         // 🚫 This is a coupon / non-real product line
//         final isCouponLine =
//             type == "coupon" ||
//                 productId == -1 ||
//                 name.contains("discount") ||
//                 name.contains("coupon") ||
//                 price < 0;
//
//         return !isCouponLine;
//       })
//           .toList();
//
//       double _getUnitPrice(Map<String, dynamic> p) {
//
//         final type = (p["type"] ?? "").toString().toLowerCase();
//         if (type == "weighted") {
//           final selling = p["price"];
//           if (selling is num && selling > 0) {
//             return selling.toDouble();
//           }
//         }
//         final unit = p["unit_price"];
//         if (unit is num && unit > 0) {
//           return unit.toDouble();
//         }
//
//         final sales = p["sales_price"];
//         if (sales is num && sales > 0) {
//           return sales.toDouble();
//         }
//         final price = p["price"];
//         if (price is num) {
//           return price.toDouble();
//         }
//
//         return 0.0;
//       }
//
//
//       print("🟢 [CD] PRODUCTS AFTER FILTER:");
//       for (var p in products) {
//         print(
//             " → ${p['name']} | qty=${p['quantity']} | unit_price=${_getUnitPrice(p)} | price=${p['price']}"
//         );
//       }
//
//       // ------------------ PAYOUTS ------------------
//       final payouts = ((data["payouts"] ?? []) as List)
//           .map((e) => Map<String, dynamic>.from(e))
//           .toList();
//
//       // ------------------ CASHBACKS ------------------
//       final cashbacks = ((data["cashbacks"] ?? []) as List)
//           .map((e) => Map<String, dynamic>.from(e))
//           .toList();
//
//       // ------------------ CASHBACK FEE ------------------
//       double cashbackFee =
//       (data["cashbackFee"] is num) ? (data["cashbackFee"] as num).toDouble() : 0.0;
//
//       print("💰 cashbackFee = $cashbackFee");
//
//       // ------------------ BUILD PARSED ITEMS LIST ------------------
//       final parsedItems = [
//         ...products.map((item) {
//           // final qty =
//           //     int.tryParse(item["quantity"]?.toString() ?? "1") ?? 1;
//           //
//           // final unitPrice = _getUnitPrice(item);
//
//
//           final String itemTypeForQty =
//           (item["type"] ?? item["item_type"] ?? "").toString().toLowerCase();
//
//           double qty;
//           if (itemTypeForQty.contains("weighted")) {
//             final dynamic rawWeight = item["weight_qty"] ??
//                 item["weightQty"] ??
//                 item["weight"] ??
//                 item["quantity"] ??
//                 1;
//             qty = (rawWeight is num)
//                 ? rawWeight.toDouble()
//                 : double.tryParse(rawWeight.toString()) ?? 1.0;
//           } else {
//             qty = double.tryParse(item["quantity"]?.toString() ?? "1") ?? 1.0;
//           }
//
//           final unitPrice = _getUnitPrice(item);
//
//
//           final pid = item["product_id"]?.toString() ?? "";
//
// // read from discount_lines instead of item
//           final discountMeta =
//           discountLines.containsKey(pid)
//               ? Map<String, dynamic>.from(discountLines[pid])
//               : {};
//
//           final double totalDiscount =
//               (discountMeta["amount"] as num?)?.toDouble() ?? 0.0;
//
//           final double perUnitDiscount =
//           qty > 0 ? totalDiscount / qty : 0.0;
//
//           print("""
// 🟠 [CD] RESOLVED DISCOUNT
//  product : ${item["name"]}
//  productId : $pid
//  meta : $discountMeta
//  perUnit : $perUnitDiscount
// """);
//
//           print("""
// 🔴 [CD] RAW PRODUCT ITEM FROM HIVE
//   name        : ${item["name"]}
//   quantity    : ${item["quantity"]}
//   price(raw)  : ${item["price"]}
//   unit_price  : ${item["unit_price"]}
//   discount_meta : ${item["discount_meta"]}
// """);
//
//           return {
//             "name": item["name"] ?? "",
//             "qty": qty.toDouble(),
//             "price": unitPrice,
//             "original_price": unitPrice,
//             "auto_discount": totalDiscount,
//             "discount_type": discountMeta["type"] ?? "",
//             "combo_discount": item["combo_discount"] ??
//                 (item['combo_discount_total'] as num?)?.toDouble() ?? 0.0,
//             "multipack_discount": item["multipack_discount"] ??
//                 (item['multipack_discount_total'] as num?)?.toDouble() ?? 0.0,
//
//             "unit_discount": perUnitDiscount,
//             "discount_source": discountMeta["source"] ?? "",
//             "rule_id": discountMeta["rule_id"] ?? "",
//             "image": item["image"] ?? "",
//           };
//         }),
//
//
//         ...payouts.map((p) => {
//           "name": "Payout",
//           "qty": 1.0,
//           "price": (p["amount"] ?? 0).toDouble(),
//           "image": "assets/svg/payout.svg",
//         }),
//
//         ...cashbacks.map((c) => {
//           "name": "Cashback",
//           "qty": 1.0,
//           "price": (c["amount"] ?? 0).toDouble(),
//           "image": c["product_image"] ?? "",
//         }),
//
//       ];
//
//       // ------------------ TOTALS ------------------
//       double productTotal = parsedItems
//           .where((i) => i["name"] != "Payout" && i["name"] != "Cashback")
//           .fold(0.0, (sum, i) {
//         final qty = (i["qty"] as num?)?.toDouble() ?? 1.0;
//         final price = (i["price"] as num?)?.toDouble() ?? 0.0;
//         final totalDiscount = (i["auto_discount"] as num?)?.toDouble() ?? 0.0;
//         return sum + ((price * qty) - totalDiscount);
//
//       });
//
//
//       double payoutTotal =
//       payouts.fold(0, (sum, p) => sum + (p["amount"] ?? 0).toDouble());
//
//       double cashbackTotal =
//       cashbacks.fold(0, (sum, c) => sum + (c["amount"] ?? 0).toDouble());
//
//       double grossTotal = productTotal + payoutTotal + cashbackTotal;
//
//       // Discounts 🟡
//       double orderDiscount =
//       (data["orderDiscount"] is num) ? (data["orderDiscount"] as num).toDouble() : 0.0;
//
//       double merchantDiscountStored =
//       (data["merchantDiscount"] is num) ? (data["merchantDiscount"] as num).toDouble() : 0.0;
//
//       bool merchantIsPercentage =
//           (data["merchantDiscountIsPercentage"] as bool?) ?? false;
//
//       double merchantDiscount = merchantDiscountStored;
//
//       // Tax 🟡
//       double orderTax =
//       (data["tax_discount"] is num)
//           ? (data["tax_discount"] as num).toDouble()
//           : 0.0;
//
//
//       // Final calculations
//       double netTotal = grossTotal - orderDiscount;
//       double netPayable = netTotal + cashbackFee + orderTax - merchantDiscount;
//
//       // ------------------ LOGS ------------------
//       print("✅ [CD] CALCULATION RESULTS");
//       print(" productTotal = $productTotal");
//       print(" payoutTotal = $payoutTotal");
//       print(" cashbackTotal = $cashbackTotal");
//       print(" grossTotal = $grossTotal");
//       print(" orderDiscount = $orderDiscount");
//       print(
//           " merchantDiscount = $merchantDiscount (${merchantIsPercentage ? "Percentage" : "Fixed"})");
//       print(" orderTax = $orderTax");
//       print(" netTotal = $netTotal");
//       print(" netPayable = $netPayable");
//       print(" orderDate = $orderDate");
//       print(" orderTime = $orderTime");
//       // ------------------ LOYALTY CONTACT ------------------
//       final loyaltyContact = data["loyaltyContact"]?.toString() ?? "";
//       print("☎ Loyalty Contact = $loyaltyContact");
//       final int availablePoints =
//           int.tryParse(data["available_points"]?.toString() ?? "0") ?? 0;
//       print("🎯 Available Points = $availablePoints");
//
//       // ------------------ PUSH TO CUSTOMER DISPLAY ------------------
//       // final int safeOrderId =
//       //     int.tryParse(wooOrderId?.toString() ?? "") ?? serverOrderId;
//       final int safeOrderId = serverOrderId;
//
//       final double totalItemDiscount = parsedItems.fold(
//         0.0,
//             (sum, i) => sum + ((i["auto_discount"] ?? 0.0) as num),
//       );
//
//
//       final String appliedDiscountType = parsedItems
//           .map((i) => i["discount_type"])
//           .firstWhere(
//             (t) => t != null && t.toString().isNotEmpty,
//         orElse: () => "NONE",
//       );
//       await CustomerDisplayService.showCustomerData(
//         orderId: safeOrderId,
//         items: parsedItems,
//         grossTotal: grossTotal,
//         discount: orderDiscount,
//         merchantDiscount: merchantDiscount,
//         netTotal: netTotal,
//         tax: orderTax,
//         netPayable: netPayable,
//         orderDate: orderDate,
//         orderTime: orderTime,
//         cashbackFee: cashbackFee,
//         loyaltyContact: loyaltyContact,
//         summaryEnabled: summaryEnabled,
//         discountType: appliedDiscountType,
//         discountValue: totalItemDiscount,
//         redeemedAmount: 0.0,
//         availablePoints: availablePoints, // ← FIX
//       );
//
//
//       print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
//     } catch (e, s) {
//       print("❌ [CD] updateCustomerDisplay failed: $e");
//       print(s);
//     }
//   }
// }

//////=========>

import 'dart:async';
import 'dart:convert';

import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import '../Database/order_panel_db_helper.dart';
import '../Preferences/pinaka_preferences.dart';
import '../mqtt_server/cart_item.dart';
import '../mqtt_server/cart_state.dart';
import '../mqtt_server/cfd_store_payload.dart';
import '../mqtt_server/store_messaging_service.dart';
import '../services/customerdisplayservice.dart';

// ========== NEW MQTT IMPORTS ==========
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Widgets/naviagtion_services.dart'; // for navigatorKey
// ======================================

class CustomerDisplayHelper {
  static bool skipNextPendingOrderRefresh = false;

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

    // ========== NEW: Publish IDLE to MQTT CFD ==========
    await _publishMqttScreen('IDLE');
    // ===================================================
  }

  static Future<void> clearOrder() async {
    try {
      await CustomerDisplayService.showWelcome();
      print("🧹 Customer display cleared (order reset)");

      // ========== NEW: Publish IDLE to MQTT CFD ==========
      await _publishMqttScreen('IDLE');
      // ===================================================
    } catch (e) {
      print("❌ Failed to clear customer display: $e");
    }
  }

  static Future<void> updateCustomerDisplay(
    int serverOrderId, {
    bool summaryEnabled = false,
  }) async {
    try {
      if (skipNextPendingOrderRefresh) {
        print("⛔ [CD] Skipping customer display refresh for pending order");
        skipNextPendingOrderRefresh = false;
        return; // ← whole update silently dropped, ONE TIME
      }

      final int? activeId = OrderHelper().activeOrderId;

      // ❌ BLOCK if no active order
      if (activeId == null) {
        print("🟢 [CD] No active order → showing welcome");

        final storeInfo = PinakaPreferences.getLoggedInStore();

        if (storeInfo.isNotEmpty) {
          await CustomerDisplayHelper.updateWelcomeWithStore(
            storeInfo['storeId']!,
            storeInfo['storeName']!,
            storeLogoUrl: storeInfo['storeLogoUrl'],
            storeBaseUrl: storeInfo['storeBaseUrl'],
          );
        } else {
          await CustomerDisplayService.showWelcome();
          // ========== NEW ==========
          await _publishMqttScreen('IDLE');
          // =========================
        }

        return;
      }

      // ❌ BLOCK stale updates
      if (activeId != serverOrderId) {
        print("🟥 [CD] Stale update detected");

        if (activeId == null) {
          await CustomerDisplayService.showWelcome();
          // ========== NEW ==========
          await _publishMqttScreen('IDLE');
          // =========================
        }

        return;
      }

      print(
          "🟡 [CD] START updateCustomerDisplay → serverOrderId=$serverOrderId");

      final offlineBox = StorageProvider.offlineOrders;
      final raw = await offlineBox.get(serverOrderId.toString());

      print(
          "🗃 [CD] Checking Hive for key=$serverOrderId → found=${raw != null}");

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
          redeemedAmount: 0.0,
        );

        final storePayload = await CfdStorePayload.load();

        // ========== NEW: Publish empty CART / PAYMENT ==========
        await _publishMqttCart(
          orderId: serverOrderId,
          items: [],
          tax: 0.0,
          screen: summaryEnabled ? 'PAYMENT' : 'CART',
          message: summaryEnabled ? 'Please complete payment' : null,
          storeId: storePayload.storeId,
          storeName: storePayload.storeName,
          storeLogoUrl: storePayload.storeLogoUrl,
          storeBaseUrl: storePayload.storeBaseUrl,
          slideshowUrls: storePayload.slideshowUrls,
        );
        // ======================================================

        return;
      }

      final data = Map<String, dynamic>.from(raw);

      // 🔥 SOURCE OF TRUTH — DISCOUNT LINES
      final Map<String, dynamic> discountLines = (data["discount_lines"] is Map)
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
            final double discount = double.tryParse(
                    product['discount_amount']?.toString() ?? '0') ??
                0.0;

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
          orderDate = "${dt.month.toString().padLeft(2, '0')}-"
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

      final payoutsRaw = (data["payouts"] ?? []) as List;
      final cashbacksRaw = (data["cashbacks"] ?? []) as List;

      if (productsRaw.isEmpty && payoutsRaw.isEmpty && cashbacksRaw.isEmpty) {
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
          redeemedAmount: 0.0,
        );

        final storePayload = await CfdStorePayload.load();

        // ========== NEW ==========
        await _publishMqttCart(
          orderId: serverOrderId,
          items: [],
          tax: 0.0,
          screen: summaryEnabled ? 'PAYMENT' : 'CART',
          message: summaryEnabled ? 'Please complete payment' : null,
          storeId: storePayload.storeId,
          storeName: storePayload.storeName,
          storeLogoUrl: storePayload.storeLogoUrl,
          storeBaseUrl: storePayload.storeBaseUrl,
          slideshowUrls: storePayload.slideshowUrls,
        );
        // =========================

        return;
      }

      print("🔵 [CD] RAW PRODUCTS FROM HIVE (BEFORE FILTER):");
      for (var p in productsRaw) {
        print(" → RAW ITEM: $p");
      }

      final products =
          productsRaw.map((e) => Map<String, dynamic>.from(e)).where((p) {
        final type = (p["type"] ?? "").toString().toLowerCase();
        final productId = (p["product_id"] ?? 0);
        final price = (p["price"] ?? 0).toDouble();
        final name = (p["name"] ?? "").toString().toLowerCase();

        // 🚫 This is a coupon / non-real product line
        final isCouponLine = type == "coupon" ||
            productId == -1 ||
            name.contains("discount") ||
            name.contains("coupon") ||
            price < 0;

        return !isCouponLine;
      }).toList();

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
            " → ${p['name']} | qty=${p['quantity']} | unit_price=${_getUnitPrice(p)} | price=${p['price']}");
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
      double cashbackFee = (data["cashbackFee"] is num)
          ? (data["cashbackFee"] as num).toDouble()
          : 0.0;

      print("💰 cashbackFee = $cashbackFee");

      // ------------------ BUILD PARSED ITEMS LIST ------------------
      final parsedItems = [
        ...products.map((item) {
          final String itemTypeForQty =
              (item["type"] ?? item["item_type"] ?? "")
                  .toString()
                  .toLowerCase();

          double qty;
          if (itemTypeForQty.contains("weighted")) {
            final dynamic rawWeight = item["weight_qty"] ??
                item["weightQty"] ??
                item["weight"] ??
                item["quantity"] ??
                1;
            qty = (rawWeight is num)
                ? rawWeight.toDouble()
                : double.tryParse(rawWeight.toString()) ?? 1.0;
          } else {
            qty = double.tryParse(item["quantity"]?.toString() ?? "1") ?? 1.0;
          }

          final unitPrice = _getUnitPrice(item);

          final pid = item["product_id"]?.toString() ?? "";

          // read from discount_lines instead of item
          final discountMeta = discountLines.containsKey(pid)
              ? Map<String, dynamic>.from(discountLines[pid])
              : {};

          final double totalDiscount =
              (discountMeta["amount"] as num?)?.toDouble() ?? 0.0;

          final double perUnitDiscount = qty > 0 ? totalDiscount / qty : 0.0;

          double autoD = (item['auto_discount'] as num?)?.toDouble() ??
              (item['_pos_auto_discount'] as num?)?.toDouble() ??
              (item['autoDiscount'] as num?)?.toDouble() ??
              (item['auto_discount_total'] as num?)?.toDouble() ??
              0.0;
          double comboD = (item['combo_discount'] as num?)?.toDouble() ??
              (item['combo_discount_total'] as num?)?.toDouble() ??
              (item['comboDiscount'] as num?)?.toDouble() ??
              0.0;
          double multipackD = (item['multipack_discount'] as num?)?.toDouble() ??
              (item['multipack_discount_total'] as num?)?.toDouble() ??
              (item['multipackDiscountTotal'] as num?)?.toDouble() ??
              (item['multipackDiscount'] as num?)?.toDouble() ??
              (item['multipack_discount_amount'] as num?)?.toDouble() ??
              0.0;
          double mixmatchD = (item['mixmatch_discount'] as num?)?.toDouble() ??
              (item['mixmatch_discount_total'] as num?)?.toDouble() ??
              (item['mixmatchDiscount'] as num?)?.toDouble() ??
              0.0;

          final String dMetaType = (item['discount_type'] ?? item['discountType'] ?? discountMeta["type"] ?? "").toString().toLowerCase();
          final String dMetaSource = (item['discount_source'] ?? item['discountSource'] ?? discountMeta["source"] ?? "").toString().toLowerCase();
          final bool multipackApplied = item['multipackApplied'] == true || item['multipack_applied'] == true;

          if (totalDiscount > 0) {
            if (multipackApplied || dMetaType.contains('multi') || dMetaSource.contains('multi')) {
              if (multipackD <= 0) multipackD = totalDiscount;
            } else if (dMetaType.contains('combo') || dMetaSource.contains('combo')) {
              if (comboD <= 0) comboD = totalDiscount;
            } else if (dMetaType.contains('mix') || dMetaSource.contains('mix')) {
              if (mixmatchD <= 0) mixmatchD = totalDiscount;
            } else if (dMetaType.contains('auto') || dMetaSource.contains('auto')) {
              if (autoD <= 0) autoD = totalDiscount;
            }
          }

          String resolvedType = '';
          if (multipackD > 0 || multipackApplied || dMetaType.contains('multi') || dMetaSource.contains('multi')) {
            resolvedType = 'multipack';
            if (multipackD <= 0 && autoD > 0) {
              multipackD = autoD;
              autoD = 0.0;
            }
          } else if (comboD > 0 || dMetaType.contains('combo') || dMetaSource.contains('combo')) {
            resolvedType = 'combo';
            if (comboD <= 0 && autoD > 0) {
              comboD = autoD;
              autoD = 0.0;
            }
          } else if (mixmatchD > 0 || dMetaType.contains('mix') || dMetaSource.contains('mix')) {
            resolvedType = 'mixmatch';
            if (mixmatchD <= 0 && autoD > 0) {
              mixmatchD = autoD;
              autoD = 0.0;
            }
          } else if (autoD > 0 || dMetaType.contains('auto') || dMetaSource.contains('auto')) {
            resolvedType = 'auto';
          }

          final bool isEbt = item['is_ebt_eligible'] == true ||
              item['isEbtEligible'] == true ||
              item['ebt_eligible'] == true ||
              item['is_ebt_eligible'] == 1 ||
              item['isEbtEligible'] == 1 ||
              item['ebt_eligible'] == 1 ||
              item['is_ebt_eligible']?.toString() == '1' ||
              item['isEbtEligible']?.toString() == '1' ||
              item['ebt_eligible']?.toString() == '1' ||
              item['is_ebt_eligible']?.toString() == 'true' ||
              item['isEbtEligible']?.toString() == 'true' ||
              item['ebt_eligible']?.toString() == 'true';

          print("""
🟠 [CD] RESOLVED DISCOUNT & EBT
 product : ${item["name"]}
 productId : $pid
 isEbt : $isEbt
 meta : $discountMeta
 autoD : $autoD | multipackD : $multipackD | comboD : $comboD | mixmatchD : $mixmatchD
 resolvedType : $resolvedType
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
            "auto_discount": autoD,
            "combo_discount": comboD,
            "multipack_discount": multipackD,
            "mixmatch_discount": mixmatchD,
            "discount_type": resolvedType,
            "unit_discount": perUnitDiscount,
            "discount_source": discountMeta["source"] ?? "",
            "rule_id": discountMeta["rule_id"] ?? "",
            "image": item["image"] ?? "",
            "product_id": pid,
            "is_ebt_eligible": isEbt,
            "isEbtEligible": isEbt,
            "ebt_eligible": isEbt,
          };
        }),
        ...payouts.map((p) {
          final double pAmt = (p["amount"] is num)
              ? (p["amount"] as num).toDouble()
              : (double.tryParse((p["amount"] ??
                          p["price"] ??
                          p["total"] ??
                          p["payout_amount"] ??
                          0)
                      .toString()) ??
                  0.0);
          final String pName =
              (p["product_name"] ?? p["name"] ?? p["item_name"] ?? "Payout")
                  .toString();
          final String pImg = (p["product_image"] ??
                  p["image"] ??
                  p["item_image"] ??
                  "assets/svg/payout.svg")
              .toString();
          return {
            "name": pName.isNotEmpty ? pName : "Payout",
            "qty": 1.0,
            "price": -pAmt.abs(),
            "original_price": -pAmt.abs(),
            "auto_discount": 0.0,
            "image": pImg,
            "product_id": (p["payout_product_id"] ??
                    p["product_id"] ??
                    p["id"] ??
                    "payout")
                .toString(),
            "item_type": "payout",
            "is_ebt_eligible": false,
            "isEbtEligible": false,
            "ebt_eligible": false,
          };
        }),
        ...cashbacks.map((c) {
          final double cAmt = (c["amount"] is num)
              ? (c["amount"] as num).toDouble()
              : (double.tryParse((c["amount"] ?? c["price"] ?? 0).toString()) ??
                  0.0);
          return {
            "name": "Cashback",
            "qty": 1.0,
            "price": cAmt.abs(),
            "original_price": cAmt.abs(),
            "auto_discount": 0.0,
            "image": c["product_image"] ?? c["image"] ?? "",
            "product_id": "cashback",
            "item_type": "cashback",
            "is_ebt_eligible": false,
            "isEbtEligible": false,
            "ebt_eligible": false,
          };
        }),
      ];

      // ------------------ TOTALS ------------------
      double productTotal = parsedItems
          .where((i) =>
              i["name"] != "Payout" &&
              i["name"] != "Cashback" &&
              i["product_id"] != "payout")
          .fold(0.0, (sum, i) {
        final qty = (i["qty"] as num?)?.toDouble() ?? 1.0;
        final price = (i["price"] as num?)?.toDouble() ?? 0.0;
        final double autoD = (i["auto_discount"] as num?)?.toDouble() ?? 0.0;
        final double comboD = (i["combo_discount"] as num?)?.toDouble() ?? 0.0;
        final double multiD = (i["multipack_discount"] as num?)?.toDouble() ?? 0.0;
        final double mixD = (i["mixmatch_discount"] as num?)?.toDouble() ?? 0.0;

        double lineItemDiscount = [autoD, comboD, multiD, mixD].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        return sum + ((price * qty) - lineItemDiscount);
      });

      double payoutTotal = payouts.fold(0.0, (sum, p) {
        final double pAmt = (p["amount"] is num)
            ? (p["amount"] as num).toDouble()
            : (double.tryParse(
                    (p["amount"] ?? p["price"] ?? p["payout_amount"] ?? 0)
                        .toString()) ??
                0.0);
        return sum + pAmt.abs();
      });

      double cashbackTotal = cashbacks.fold(0.0, (sum, c) {
        final double cAmt = (c["amount"] is num)
            ? (c["amount"] as num).toDouble()
            : (double.tryParse((c["amount"] ?? c["price"] ?? 0).toString()) ??
                0.0);
        return sum + cAmt.abs();
      });

      double grossTotal = productTotal + payoutTotal + cashbackTotal;

      // Discounts 🟡
      double orderDiscount = [
        (data["orderDiscount"] as num?)?.toDouble() ?? 0.0,
        (data["order_discount"] as num?)?.toDouble() ?? 0.0,
        (data["couponDiscount"] as num?)?.toDouble() ?? 0.0,
        (data["coupon_discount"] as num?)?.toDouble() ?? 0.0,
        (data["couponAmount"] as num?)?.toDouble() ?? 0.0,
      ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      double merchantDiscountStored = [
        (data["merchantDiscount"] as num?)?.toDouble() ?? 0.0,
        (data["merchant_discount"] as num?)?.toDouble() ?? 0.0,
        (data["merchantDiscountAmount"] as num?)?.toDouble() ?? 0.0,
        (data["recalculatedMerchantDiscount"] as num?)?.toDouble() ?? 0.0,
      ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      bool merchantIsPercentage =
          (data["merchantDiscountIsPercentage"] as bool?) ?? false;

      double merchantDiscount = merchantDiscountStored;

      // Tax 🟡
      double orderTax = (data["tax_discount"] is num)
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
      print(" Loyalty Contact = $loyaltyContact");
      final int availablePoints =
          int.tryParse(data["available_points"]?.toString() ?? "0") ?? 0;
      print(" Available Points = $availablePoints");

      // ------------------ STORE DETAILS & BANNERS ------------------
      final storePayload = await CfdStorePayload.load();

      // ------------------ PUSH TO CUSTOMER DISPLAY ------------------
      final int safeOrderId = serverOrderId;

      final double totalItemDiscount = parsedItems.fold(
        0.0,
        (sum, i) {
          final double autoD = (i["auto_discount"] as num?)?.toDouble() ?? 0.0;
          final double comboD = (i["combo_discount"] as num?)?.toDouble() ?? 0.0;
          final double multiD = (i["multipack_discount"] as num?)?.toDouble() ?? 0.0;
          final double mixD = (i["mixmatch_discount"] as num?)?.toDouble() ?? 0.0;

          double d = [autoD, comboD, multiD, mixD].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);
          return sum + d;
        },
      );

      final String appliedDiscountType =
          parsedItems.map((i) => i["discount_type"]).firstWhere(
                (t) => t != null && t.toString().isNotEmpty,
                orElse: () => "NONE",
              );

      // Run Native display update in background unawaited so MQTT is never delayed by hardware calls
      unawaited(CustomerDisplayService.showCustomerData(
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
        redeemedAmount: 0.0,
        availablePoints: availablePoints,
        storeId: storePayload.storeId,
        storeName: storePayload.storeName,
        storeLogoUrl: storePayload.storeLogoUrl,
        storeBaseUrl: storePayload.storeBaseUrl,
        slideshowUrls: storePayload.slideshowUrls,
      ));

      await _publishMqttCart(
        orderId: safeOrderId,
        items: parsedItems,
        tax: orderTax,
        orderDiscount: orderDiscount,
        merchantDiscount: merchantDiscount,
        netPayable: netPayable,
        grossTotal: grossTotal,
        screen: summaryEnabled ? 'PAYMENT' : 'CART',
        message: summaryEnabled ? 'Please complete payment' : null,
        storeId: storePayload.storeId,
        storeName: storePayload.storeName,
        storeLogoUrl: storePayload.storeLogoUrl,
        storeBaseUrl: storePayload.storeBaseUrl,
        slideshowUrls: storePayload.slideshowUrls,
      );
      // ========================================================

      print("✅ [CD] Completed updateCustomerDisplay → $serverOrderId");
    } catch (e, s) {
      print("❌ [CD] updateCustomerDisplay failed: $e");
      print(s);
    }
  }

  // =========================================================
  // ========== NEW MQTT HELPER METHODS ======================
  // =========================================================

  /// Publish full cart state to MQTT CFD
  static Future<void> _publishMqttCart({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required double tax,
    required String screen,
    String? message,
    double orderDiscount = 0.0,
    double merchantDiscount = 0.0,
    double netPayable = 0.0,
    double grossTotal = 0.0,
    String? storeId,
    String? storeName,
    String? storeLogoUrl,
    String? storeBaseUrl,
    List<String>? slideshowUrls,
  }) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        print("⚠️ [MQTT] No context available — skip publish");
        return;
      }

      final messaging =
          Provider.of<StoreMessagingService>(context, listen: false);

      final List<CartItem> mqttItems = items.map((i) {
        final bool ebtFlag = i["is_ebt_eligible"] == true ||
            i["isEbtEligible"] == true ||
            i["ebt_eligible"] == true ||
            i["is_ebt_eligible"] == 1 ||
            i["isEbtEligible"] == 1 ||
            i["ebt_eligible"] == 1 ||
            i["is_ebt_eligible"]?.toString() == "1" ||
            i["isEbtEligible"]?.toString() == "1" ||
            i["ebt_eligible"]?.toString() == "1" ||
            i["is_ebt_eligible"]?.toString() == "true" ||
            i["isEbtEligible"]?.toString() == "true" ||
            i["ebt_eligible"]?.toString() == "true";

        double parseNum(dynamic v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0.0;
        }

        final double posAuto = [
          parseNum(i['auto_discount']),
          parseNum(i['autoDiscount']),
          parseNum(i['auto_discount_total']),
        ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        final double combo = [
          parseNum(i['combo_discount']),
          parseNum(i['comboDiscount']),
          parseNum(i['combo_discount_total']),
        ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        final double multipack = [
          parseNum(i['multipack_discount']),
          parseNum(i['multipackDiscount']),
          parseNum(i['multipack_discount_total']),
        ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        final double mixmatch = [
          parseNum(i['mixmatch_discount']),
          parseNum(i['mixmatchDiscount']),
          parseNum(i['mixmatch_discount_total']),
        ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        String? dType = (i['discount_type'] ?? i['discountType'])?.toString();
        if (dType != null && dType.isNotEmpty) {
          final String dtLower = dType.toLowerCase();
          if (dtLower.contains('combo')) {
            dType = 'combo';
          } else if (dtLower.contains('multi')) {
            dType = 'multipack';
          } else if (dtLower.contains('mix')) {
            dType = 'mixmatch';
          } else if (dtLower.contains('auto')) {
            dType = 'auto';
          }
        } else {
          final String dSource = (i['discount_source'] ?? '').toString().toLowerCase();
          if (multipack > 0 || dSource.contains('multipack') || dSource.contains('multi')) {
            dType = 'multipack';
          } else if (combo > 0 || dSource.contains('combo')) {
            dType = 'combo';
          } else if (mixmatch > 0 || dSource.contains('mix')) {
            dType = 'mixmatch';
          } else if (posAuto > 0 || dSource.contains('auto')) {
            dType = 'auto';
          }
        }

        double itemDiscount = [posAuto, combo, multipack, mixmatch].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

        return CartItem(
          productId: (i["payout_product_id"] ??
                  i["product_id"] ??
                  i["id"] ??
                  i["name"] ??
                  "")
              .toString(),
          name: (i["product_name"] ?? i["name"] ?? i["item_name"] ?? "Item")
              .toString(),
          qty: ((i["qty"] as num?)?.toInt() ??
              (i["quantity"] as num?)?.toInt() ??
              1),
          unitPrice: (i["price"] as num?)?.toDouble() ??
              (i["unit_price"] as num?)?.toDouble() ??
              0.0,
          discount: itemDiscount,
          autoDiscount: posAuto,
          comboDiscount: combo,
          multipackDiscount: multipack,
          mixmatchDiscount: mixmatch,
          discountType: dType,
          isEbtEligible: ebtFlag,
          sku: i["sku"]?.toString(),
          itemType: i["item_type"]?.toString() ?? i["type"]?.toString(),
          image: i["product_image"]?.toString() ??
              i["image"]?.toString() ??
              i["item_image"]?.toString(),
        );
      }).toList();

      final cartState = CartState(
        sessionId: 'ORDER-$orderId',
        sequence: 0, // service overwrites with real sequence
        screen: screen,
        items: mqttItems,
        tax: tax,
        message: message,
        orderId: orderId,
        orderDiscount: orderDiscount,
        merchantDiscount: merchantDiscount,
        netPayable: netPayable,
        subtotalOverride: grossTotal,
        totalItems: mqttItems.fold(0, (s, item) => s + item.qty),
        summaryEnabled: screen == 'PAYMENT',
        storeId: storeId,
        storeName: storeName,
        storeLogoUrl: storeLogoUrl,
        storeBaseUrl: storeBaseUrl,
        slideshowUrls: slideshowUrls ?? const [],
      );

      await messaging.publishState(cartState);
      print(
          "✅ [MQTT] Published $screen with ${mqttItems.length} items (discounts & EBT included)");
    } catch (e) {
      print("❌ [MQTT] Publish failed (non-fatal): $e");
    }
  }

  /// Publish simple screen state (IDLE / SUCCESS etc.)
  static Future<void> _publishMqttScreen(String screen,
      {String? message, double? total}) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final messaging =
          Provider.of<StoreMessagingService>(context, listen: false);

      await messaging.publishScreen(screen, message: message, total: total);
      print("✅ [MQTT] Published screen → $screen");
    } catch (e) {
      print("❌ [MQTT] Screen publish failed (non-fatal): $e");
    }
  }
}
