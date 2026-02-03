// repositories/order_repository.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as _apiHelper;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/customerdisplayhelper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Assets/asset_model.dart';
import '../../Models/Orders/apply_discount_model.dart';
import '../../Models/Orders/get_orders_model.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Orders/total_orders_count_model.dart';
import '../../Utilities/global_utility.dart';

class FastKeyImageModel {
  final int id;
  final String name;
  final String url;
  final String imageType;

  FastKeyImageModel({
    required this.id,
    required this.name,
    required this.url,
    required this.imageType,
  });

  factory FastKeyImageModel.fromJson(Map<String, dynamic> json) {
    return FastKeyImageModel(
      id: json["id"],
      name: json["name"],
      url: json["url"],
      imageType: json["image_type"],
    );
  }
}

class TaxModel {
  final int id;
  final String name;
  final double rate;
  final String taxClass;

  TaxModel({
    required this.id,
    required this.name,
    required this.rate,
    required this.taxClass,
  });

  factory TaxModel.fromJson(Map<String, dynamic> json) {
    return TaxModel(
      id: json['id'],
      name: json['name'],
      rate: (json['rate'] as num).toDouble(),
      taxClass: json['tax_class'],
    );
  }
}



class OrderRepository {  // Build #1.0.25 - added by naveen
  final APIHelper _helper = APIHelper();

  // 1. Create Order
  Future<CreateOrderResponseModel> createOrder() async {
    // 🔹 Get local user and device info
    int? shiftId = await UserDbHelper().getUserShiftId();
    if (shiftId == null) {
      throw Exception("Please start your shift before creating an order");
    }

    final deviceDetails = await GlobalUtility.getDeviceDetails();
    final deviceId = deviceDetails['device_id'] ?? 'unknown';
    final userData = await UserDbHelper().getUserData();
    final userId = userData?[AppDBConst.userId] as int;

    final metaData = [
      OrderMetaData(key: OrderMetaData.posDeviceId, value: deviceId),
      OrderMetaData(key: OrderMetaData.posPlacedBy, value: '$userId'),
      OrderMetaData(key: OrderMetaData.shiftId, value: shiftId.toString()),
      OrderMetaData(key: 'user_name', value: (userData?[AppDBConst.username] ?? "")),
      OrderMetaData(key: 'user_id', value: userId.toString()),
    ];


    final request = CreateOrderRequestModel(metaData: metaData);

    // ---------- OFFLINE MODE ONLY ----------
    final box = Hive.box('offlineOrders');

    // Generate a 4-digit order ID that increments each time
    int lastOrderId = box.get('lastOrderId', defaultValue: 1000);
    int newOrderId = lastOrderId + 1;
    box.put('lastOrderId', newOrderId);

    final localOrder = {
      'order_id': newOrderId,
      'request': request.toJson(),
      'created_at': DateTime.now().toIso8601String(),
      'synced': false,
      'products': [],
      'user_id': userId,
      'user_name': userData?[AppDBConst.username] ?? "",
      'shift_id': shiftId,
      'order_type': "offline Order",
      'status': "pending_offline",
      'created_via': "offline Order",
      'orderAgeRestricted': false,
      'custom_items': [],       // add to maintain compatibility
    };


    await box.put(newOrderId.toString(), localOrder);

    if (kDebugMode) {
      print("📦 Saved offline order: $localOrder");
    }

    // 🔹 Return local response for UI consistency
    return CreateOrderResponseModel(
      id: newOrderId,
      parentId: 0,
      status: "pending_offline",
      currency: "INR",
      discountTotal: "0",
      total: "0",
      metaData: metaData,
      lineItems: [],
      taxLines: [],
      shippingLines: [],
      feeLines: [],
      couponLines: [],
    );
  }
  Future<void> saveOfflineOrderTotals(int orderId) async {
    final box = Hive.box('offlineOrders');
    final raw = box.get(orderId.toString());

    if (raw == null) return;

    final order = Map<String, dynamic>.from(raw);

    // ------------------ Products ------------------
    final products = (order['products'] ?? []) as List;
    num gross = 0;

    for (final p in products) {
      final price = double.tryParse(p['price'].toString()) ?? 0.0;
      final qty = int.tryParse(p['quantity'].toString()) ?? 1;
      gross += price * qty;
    }

    // ------------------ Discounts ------------------
    num orderDiscount = (order['orderDiscount'] ?? 0.0) as num;
    num merchantDiscount = (order['merchantDiscount'] ?? 0.0) as num;

    // ------------------ Tax ------------------
    num orderTax = (order['order_tax'] ?? 0.0) as num;

    // ------------------ Totals ------------------
    num netTotal = gross - orderDiscount - merchantDiscount;
    num netPayable = netTotal + orderTax;

    // Save
    order['gross_total'] = gross;
    order['orderDiscount'] = orderDiscount;
    order['merchantDiscount'] = merchantDiscount;
    order['order_tax'] = orderTax;
    order['net_total'] = netTotal;
    order['net_payable'] = netPayable;

    await box.put(orderId.toString(), order);
    print("💾 (Helper) Saved totals into Hive for order $orderId");
  }

  Future<void> addProductToOfflineOrder({
    required int orderId,
    required Map<String, dynamic> product,
  }) async {
    final box = Hive.box('offlineOrders');
    final order = box.get(orderId.toString());

    if (order == null) {
      throw Exception("Offline order $orderId not found");
    }

    final List<Map<String, dynamic>> products = (order['products'] ?? [])
        .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
        .toList();

    final newProductId = product['product_id'] ?? -1;
    final newVariationId = product['variation_id'] ?? 0;

    final existingIndex = products.indexWhere((p) {
      final storedProductId = p['product_id'] ?? -1;
      final storedVariationId = p['variation_id'] ?? 0;

      // ✅ Only match if both product_id and variation_id match exactly
      return storedProductId == newProductId &&
          storedVariationId == newVariationId;
    });

    if (existingIndex != -1) {
      // 🧮 Increase quantity if exact match found
      final existing = products[existingIndex];
      final oldQty = (existing['quantity'] ?? 0).toInt();
      final newQty = oldQty + (product['quantity'] ?? 1);

      products[existingIndex] = {
        ...existing,
        'quantity': newQty,
      };

      if (kDebugMode) {
        print("🔁 Updated existing offline product: ${product['name']} (Qty: $oldQty → $newQty)");
      }
    } else {
      // 🆕 Add as new product
      products.add(Map<String, dynamic>.from(product));

      if (kDebugMode) {
        print("🆕 Added new offline product: ${product['name']} (ID: $newProductId / Var: $newVariationId)");
      }
    }

    await box.put(orderId.toString(), {
      ...order,
      'products': products,
    });

    if (kDebugMode) {
      print("📦 Offline order updated -> Total products: ${products.length}");
    }
  }


  double getCustomItemTax({
    required String taxClass,
    required double price,
    required int qty,
    required List<Tax> taxes,
    double? taxRate,
  }) {
    try {
      double rate = 0.0;

      if (taxRate != null && taxRate > 0) {
        rate = taxRate;
      } else {
        final selected = taxes.firstWhere(
              (t) => t.slug == taxClass,
          orElse: () => Tax(slug: "", name: ""),
        );

        if (selected.slug.isEmpty) {
          print("⚠ No tax class match → tax = 0.0");
          return 0.0;
        }

        final rateString =
        selected.slug.replaceAll(RegExp(r'[^0-9.]'), '');
        rate = double.tryParse(rateString) ?? 0.0;
      }

      final taxAmount = ((price * rate) / 100) * qty;

      print(
        "🔥 Custom Item Tax → price:$price qty:$qty rate:$rate tax:$taxAmount",
      );

      return taxAmount;
    } catch (e) {
      print("❌ ERROR in getCustomItemTax → $e");
      return 0.0;
    }
  }
  void printFullJson(String label, Object json) {
    final encoded = jsonEncode(json);
    const chunkSize = 800;

    for (int i = 0; i < encoded.length; i += chunkSize) {
      debugPrint(
        "🟢 [$label] ${encoded.substring(
          i,
          i + chunkSize > encoded.length ? encoded.length : i + chunkSize,
        )}",
      );
    }
  }




  Future<Map<String, dynamic>?> syncSingleOfflineOrder(
      Map<String, dynamic> offlineOrder) async {
    try {
      final dynamic wooOrderIdRaw = offlineOrder['wooOrderId'];
      final int? existingWooOrderId =
      wooOrderIdRaw != null ? int.tryParse(wooOrderIdRaw.toString()) : null;

      final bool isUpdate =
          existingWooOrderId != null && existingWooOrderId > 0;

      final String url = isUpdate
          ? "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$existingWooOrderId"
          : "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}";
// ---------------------------------------------------------
      // ⭐ BUILD PAYMENTS ARRAY
      // ---------------------------------------------------------
      final List paymentsRaw = offlineOrder['payments'] as List? ?? [];

      final List<Map<String, dynamic>> paymentsPayload = paymentsRaw.map((p) {
        final double remaining =
            double.tryParse(p['remainingBalance']?.toString() ?? '0') ?? 0.0;

        return {
          "local_id": p['local_id'] ?? p['id'],
          "method": p['paymentMethod'],
          "amount": double.tryParse(p['amount'].toString()) ?? 0.0,
          "remaining": remaining < 0 ? 0.0 : remaining,
          "status": p['status'] ?? 'pending',
          "created_at": p['createdAt'],
        };
      }).toList();

      // ✅ PRINT PAYMENTS CLEARLY
      debugPrint("\n💰 PAYMENTS ATTACHED (${paymentsPayload.length}):");
      for (final p in paymentsPayload) {
        debugPrint(
          " → LocalID:${p['local_id']} | "
              "Method:${p['method']} | "
              "Amount:\$${p['amount']} | "
              "Remaining:\$${p['remaining']} | "
              "Status:${p['status']}",
        );
      }

      final String clientOrderId =
          offlineOrder['id']?.toString() ??
              offlineOrder['order_id']?.toString() ??
              offlineOrder['local_order_id']?.toString() ??
              "";


      // ---------------------------------------------------------
      // ⭐ HANDLE PRODUCTS
      // ---------------------------------------------------------
      final productsRaw =
      (offlineOrder['items'] ??
          offlineOrder['products'] ??
          []) as List;

      final List<Map<String, dynamic>> lineItems = [];
      final List<Map<String, dynamic>> feeLines = [];

      // ---------------------------------------------------------
      // ⭐ HANDLE PRODUCTS (Woo items + Custom items)
      // ---------------------------------------------------------
      for (var raw in productsRaw) {
        final item = Map<String, dynamic>.from(raw);
        final discountMeta =
        Map<String, dynamic>.from(item['discount_meta'] ?? {});

        final double autoDiscount =
            double.tryParse(discountMeta['amount']?.toString() ?? '0') ?? 0.0;

        final String discountType = discountMeta['type']?.toString() ?? '';
        final String discountSource = discountMeta['source']?.toString() ?? '';
        final String ruleId = discountMeta['rule_id']?.toString() ?? '';

        // final double price =
        //     double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        // final double qty =
        //     double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
        // final double lineTotal = price * qty;

        // ✅ NORMALIZE ITEM FIELDS (POS + API)
        final String name =
            item['item_name'] ??
                item['name'] ??
                "Product";

        // 🔒 HARD BLOCK payout & cashback from products loop
        final String lowerName =
        (item['item_name'] ?? item['name'] ?? '').toString().toLowerCase();

        final String itemType =
            item['type']?.toString().toLowerCase() ?? '';

        if (lowerName == 'payout' ||
            lowerName == 'cashback' ||
            itemType == 'payout' ||
            itemType == 'cashback' ||
            item['is_payout'] == true ||
            item['is_cashback'] == true) {
          debugPrint("⏭ Skipping special item from products loop → $lowerName / $itemType");
          continue;
        }

        final double price =
            double.tryParse(
              item['item_price']?.toString() ??
                  item['price']?.toString() ??
                  '0',
            ) ?? 0.0;

        final int qty =
            int.tryParse(
              item['items_count']?.toString() ??
                  item['quantity']?.toString() ??
                  '1',
            ) ?? 1;

        final double subtotal = price * qty;
        final double total = subtotal - autoDiscount;



        final dynamic pidRaw =
            item['product_id'] ??
                item['id'] ??
                item['productId'] ??
                item['productID'] ??
                item['product-id'] ??
                item['meta']?['product_id'] ??
                item['data']?['id'];

        final int? pid =
        pidRaw == null ? null : int.tryParse(pidRaw.toString());
        if (pid == null || pid == 0) {
          final int qtyInt = qty.toInt();

          // 🔹 READ rate stored from UI
          final double taxRate =
              double.tryParse(
                  item['tax_rate']?.toString() ??
                      item['tax_Rate']?.toString() ??
                      '0'
              ) ?? 0.0;

          // ✅ READ TAX CLASS
          final String taxClass =
              item['tax_class']?.toString() ??
                  item['tax_Class']?.toString() ??
                  "";


          // 🔹 RECALCULATE tax HERE (new screen)
          final double taxAmount = getCustomItemTax(
            taxClass: taxClass,
            price: price,
            qty: qtyInt,
            taxes: [],
            taxRate: taxRate,
          );

          lineItems.add({
            "name": name,
            "quantity": qtyInt,
            "sku": item["sku"] ?? item["generated_sku"] ?? "",
            "price": price.toStringAsFixed(2),

            "tax_status": "taxable",
            "tax_class": taxClass,

            "subtotal": (price * qtyInt).toStringAsFixed(2),
            "total": (price * qtyInt).toStringAsFixed(2),

            // ✅ SEND TAX
            "subtotal_tax": taxAmount.toStringAsFixed(2),
            "total_tax": taxAmount.toStringAsFixed(2),

            "taxes": taxAmount > 0
                ? [
              {
                "rate_id": 0,
                "total": taxAmount.toStringAsFixed(2),
                "subtotal": taxAmount.toStringAsFixed(2),
              }
            ]
                : [],

            // ✅ SEND RATE
            "meta_data": [
              {
                "key": "_custom_tax_rate",
                "value": taxRate.toString(),
              }
            ],

            "type": "custom",
          });

          continue;
        }


        // ---------------------------------------------------------
        // ⭐ WooCommerce normal product
        // ---------------------------------------------------------
        lineItems.add({
          "product_id": pid,
          //"name": item['name'] ?? "",
          "quantity": qty,
          "subtotal": subtotal.toStringAsFixed(2),
          "total": total.toStringAsFixed(2),

          // Optional (Woo may override name, but fine to send)
          "name": name,

          "meta_data": [
            {
              "key": "_pos_auto_discount",
              "value": autoDiscount.toStringAsFixed(2),
            },
            {
              "key": "_pos_discount_type",
              "value": discountType,
            },
            {
              "key": "_pos_discount_source",
              "value": discountSource,
            },
            {
              "key": "_pos_discount_rule_id",
              "value": ruleId,
            },
          ],
        });

      }

      // ---------------------------------------------------------
      // ⭐ HANDLE PAYOUTS
      // ---------------------------------------------------------
      final payouts = (offlineOrder['payouts'] ?? []) as List? ?? [];
      for (final p in payouts) {
        final double amount =
            double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;

        final int? productId =
        int.tryParse(p['payout_product_id']?.toString() ?? "");

        if (productId != null && productId > 0) {
          lineItems.add({
            "product_id": productId,
            "name": p["product_name"] ?? "Payout",
            "quantity": 1,
            "subtotal": amount.toStringAsFixed(2),
            "total": amount.toStringAsFixed(2),
          });
        } else {
          feeLines.add({
            "name": p["product_name"] ?? "Payout",
            "tax_status": "none",
            "total": amount.toStringAsFixed(2),
          });
        }
      }

      // ---------------------------------------------------------
      // ⭐ HANDLE CASHBACK
      // ---------------------------------------------------------
      // ---------------------------------------------------------
// ⭐ HANDLE CASHBACK
// ---------------------------------------------------------
      final cashbacks = (offlineOrder['cashbacks'] ?? []) as List? ?? [];
      for (final c in cashbacks) {
        final double amount =
            double.tryParse(c['amount']?.toString() ?? '0') ?? 0.0;

        // Try multiple key names to be safe
        final dynamic cashbackPidRaw =
            c['cashback_product_id'] ??
                c['product_id'] ??
                c['id'] ??
                c['cashbackProductId'];

        final int? productId = cashbackPidRaw == null
            ? null
            : int.tryParse(cashbackPidRaw.toString());

        if (productId != null && productId > 0) {
          lineItems.add({
            "product_id": productId,
            "name": c["product_name"] ?? "Cashback",
            "quantity": 1,
            "subtotal": amount.toStringAsFixed(2),
            "total": amount.toStringAsFixed(2),
          });
          debugPrint("🟢 Added Cashback as product line → $productId");
        } else {
          feeLines.add({
            "name": c["product_name"] ?? "Cashback",
            "tax_status": "none",
            "total": amount.toStringAsFixed(2),
          });
          debugPrint("🟡 Cashback product_id missing → sending as fee line");
        }
      }

      // ---------------------------------------------------------
// ⭐ HANDLE MERCHANT DISCOUNT (AS LINE ITEM USING PRODUCT ID)
// ---------------------------------------------------------
      final dynamic discountRaw = offlineOrder['merchantDiscount'];
      double merchantDiscount =
          double.tryParse(discountRaw?.toString() ?? "0") ?? 0.0;

      final discountProductIds =
      (offlineOrder['merchantDiscountIds'] as List? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();

      if (merchantDiscount > 0 && discountProductIds.isNotEmpty) {
        final int discountPid = discountProductIds.first;   // ⭐ Woo Product ID (11827)

        lineItems.add({
          "product_id": discountPid,
          "name": "Discount",
          "quantity": 1,
          "subtotal": (-merchantDiscount).toStringAsFixed(2),
          "total": (-merchantDiscount).toStringAsFixed(2),
          "tax_status": "none",
          "type": "discount"
        });

        print("🟢 Added Merchant Discount Product → $discountPid");
      }


      // ---------------------------------------------------------
      // ⭐ FINAL TOTAL
      // ---------------------------------------------------------
      final totalAmount = lineItems.fold<double>(
        0.0,
            (sum, li) =>
        sum + (double.tryParse(li['total'].toString()) ?? 0.0),
      );

      // ---------------------------------------------------------
      // ⭐ Meta
      // ---------------------------------------------------------
      final shiftId = await UserDbHelper().getUserShiftId();
      final userData = await UserDbHelper().getUserData();
      final userId = userData?[AppDBConst.userId] ?? "admin";

      final List<Map<String, dynamic>> metaData = [
        {"key": "pos_device_id", "value": "b31b723b92047f4b"},
        {"key": "pos_placed_by", "value": "$userId"},
        {"key": "shift_id", "value": "$shiftId"},
        {"key": "pos_cash_paid", "value": totalAmount.toStringAsFixed(2)},
        {"key": "_pos_client_order_id", "value": clientOrderId},
      ];

      if (paymentsPayload.isNotEmpty) {
        metaData.add({
          "key": "_pos_payments",
          "value": paymentsPayload,
        });
      }
      if (isUpdate) {
        metaData.add({"key": "pos_order_tag", "value": "updated_from_pos"});
      }

      // ---------------------------------------------------------
      // ⭐ FINAL PAYLOAD
      // ---------------------------------------------------------
      final payload = {
        "payment_method": "cash",
        "payment_method_title": "POS-CASH",
        "set_paid": true,
        "status": "processing",
        "meta_data": metaData,
        "fee_lines": feeLines,
        "line_items": lineItems,
        "tax_lines": [],
      };

      printFullJson("SYNC Woo Payload", payload);


      final response = isUpdate
          ? await _helper.put(url, payload, true)
          : await _helper.post(url, payload, true);

      final decoded =
      (response is String) ? jsonDecode(response) : response;

      final String wooStatus =
      decoded is Map<String, dynamic>
          ? decoded['status']?.toString() ?? 'processing'
          : 'processing';

      debugPrint("🟣 Woo Status from sync response → $wooStatus");


      debugPrint(
        "🟦 [SYNC] Woo Response → ${jsonEncode(decoded)}",
        wrapWidth: 1024,
      );
      // if (decoded is Map<String, dynamic> && decoded['id'] != null) {
      //   final int serverOrderId =
      //       int.tryParse(decoded['id'].toString()) ?? 0;
      //
      //   // ---------------------------------------------------------
      //   // ⭐ ADD PAYMENT NOTES (VISIBLE IN WOO)
      //   // ---------------------------------------------------------
      //   for (final p in paymentsPayload) {
      //     await _helper.post(
      //       "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$serverOrderId/notes",
      //       {
      //         "note":
      //         "POS Payment | ${p['method']} | \$${p['amount']} | Status: ${p['status']}",
      //         "customer_note": false,
      //       },
      //       true,
      //     );
      //   }
      //
      //   // ---------------------------------------------------------
      //   // ⭐ RETURN RESULT
      //   // ---------------------------------------------------------
      //   return {
      //     "id": serverOrderId,
      //     "status": wooStatus,
      //     "payments": paymentsPayload
      //         .map((p) => {
      //       "local_id": p["local_id"],
      //       "server_id": serverOrderId,
      //     })
      //         .toList(),
      //   };
      // }
      // ---------------------------------------------------------
      // ⭐ Extract Cashback Fee (if backend adds it)
      // ---------------------------------------------------------
      double cashbackFee = 0.0;
      final wooFees = decoded["fee_lines"] as List? ?? [];
      for (final fee in wooFees) {
        final name = fee["name"]?.toString().toLowerCase() ?? "";
        if (name.contains("cashback fee")) {
          cashbackFee =
              double.tryParse(fee["total"]?.toString() ?? "0") ?? 0.0;
        }
      }


      if (decoded is Map<String, dynamic> && decoded['id'] != null) {
        final int serverOrderId =
            int.tryParse(decoded['id'].toString()) ?? 0;
        final double wooTax =
            double.tryParse(decoded['total_tax']?.toString() ?? "0") ??
                0.0;
        final double wooTotal =
            double.tryParse(decoded['total']?.toString() ?? "0") ?? 0.0;

        final box = Hive.box('offlineOrders');

        final localOrderId = offlineOrder['id']?.toString() ??
            offlineOrder['order_id']?.toString() ??
            serverOrderId.toString();

        offlineOrder['wooOrderId'] = serverOrderId;
        offlineOrder['wooTax'] = wooTax;
        offlineOrder['wooTotal'] = wooTotal;
        offlineOrder['wooStatus'] = wooStatus;

        await box.put(localOrderId, offlineOrder);
        await box.put(serverOrderId.toString(), {"map_to_local": localOrderId});

        CustomerDisplayHelper.updateCustomerDisplay(
            int.tryParse(localOrderId) ?? serverOrderId);
// ---------------------------------------------------------
// ⭐ Extract values from Woo meta (EBT + Discount)
// ---------------------------------------------------------
        double ebtTotal = 0.0;
        double discountAmount = 0.0;

        final List metaList = decoded["meta_data"] as List? ?? [];

        for (final meta in metaList) {
          final key = meta["key"]?.toString();

          if (key == "_pinaka_ebt_eligible_total") {
            ebtTotal = double.tryParse(meta["value"]?.toString() ?? "0") ?? 0.0;
          }

          if (key == "_discount_amount") {
            discountAmount = double.tryParse(meta["value"]?.toString() ?? "0") ?? 0.0;
          }
        }

        print("🔵 EBT extracted from Woo → $ebtTotal");
        print("🏷 Discount extracted from Woo → $discountAmount");


// ---------------------------------------------------------
// ⭐ Return all values including EBT
// ---------------------------------------------------------
        return {
          "id": serverOrderId,
          "status": wooStatus,
          "total": wooTotal,
          "cashback_fee": cashbackFee,

          "ebt_total": ebtTotal,       // ✅ ADD THIS
          "discount_amount": discountAmount,
          "line_items": decoded["line_items"],
        };

      }
    } catch (e, s) {
      print("❌ Failed to sync offline order: $e");
      print("Stack: $s");
    }
    return null;
  }
  // 2. Update Order Products
  Future<OrderModel> updateOrderProducts({required int orderId, required UpdateOrderRequestModel request,}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepositoryyyyyy - POST URL: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);
      } catch (e, s) {
        if (kDebugMode) print("Error parsing update order response: $e, Stack: $s");
        throw Exception("Failed to parse update order response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in update order PUT");
    }
  }

  Future<Map<String, List<FastKeyImageModel>>> getFastKeyImages() async {
    final String url = UrlMethodConstants.fastkeyimages;

    try {
      final raw = await _helper.get(url, true);
      final response = raw is String ? jsonDecode(raw) : raw;

      if (kDebugMode) {
        print("FastKey Images Response: $response");
      }

      final data = response["data"] as Map<String, dynamic>;
      Map<String, List<FastKeyImageModel>> result = {};

      data.forEach((key, value) {
        result[key] = (value as List)
            .map((json) => FastKeyImageModel.fromJson(json))
            .toList();
      });

      return result;
    } catch (e) {
      print("❌ Error fetching FastKey images: $e");
      return {};
    }
  }

  //Build #1.0.40: getOrders
  Future<OrdersListModel> getOrders({bool allStatuses = false, int pageNumber =1, int pageLimit = 30, String status = "", String orderType = "", String userId = ""}) async {
    //Build #1.0.54: added if allStatuses is true, include all statuses; otherwise, just "processing"
    final statusString = status != "" ? status : (allStatuses
        ? TextConstants.orderScreenStatus
        : TextConstants.processing);

    orderType = orderType != "" ? orderType : "";

    final userData = await UserDbHelper().getUserData();
    userId = "${userData?[AppDBConst.userId]}"; ///Added to filter user based processing orders as per requirement update on 7-Jul-25
    //"?page=1&per_page=10&search=&status="
    var getOrdersParameter = "?author=$userId&page=$pageNumber&per_page=$pageLimit&created_via=$orderType&search=&status=";
    // Encode for URL (spaces become '+', commas become '%2C')
    final encodedStatus = Uri.encodeQueryComponent(statusString);
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}"
        "$getOrdersParameter$encodedStatus";
    //"${UrlParameterConstants.getOrdersEndParameter}"; # Build 1.0.172 removed them so that when applied date filter, data is fetching properly.

    if (kDebugMode) {
      print("OrderRepository - GET URL: $url");
    }

    try {
      final response = await _helper.get(url, true);

      if (kDebugMode) {
        print("OrderRepository - Raw Response Type: ${response.runtimeType}");
        print("OrderRepository - Raw Response: ${response.toString()}");
      }

      // Handle case where response is already a List<dynamic>
      if (response is List<dynamic>) {
        return OrdersListModel.fromJson(response);
      }
      // Handle case where response might be a String that needs parsing
      else if (response is String) {
        final parsed = jsonDecode(response);
        if (parsed is List<dynamic>) {
          return OrdersListModel.fromJson(parsed);
        }
        throw Exception("Unexpected parsed response type: ${parsed.runtimeType}");
      }
      // Handle any other unexpected type
      else {
        throw Exception("Unexpected response type: ${response.runtimeType}");
      }
    } catch (e,s) {
      if (kDebugMode) {
        print("OrderRepository - Error in getOrders: $e");
        print("Stack trace: $s");
      }
      throw Exception("Failed to fetch orders: $e");
    }
  }

  // Build #1.0.118: Fetch Total Orders Count API Call for Orders Screen
  Future<TotalOrdersResponseModel> fetchTotalOrdersCount({bool allStatuses = false, int pageNumber =1, int pageLimit = 10, String status = "", String orderType = "", String userId = "", String startDate = "", String endDate = ""}) async {

    final statusString = status != "" ? status : (allStatuses
        ? TextConstants.orderScreenStatus
        : TextConstants.processing);

    orderType = orderType != "" ? orderType : "";

    var getOrdersParameter = "?author=$userId&page=$pageNumber&per_page=$pageLimit&created_via=$orderType&after=$startDate&before=$endDate&search=&status="; //Build #1.0.134: updated new parameters startDate, endDate
    // Encode for URL (spaces become '+', commas become '%2C')
    final encodedStatus = Uri.encodeQueryComponent(statusString);
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/${UrlMethodConstants.totalOrders}$getOrdersParameter$encodedStatus";
    //"${UrlParameterConstants.getOrdersEndParameter}"; # Build 1.0.172 removed them so that when applied date filter, data is fetching properly.

    if (kDebugMode) {
      print("OrderRepository - GET URL: $url");
    }

    try {
      final response = await _helper.get(url, true);

      if (kDebugMode) {
        print("OrderRepository - Raw Response Type: ${response.runtimeType}");
        print("OrderRepository - Raw Response: ${response.toString()}");
      }
      /// Build #1.0.149
      /// The issue was passing a `String` (raw JSON) to `TotalOrdersResponseModel.fromJson` instead of a `Map<String, dynamic>` due to improper response handling.
      /// Updated code ensuring the `String` response is decoded with `json.decode` before processing in `fetchTotalOrdersCount`.
      /// Ensure response is decoded if it's a String
      dynamic responseData;
      if (response is String) {
        try {
          responseData = json.decode(response);
          if (responseData is! Map<String, dynamic>) {
            throw Exception("Decoded response is not a Map<String, dynamic>: ${responseData.runtimeType}");
          }
        } catch (e, s) {
          if (kDebugMode) {
            print("OrderRepository - Error decoding response: $e, Stack: $s");
          }
          throw Exception("Failed to decode total orders response");
        }
      } else if (response is Map<String, dynamic>) {
        responseData = response;
      } else {
        throw Exception("Unexpected response type: ${response.runtimeType}");
      }

      return TotalOrdersResponseModel.fromJson(responseData);
    } catch (e, s) {
      if (kDebugMode) {
        print("OrderRepository - Error in fetchTotalOrders: $e, Stack: $s");
      }
      throw Exception("Failed to fetch total orders: $e");
    }
  }

  Future<OrderModel> getOrder({required String orderId}) async {

    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}$orderId";

    if (kDebugMode) {
      print("OrderRepository.getOrder - GET URL: $url");
    }

    try {
      final response = await _helper.get(url, true);

      if (kDebugMode) {
        print("OrderRepository - Raw Response Type: ${response.runtimeType}");
        print("OrderRepository - Raw Response: ${response.toString()}");
      }
      if (response is String) {
        return OrderModel.fromJson(jsonDecode(response));
      }
      // Handle any other unexpected type
      else {
        throw Exception("Unexpected response type: ${response.runtimeType}");
      }
    } catch (e,s) {
      if (kDebugMode) {
        print("OrderRepository - Error in getOrders: $e");
        print("Stack trace: $s");
      }
      throw Exception("Failed to fetch orders");
    }
  }


  Future<Map<String, dynamic>> syncOfflineDeletedOrders(
      List<Map<String, dynamic>> orders) async {

    final String url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.deleteofflineorders}";

    final List<Map<String, dynamic>> formattedOrders = [];

    for (final order in orders) {
      final List<Map<String, dynamic>> lineItems = [];
      final List<Map<String, dynamic>> feeLines = [];

      final products = (order["products"] ?? []) as List;

      final String clientOrderId =
      (order["order_id"] ??
          order["client_order_id"] ??
          order["local_order_id"] ??
          "").toString();

      if (clientOrderId.isEmpty) {
        throw Exception("❌ client_order_id is missing");
      }


      // ---------------------------------------------------------
      // ⭐ PRODUCTS (NORMAL + CUSTOM)
      // ---------------------------------------------------------
      for (final raw in products) {
        final item = Map<String, dynamic>.from(raw);

        final double price =
            double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        final double qty =
            double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
        final double total = price * qty;

        final dynamic pidRaw =
            item["product_id"] ??
                item["id"] ??
                item["productId"] ??
                item["productID"] ??
                item["meta"]?["product_id"];

        final int? pid =
        pidRaw == null ? null : int.tryParse(pidRaw.toString());

        if (pid == null || pid == 0) {
          // CUSTOM ITEM
          lineItems.add({
            "name": item["name"] ?? "Custom Item",
            "quantity": qty,
            "price": price.toStringAsFixed(2),
            "tax_status": "taxable",
            "type": "custom"
          });
          continue;
        }

        lineItems.add({
          "product_id": pid,
          "name": item["name"] ?? "",
          "quantity": qty,
          "subtotal": total.toStringAsFixed(2),
          "total": total.toStringAsFixed(2),
        });
      }

      // ---------------------------------------------------------
      // ⭐ PAYOUTS
      // ---------------------------------------------------------
      for (final p in (order["payouts"] ?? [])) {
        final double amount =
            double.tryParse(p["amount"]?.toString() ?? "0") ?? 0.0;
        final int? pid =
        int.tryParse(p["payout_product_id"]?.toString() ?? "");

        if (pid != null && pid > 0) {
          lineItems.add({
            "product_id": pid,
            "name": p["product_name"] ?? "Payout",
            "quantity": 1,
            "subtotal": amount.toStringAsFixed(2),
            "total": amount.toStringAsFixed(2),
          });
        } else {
          feeLines.add({
            "name": p["product_name"] ?? "Payout",
            "tax_status": "none",
            "total": amount.toStringAsFixed(2),
          });
        }
      }

      // ---------------------------------------------------------
      // ⭐ CASHBACKS (ALWAYS LINE ITEM IF PID EXISTS)
      // ---------------------------------------------------------
      for (final c in (order["cashbacks"] ?? [])) {
        final double amount =
            double.tryParse(c["amount"]?.toString() ?? "0") ?? 0.0;

        final dynamic pidRaw =
            c["cashback_product_id"] ??
                c["product_id"] ??
                c["id"] ??
                c["cashbackProductId"];

        final int? pid =
        pidRaw == null ? null : int.tryParse(pidRaw.toString());

        final String name = c["product_name"] ?? "Cashback";

        if (pid != null && pid > 0) {
          lineItems.add({
            "product_id": pid,
            "name": name,
            "quantity": 1,
            "subtotal": amount.toStringAsFixed(2),
            "total": amount.toStringAsFixed(2),
          });
        } else {
          feeLines.add({
            "name": name,
            "tax_status": "none",
            "total": amount.toStringAsFixed(2),
          });
        }
      }

      // ---------------------------------------------------------
      // ⭐ MERCHANT DISCOUNT
      // ---------------------------------------------------------
      final discount =
          double.tryParse(order["merchantDiscount"]?.toString() ?? "0") ?? 0.0;
      final ids = (order["merchantDiscountIds"] ?? []).cast<int>();

      if (discount > 0 && ids.isNotEmpty) {
        lineItems.add({
          "product_id": ids.first,
          "name": "Discount",
          "quantity": 1,
          "subtotal": (-discount).toStringAsFixed(2),
          "total": (-discount).toStringAsFixed(2),
          "tax_status": "none",
          "type": "discount"
        });
      }

      // ---------------------------------------------------------
      // ⭐ META + PAYMENT
      // ---------------------------------------------------------
      formattedOrders.add({
        "client_order_id": clientOrderId,
        "status": "canceled",
        "set_paid": false,
        "payment_method": "cash",
        "payment_method_title": "POS-CASH",
        "line_items": lineItems,
        "fee_lines": feeLines,
        "tax_lines": [],
        "meta_data": [
          {"key": "pos_device_id", "value": order["device_id"] ?? ""},
          {"key": "pos_placed_by", "value": order["user_name"] ?? ""},
          {"key": "shift_id", "value": order["shift_id"]?.toString() ?? ""},
          // {
          //   "key": "offline_woo_order_id",
          //   "value": order["woo_order_id"] ??
          //       order["wooOrderId"] ??
          //       ""
          // },
        ],
        "payment": {
          "method": "cash",
          "paid": false,
          "transaction_id": "deleted_${order["order_id"]}"
        }
      });
    }

    final body = {"orders": formattedOrders};

    debugPrint(
      "📤 DELETE SYNC PAYLOAD:\n${JsonEncoder.withIndent('  ').convert(body)}",
      wrapWidth: 9000,
    );

    try {
      final response =
      await _helper.post(url, body, true, validateMarchentUrl: true);

      final decoded = jsonDecode(response);
      final result = decoded["results"]?.first;

      final int? wooOrderId = result?["order_id"];

      return {
        "success": true,
        "wooOrderId": wooOrderId,
      };
    } catch (e) {
      print("❌ Delete Sync Error: $e");
      return {
        "success": false,
        "wooOrderId": null,
      };
    }
  }
  Future<List<TaxModel>> getAllTaxes() async {
    final String url = UrlMethodConstants.taxes;

    try {
      final raw = await _helper.get(url, true);
      final response = raw is String ? jsonDecode(raw) : raw;

      if (kDebugMode) {
        print("🧾 Tax API Response: $response");
      }

      if (response["success"] == true) {
        final List list = response["taxes"];
        return list.map((e) => TaxModel.fromJson(e)).toList();
      }

      return [];
    } catch (e) {
      print("❌ Error fetching taxes: $e");
      return [];
    }
  }

  Future<String> validateLoginPin(String pin) async {
    final String url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}token/validate-login-pin";

    if (kDebugMode) {
      print("OrderRepository - Validate PIN URL: $url");
      print("OrderRepository - PIN: $pin");
    }

    final response = await _helper.postForm(
      url,
      {
        "emp_login_pin": pin,
      },
      true,
      validateMarchentUrl: true,
    );

    return response;
  }

  Future<dynamic> redeemLoyaltyPoints({
    required int orderId,
    required String contact,
    required double redeemAmount,
    required int redeemPoints,
  }) async {
    final String url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.loyaltyRedeem}";

    final body = {
      "redeem_points": redeemPoints,
      "redeem_amount": redeemAmount,
      "contact": contact,
      "order_id": orderId
    };

    try {
      final response = await _helper.post(
        url,
        body,
        true,
        validateMarchentUrl: true,
      );

      return response;
    } catch (e) {
      throw Exception(_extractRedeemError(e));   // <----- ADD THIS
    }
  }
  String _extractRedeemError(dynamic e) {
    try {
      if (e is String) {
        return e;
      }

      if (e is Map<String, dynamic>) {
        if (e.containsKey("message")) return e["message"];
        if (e.containsKey("error")) return e["error"];
        if (e.containsKey("msg")) return e["msg"];
      }
    } catch (_) {}

    return "Unable to redeem loyalty points";
  }


  Future<dynamic> addLoyaltyPoints({
    required int orderId,
    required String contact,
  }) async {
    final String url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.loyaltyCreateCustomer}";

    final body = {
      "order_id": orderId.toString(),
      "contact": contact,
    };

    if (kDebugMode) {
      print("🔵 Add Loyalty Points URL: $url");
      print("🔵 Add Loyalty Points Body: $body");
    }

    final response = await _helper.post(
      url,
      body,
      true,
      validateMarchentUrl: true,
    );

    if (kDebugMode) {
      print("🔵 Add Loyalty Points Response: $response");
    }

    return response;
  }

  Future<dynamic> removeLoyaltyPoints({
    required int orderId,
    required String contact,
  }) async {
    final String url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.loyaltyRemove}";

    final body = {
      "order_id": orderId,
      "contact": contact,
    };

    final response = await _helper.post(
      url,
      body,
      true,
      validateMarchentUrl: true,
    );

    return response;
  }
  Future<List<Map<String, dynamic>>> fetchDiscountRules() async {
    final String url = UrlMethodConstants.discountRules;

    print("🌐 DISCOUNT API REQUEST");
    print("➡️ Relative URL: $url");

    final response = await _helper.get(url, true);

    print("🌐 DISCOUNT API RAW RESPONSE ↓↓↓");
    print(response);

    if (response is String) {
      final decoded = jsonDecode(response);

      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    }

    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }

    return [];
  }

  // 3. Apply Coupon to Order
  Future<OrderModel> applyCouponToOrder({required int orderId, required ApplyCouponRequestModel request,}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - POST URL: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);  //Build #1.0.92: Updated: using OrderModel rather than UpdateOrderResponseModel
      } catch (e) {
        if (kDebugMode) print("Error parsing apply coupon response: $e");
        throw Exception("Failed to parse apply coupon response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in apply coupon POST");
    }
  }

  Future<UpdateOrderResponseModel> deleteOrderItem({
    required int orderId,
    required UpdateOrderRequestModel request,
  }) async {
    final box = Hive.box('offlineOrders');
    final order = box.get(orderId.toString());

    if (order == null) {
      throw Exception("Offline order $orderId not found for deletion");
    }

    // Convert product list to mutable list of maps
    List<Map<String, dynamic>> products = (order['products'] ?? [])
        .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
        .toList();

    final deleteList = request.lineItems ?? [];

    if (deleteList.isEmpty) {
      if (kDebugMode) print("⚠️ deleteOrderItem called with empty lineItems.");
      return UpdateOrderResponseModel(
        id: orderId,
        status: "pending_offline",
        parentId: 0,
        currency: "INR",
        discountTotal: "0",
        total: "0",
        totalTax: "0",
        metaData: [],
        lineItems: [],
        taxLines: [],
        shippingLines: [],
        feeLines: [],
        couponLines: [],
      );
    }

    int initialCount = products.length;

    for (var deleteItem in deleteList) {
      final deleteProductId = deleteItem.productId ?? -1;
      final deleteVariationId = deleteItem.variationId ?? 0;

      products.removeWhere((p) {
        final storedProductId = p['product_id'] ?? -1;
        final storedVariationId = p['variation_id'] ?? 0;
        return storedProductId == deleteProductId &&
            storedVariationId == deleteVariationId;
      });
    }

    await box.put(orderId.toString(), {
      ...order,
      'products': products,
      'synced': false, // Mark as needing sync later
    });

    if (kDebugMode) {
      print("🗑️ Offline delete for order #$orderId");
      print("   Items before: $initialCount → after: ${products.length}");
    }

    // ✅ Return consistent model for UI
    return UpdateOrderResponseModel(
      id: orderId,
      parentId: 0,
      status: "pending_offline",
      currency: "INR",
      discountTotal: "0",
      total: "0",
      totalTax: "0",
      metaData: [],
      lineItems: [],
      taxLines: [],
      shippingLines: [],
      feeLines: [],
      couponLines: [],
    );
  }



  // Build #1.0.49: Added changeOrderStatus api call code
  Future<UpdateOrderResponseModel> changeOrderStatus({
    required int orderId,
    required OrderStatusRequest request,
  }) async {
    final box = Hive.box('offlineOrders');
    final order = box.get(orderId.toString());

    if (order == null) {
      throw Exception("Offline order $orderId not found for status update");
    }

    final newStatus = request.status ?? 'unknown_status';

    // ✅ Update local Hive record
    await box.put(orderId.toString(), {
      ...order,
      'status': newStatus,
      'synced': false, // Mark to sync later
      'updated_at': DateTime.now().toIso8601String(),
    });

    if (kDebugMode) {
      print("🔄 Offline order #$orderId status changed → $newStatus");
    }

    // ✅ Return a consistent response for UI
    return UpdateOrderResponseModel(
      id: orderId,
      parentId: 0,
      status: newStatus,
      currency: "INR",
      discountTotal: "0",
      total: "0",
      totalTax: "0",
      metaData: [],
      lineItems: [],
      taxLines: [],
      shippingLines: [],
      feeLines: [],
      couponLines: [],
    );
  }

  // Build #1.0.49: Added applyDiscount api call code
  Future<ApplyDiscountResponse> applyDiscount(int orderId, String discountCode) async {
    String url = "${UrlHelper.baseUrl}${UrlParameterConstants.applyDiscount}$orderId";

    if (kDebugMode) {
      print("ProductRepository - ApplyDiscount URL: $url");
    }

    final body = {
      'discount_code': discountCode,
    };

    final response = await _helper.post(url, body, true);

    if (kDebugMode) {
      print("ProductRepository - ApplyDiscount Raw Response: $response");
    }

    if (response is String) {
      try {
        final Map<String, dynamic> responseData = json.decode(response);
        return ApplyDiscountResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) {
          print("ProductRepository - Error parsing apply discount response: $e");
        }
        throw Exception("Failed to parse apply discount response");
      }
    } else if (response is Map<String, dynamic>) {
      return ApplyDiscountResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type");
    }
  }

  // Build #1.0.274 : Added new function for add merchant discount
  Future<OrderModel> addMerchantDiscount({required int orderId, required AddMerchantDiscountRequestModel request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}${EndUrlConstants.addDiscountEndUrl}";

    if (kDebugMode) {
      print("OrderRepository - POST URL for add merchant discount: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Add Merchant Discount Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing add merchant discount response: $e");
        throw Exception("Failed to parse add merchant discount response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in add merchant discount POST");
    }
  }

  // Build #1.0.53 : Add Payout to Order
  @Deprecated("This API is deprecated, please use 'addPayoutAsProduct'")
  Future<OrderModel> addPayout({required int orderId, required AddPayoutRequestModel request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - POST URL for add payout: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Add Payout Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing add payout response: $e");
        throw Exception("Failed to parse add payout response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in add payout POST");
    }
  }
// Build #1.0.199 : Add Payout as Product (Hive-Only Permanent Offline)
  Future<OrderModel> addPayoutAsProduct({
    required int orderId,
    required AddPayoutAsProductRequestModel request,
  }) async {
    try {
      final box = Hive.box('offlineOrders');
      final key = orderId.toString();

      // 🟡 Fetch existing offline order
      final existingOrder = box.get(key);
      if (existingOrder == null) {
        throw Exception("Offline order not found for ID $orderId");
      }

      // 🧾 Create payout entry (stored as negative amount for clarity)
      final payoutEntry = {
        "order_id": orderId,
        "amount": request.amount,
        "type": "payout",
        "timestamp": DateTime.now().toIso8601String(),
      };

      // 🧩 Update existing order map
      final updatedOrder = Map<String, dynamic>.from(existingOrder);
      final payouts = List<Map<String, dynamic>>.from(updatedOrder["payouts"] ?? []);
      payouts.add(payoutEntry);
      updatedOrder["payouts"] = payouts;

      // 🔄 Recalculate totals
      double productsTotal = 0.0;
      for (var item in (updatedOrder["products"] ?? [])) {
        final price = (item["price"] ?? 0).toDouble();
        final qty = (item["quantity"] ?? 1).toDouble();
        productsTotal += price * qty;
      }

      double payoutsTotal = payouts.fold(0.0, (sum, p) => sum + (p["amount"] ?? 0.0));
      updatedOrder["gross_total"] = productsTotal + payoutsTotal;

      // 💾 Save updated order back to Hive
      await box.put(key, updatedOrder);

      if (kDebugMode) {
        print("✅ [Hive] Payout added to offline order #$orderId");
        print("🧾 Payout Entry → $payoutEntry");
        print("🧾 Updated Gross Total: ${updatedOrder["gross_total"]}");
      }

      // Return updated order model
      return OrderModel.fromJson(updatedOrder);
    } catch (e, s) {
      print("❌ [Hive] Failed to add payout offline: $e");
      print(s);
      rethrow;
    }
  }


  // Build #1.0.53 : Remove Payout from Order
  Future<OrderModel> removeFeeLine({required int orderId, required RemoveFeeLinesRequestModel request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - PUT URL for remove fee line: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.put(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Remove FeeLine Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing remove FeeLine response: $e");
        throw Exception("Failed to parse remove FeeLine response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in remove FeeLine PUT");
    }
  }

  // Build #1.0.64: removeCoupon API call
  Future<OrderModel> removeCoupon({required int orderId, required RemoveCouponRequestModel request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - PUT URL for remove coupon: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Remove Coupon Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return OrderModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing remove coupon response: $e");
        throw Exception("Failed to parse remove coupon response");
      }
    } else if (response is Map<String, dynamic>) {
      return OrderModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in remove coupon PUT");
    }
  }
}