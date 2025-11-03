import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:pinaka_pos/Blocs/Orders/order_bloc.dart';
import 'package:pinaka_pos/Database/user_db_helper.dart';
import 'package:pinaka_pos/Models/Orders/orders_model.dart';
import 'package:pinaka_pos/Repositories/Orders/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../Constants/text.dart';
import '../Helper/api_response.dart';
import '../Models/Orders/get_orders_model.dart' as model;
import 'db_helper.dart';

// Build #1.0.64: Add ItemType enum
enum ItemType {
  customProduct(TextConstants.customItem),
  coupon(TextConstants.couponText),
  payout(TextConstants.payoutText), //Build #1.0.68
  product(TextConstants.productText);

  final String value;
  const ItemType(this.value);
}

class OrderHelper { // Build #1.0.10 - Naveen: Added Order Helper to Maintain Order data
  static final OrderHelper _instance = OrderHelper._internal(); // Singleton instance to ensure only one instance of OrderHelper exists
  factory OrderHelper() => _instance;
  static bool isOrderPanelLoaded = false;

  int? activeOrderId; // Stores the currently active order ID
  int? activeUserId; // Stores the active user ID
  int? selectedOrderId; // Build #1.0.248 : save & persists across rebuilds of theme selection change
  int? cancelledOrderId; // Build #1.0.189: Stores the cancelled order ID
  List<int> orderIds = []; // List of order IDs for the active user
  List<Map<String, dynamic>> orders = [];
  /// Build 1.0.171: Concurrency Control: _syncFuture ensures only one sync operation runs at a time by checking if a sync is in progress; if so, it waits for completion, preventing data corruption or race conditions.
  /// Reliable Sync Process: Using a Completer, _syncFuture manages the sync, clears and updates the database with API orders, handles errors, and resets to allow new syncs, maintaining data consistency.
  static Future<void>? _syncFuture;

  OrderHelper._internal() {
    if (kDebugMode) {
      print("#### OrderHelper initialized!");
    }
    loadData(); // Load existing order data on initialization
  }

  // Loads processing order data from the local database and shared preferences
  Future<void> loadProcessingData() async {
    final prefs = await SharedPreferences.getInstance();
    activeOrderId = prefs.getInt('activeOrderId'); // Retrieve the saved active order ID
    activeUserId = await getUserIdFromDB();
    // Debugging logs
    if (kDebugMode) {
      print("#### Order Panel DB helper loadData: before activeOrderId = $activeOrderId, activeUserId= $activeUserId ");
      print("#### DEBUG orders: $orders");  // Build #1.0.189
      print("#### DEBUG orders length >>>>> : ${orders.length}");
      print("#### DEBUG orderIds >>>>> : $orderIds");
    }
    // Fetch the user's orders from the database
    final db = await DBHelper.instance.database;
    orders = await db.query(
      AppDBConst.orderTable,
      where: '${AppDBConst.userId} = ? AND ${AppDBConst.orderStatus} = ?',
      whereArgs: [activeUserId ?? 1, 'processing'],
      /// Build #1.0.161
      /// If required "asc" orders list, un-comment this line (order id's order low to high)
      /// Build #1.0.251 : FIXED - We have to use orderServerId rather than orderDate, it is already latest based on backend
      orderBy: '${AppDBConst.orderServerId} ASC', // Ensure orders are sorted by creation date
    );

    if (orders.isNotEmpty) {
      // Convert order list from DB into a list of order IDs
      orderIds = orders.map((order) => order[AppDBConst.orderServerId] as int).toList();
      // If activeOrderId is null or invalid, set it to the last available order ID
      if (activeOrderId == null || !orderIds.contains(activeOrderId)) {
        activeOrderId = orders.last[AppDBConst.orderServerId];///changed to order server id
        await prefs.setInt('activeOrderId', activeOrderId!);
      }
    } else {
      // No orders found, reset values
      activeOrderId = null;
      orderIds = [];
      orders = [];
    }

    // Debugging logs
    if (kDebugMode) {
      print("#### Order Panel DB helper loadData: activeOrderId = $activeOrderId");
      print("#### Order Panel DB helper loadData: orderIds = $orderIds, activeUserId: $activeUserId");
    }
  }
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    activeOrderId = prefs.getInt('activeOrderId');
    activeUserId = await getUserIdFromDB();

    orderIds = [];
    orders = [];

    // Always offline
    if (kDebugMode) print("📴 Loading offline orders from Hive");

    final box = Hive.box('offlineOrders');
    final allOfflineOrders = box.toMap();

    final validEntries = allOfflineOrders.entries
        .where((entry) => entry.value is Map)
        .map((entry) {
      // ✅ Normalize the root map
      final normalized = Map<String, dynamic>.from(entry.value as Map);

      // ✅ Normalize nested 'products' list if present
      if (normalized['products'] is List) {
        final rawProducts = normalized['products'] as List;
        normalized['products'] = rawProducts
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      } else {
        normalized['products'] = <Map<String, dynamic>>[];
      }

      // ✅ Normalize nested 'request' if present
      if (normalized['request'] is Map) {
        normalized['request'] =
        Map<String, dynamic>.from(normalized['request'] as Map);
      }

      // ✅ Normalize nested 'customer' if present
      if (normalized['customer'] is Map) {
        normalized['customer'] =
        Map<String, dynamic>.from(normalized['customer'] as Map);
      }

      // ✅ Normalize 'totals' or other nested objects if exist
      if (normalized['totals'] is Map) {
        normalized['totals'] =
        Map<String, dynamic>.from(normalized['totals'] as Map);
      }

      return MapEntry(entry.key, normalized);
    })
        .toList();

    if (validEntries.isNotEmpty) {
      orders = validEntries.map((e) => e.value).toList();

      // ✅ Extract order IDs safely
      orderIds = validEntries.map((e) {
        final map = e.value;
        if (map.containsKey('order_id')) return map['order_id'] as int?;
        if (map.containsKey('id')) return map['id'] as int?;
        return int.tryParse(e.key.toString());
      }).whereType<int>().toList();

      // ✅ Set active order ID if not found
      if (activeOrderId == null || !orderIds.contains(activeOrderId)) {
        activeOrderId = orderIds.isNotEmpty ? orderIds.last : null;
        if (activeOrderId != null) {
          await prefs.setInt('activeOrderId', activeOrderId!);
        }
      }
    } else {
      if (kDebugMode) print("⚠️ No valid offline order maps found in Hive");
      activeOrderId = null;
      orderIds = [];
      orders = [];
    }

    if (kDebugMode) {
      print("#### Offline Orders Loaded ####");
      print("Active Order ID: $activeOrderId");
      print("Order IDs: $orderIds");
      print("Total Orders Loaded: ${orders.length}");
    }
  }


  Future<int> getUserIdFromDB() async {
    var userId = 0;
    try {
      final userData = await UserDbHelper().getUserData();

      if (userData != null && userData[AppDBConst.userId] != null) {
        userId = userData[AppDBConst.userId] as int;
      }
    } catch (e) {
      if (kDebugMode) {
        print("OrderPanelDBHelper: Exception in getUserFromDB: $e");
      }
    }
    return userId;
  }


  // Update an orderID from API
  Future<void> updateServerOrderIDInDB(int orderServerId) async {
    ///Call to Create order REST API here, it should be done on add order at UI
    // OrderBloc orderBloc = OrderBloc(OrderRepository());
    // ///Create metadata for the order
    // OrderMetaData device = OrderMetaData(key: OrderMetaData.posDeviceId, value: "b31b723b92047f4b"); /// need to add code for device id later
    // OrderMetaData placedBy = OrderMetaData(key: OrderMetaData.posPlacedBy, value: '$activeUserId');
    // List<OrderMetaData> metaData = [device,placedBy];
    // ///call create order API
    // await orderBloc.createOrder(metaData).whenComplete(() async {
    //   if (kDebugMode) {
    //     print('createOrderStream completed');
    //   }
    // });

    // await orderBloc.createOrderStream.listen((event) async {
    //   if (kDebugMode) {
    //     print('createOrderStream status: ${event.status}');
    //   }
    //   if (event.status == Status.ERROR) {
    //     if (kDebugMode) {
    //       print(
    //           'OrderPanelDBHelper createOrder: completed with ERROR');
    //     }
    //     orderBloc.createOrderSink.add(APIResponse.error(TextConstants.retryText));
    //     orderBloc.dispose();
    //   } else if (event.status == Status.COMPLETED) {
    //     final order = event.data!;
    //     orderServerId = order.id;
    //     orderStatus = order.status;
    //     if (kDebugMode) {
    //       print('>>>>>>>>>>> OrderPanelDBHelper Order created with id: $orderServerId');
    //     }
    //   }
    // });

    ///check if 'orderServerId' is 0 or not, if yes show alert
    final db = await DBHelper.instance.database;
    await db.update(
      AppDBConst.orderTable,
      {
        AppDBConst.orderId: orderServerId, // Update order_id to API id
        AppDBConst.orderServerId: orderServerId,
        AppDBConst.orderDate: DateTime.now().toString(),
        AppDBConst.orderTime: DateTime.now().toString(),
      },
      where: '${AppDBConst.orderId} = ?',
      whereArgs: [activeOrderId],
    );

    // Update activeOrderId to the new server ID
    activeOrderId = orderServerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeOrderId', activeOrderId!);

    if (kDebugMode) {
      print("#### Order updated with ID: Active DBOrder ID $activeOrderId, serverOrderID $orderServerId, orderDate: ${DateTime.now().toString()}");
    }
  }

  //Build #1.0.40: syncOrdersFromApi
  Future<void> syncOrdersFromApi(List<model.OrderModel> apiOrders) async {
    // Build 1.0.171: Check if a sync operation is already in progress
    if (_syncFuture != null) {
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Sync already in progress, waiting for completion");
      }
      await _syncFuture; // Wait for the existing sync to complete
      return;
    }

    // Create a Completer to manage the sync operation's future
    final completer = Completer<void>();
    _syncFuture = completer.future;
    if (kDebugMode) {
      print("#### DEBUG: syncOrdersFromApi - Starting new sync operation");
    }

    try {
      final db = await DBHelper.instance.database;
      activeUserId = await getUserIdFromDB(); // Build #1.0.165: to load user before update order table, to filter user based processing order only
      // Build #1.0.80: Count orders in the database
      final dbOrdersCount = await db.query(AppDBConst.orderTable);
      final apiOrdersCount = apiOrders.length;

      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - API orders count: $apiOrdersCount, DB orders count: ${dbOrdersCount.length}, activeUserId :${activeUserId ?? 1}");
      }

      // Check if counts match
      //Build #1.0.165: delete db every time because of user filter logic applied for order table
      // if (dbOrdersCount.length != apiOrdersCount) {
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Counts do not match, deleting DB orders");
      }
      // Build #1.0.80: Delete all orders in the database
      // await db.delete(AppDBConst.orderTable);
      /// Build #1.0.207: Fixed -> No popup warning for open orders when closing shift via Vendor Payouts [SCRUM- 360]
      /// When ever navigating to orderPanel to orderScreenPanel related screen's, deleting all orders
      /// If we go to order screen - prev all processing orders will remove that the cause of checking processing orders while closing shift
      if (apiOrders.isNotEmpty) {
        // Check if we're syncing processing orders
        final isSyncingProcessingOrders = apiOrders.any((order) => order.status == 'processing');
        if (kDebugMode) {
          print("#### DEBUG: isSyncingProcessingOrders $isSyncingProcessingOrders");
        }
        if (isSyncingProcessingOrders) {
          // If syncing processing orders, only delete processing orders
          // when ever orderPanel calls like - fastKey/categories/add screens prev processing orders will remove and re-adding below
          await db.delete(
            AppDBConst.orderTable,
            where: '${AppDBConst.userId} = ? AND ${AppDBConst.orderStatus} = ?',
            whereArgs: [activeUserId ?? 1, 'processing'],
          );
        } else {
          // If syncing non-processing orders, only delete non-processing orders
          // when ever orderScreenPanel calls like - order screen prev non-processing orders will remove and re-adding below
          await db.delete(
            AppDBConst.orderTable,
            where: '${AppDBConst.userId} = ? AND ${AppDBConst.orderStatus} != ?',
            whereArgs: [activeUserId ?? 1, 'processing'],
          );
        }
      } else {
        ///  BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-360]: No popup warning for open orders when closing shift via Vendor Payouts
        // DON'T delete all orders when apiOrders is empty
        // Just skip the deletion and proceed with sync (which will do nothing)
        if (kDebugMode) {
          print("#### DEBUG: syncOrdersFromApi - No orders to sync, skipping deletion");
        }
        // await db.delete(AppDBConst.orderTable); // NO NEED TO DELETE COMPLETE ORDER TABLE
      }
      //  delete purchasedItemsTable related data
      /// Build #1.0.226: purchasedItemsTable foreign key has ON DELETE CASCADE which means when a parent order is deleted, all child purchased items are automatically deleted
      // await db.delete(AppDBConst.purchasedItemsTable); // NO NEED HERE
      OrderHelper.isOrderPanelLoaded = false;/// set 'false' to load 'processing' orders in order panel again, if db is empty by orders screen loading.
      // }
      // if(!isProcessing) {
      //   if (kDebugMode) {
      //     print("#### DEBUG: syncOrdersFromApi - Counts do not match, deleting DB orders");
      //   }
      //   // Build #1.0.80: Delete all orders in the database
      //   await db.delete(AppDBConst.orderTable, where: '${AppDBConst.orderStatus} != ?', whereArgs: ['processing']);
      //   //  delete purchasedItemsTable related data
      //   await db.delete(AppDBConst.purchasedItemsTable, where: '${AppDBConst.orderStatus} != ?', whereArgs: ['processing']);
      // }
      // Proceed with syncing only if counts match or after clearing DB
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Processing ${apiOrders.length} orders");
      }

      for (var apiOrder in apiOrders) {
        if (kDebugMode) {
          print("#### DEBUG: syncOrdersFromApi - Processing order serverId: ${apiOrder.id}");
        }
        // Check if order exists in DB by API id
        final existingOrders = await db.query(
          AppDBConst.orderTable,
          where: '${AppDBConst.orderServerId} = ?', //Build #1.0.78
          whereArgs: [apiOrder.id],
        );

        if (kDebugMode) {
          print("#### DEBUG: syncOrdersFromApi - existingOrders: ${existingOrders.length}");
        }

        if (existingOrders.isNotEmpty) {
          await db.update(
            AppDBConst.orderTable,
            {
              AppDBConst.orderServerId: apiOrder.id,
              AppDBConst.orderTotal: double.tryParse(apiOrder.total) ?? 0.0,
              AppDBConst.orderStatus: apiOrder.status,
              AppDBConst.orderDate: apiOrder.dateCreated,
              AppDBConst.orderTime: apiOrder.dateCreated,
              AppDBConst.orderPaymentMethod: apiOrder.paymentMethod,
              AppDBConst.orderDiscount: double.tryParse(apiOrder.discountTotal) ?? 0.0, // Store discount
              AppDBConst.orderTax: double.tryParse(apiOrder.totalTax) ?? 0.0, // Store tax
              AppDBConst.orderAgeRestricted: apiOrder.metaData.firstWhere( //Build #1.0.234: Saving Age Restricted value in order table
                    (meta) => meta.key == TextConstants.ageRestrictedKey,
                orElse: () => model.MetaData(id: 0, key: '', value: 'false'),
              ).value.toString(),
            },
            where: '${AppDBConst.orderServerId} = ?',
            whereArgs: [apiOrder.id],
          );
          if (kDebugMode) {
            print("#### DEBUG: syncOrdersFromApi Updated order with serverId: ${apiOrder.id}, orderTotal: ${apiOrder.total}");
          }
        } else {
          await db.insert(AppDBConst.orderTable, {
            // AppDBConst.orderId: apiOrder.id,
            AppDBConst.userId: activeUserId ?? 1,
            AppDBConst.orderServerId: apiOrder.id,
            AppDBConst.orderTotal: double.tryParse(apiOrder.total) ?? 0.0,
            AppDBConst.orderStatus: apiOrder.status,
            AppDBConst.orderType: apiOrder.createdVia ?? 'in-store',
            AppDBConst.orderDate: apiOrder.dateCreated,
            AppDBConst.orderTime: apiOrder.dateCreated,
            AppDBConst.orderPaymentMethod: apiOrder.paymentMethod,
            AppDBConst.orderDiscount: double.tryParse(apiOrder.discountTotal) ?? 0.0, // Store discount
            AppDBConst.orderTax: double.tryParse(apiOrder.totalTax) ?? 0.0, // Store tax
            AppDBConst.orderShipping: double.tryParse(apiOrder.shippingTotal) ?? 0.0, // Store shipping
            AppDBConst.orderAgeRestricted: apiOrder.metaData //Build #1.0.234: Saving Age Restricted value in order table
                .firstWhere((meta) => meta.key == TextConstants.ageRestrictedKey,
              orElse: () => model.MetaData(id: 0, key: '', value: 'false'),
            ).value.toString(),
          });
          if (kDebugMode) {
            print("#### DEBUG: syncOrdersFromApi Inserted new order with serverId: ${apiOrder.id}, orderTotal: ${apiOrder.total}");
          }
        }

        // Sync line items using API order id
        await updateOrderItems(apiOrder.id, apiOrder.lineItems);
        // await updateOrderPayoutItems(apiOrder.id, apiOrder.feeLines ?? []); // Build #1.0.64
        await updateOrderPayoutItem(apiOrder.id, apiOrder.lineItems); // Build #1.0.198
        // Build #1.0.207: Fixed Issue - Always Merchant discount showing "0"
        // Ex: updateOrderPayoutItem modified to lineItems but discount we are getting in fee lines only , we are not using this, that's why merchant discount calculation is 0.
        await updateOrderMerchantDiscount(apiOrder.id, apiOrder.lineItems ?? []); // Build #1.0.274 : updated fee lines to line items change
        await updateOrderCouponItems(apiOrder.id, apiOrder.couponLines ?? []);
      }

      if (kDebugMode) {
        // Calculate order total from items
        for (var order in apiOrders) {
          final items = await getOrderItems(order.id);
          for (var item in items) {
            print(
                "#### DEBUG: Check after insert if Order items ID: ${item[AppDBConst
                    .itemId]},  ${item[AppDBConst
                    .itemServerId]} for order ${order.id} is correct?, loadOrderItems 3");
          }
        }
        print("#### DEBUG: syncOrdersFromApi - Refreshing local data");
      }
      await loadData();
      // Complete the sync operation
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Sync completed successfully");
      }
      completer.complete();
    } catch (e) { // Build 1.0.171
      // Handle errors and propagate them
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Error occurred: $e");
      }
      completer.completeError(e);
      rethrow;
    } finally { // Build 1.0.171
      // Reset _syncFuture to allow new sync operations
      _syncFuture = null;
      if (kDebugMode) {
        print("#### DEBUG: syncOrdersFromApi - Sync future reset, ready for new sync");
      }
    }
  }

  //Build #1.0.40: update order items using item id
  Future<void> updateOrderItems(int orderId, List<model.LineItem> apiItems) async {
    if (kDebugMode) {
      print("#### DEBUG: updateOrderItems orderId: $orderId");
    }
    final db = await DBHelper.instance.database;
    final existingItems = await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ?',
      whereArgs: [orderId],
    );

    final existingItemsMap = {
      for (var item in existingItems) item[AppDBConst.itemServerId].toString(): item,
    };

    if (kDebugMode) {
      print("#### DEBUG: updateOrderItems - Processing ${apiItems.length} items for order $orderId, existing items: ${existingItemsMap.length}");
    }

    for (var apiItem in apiItems) { // Build #1.0.274 : updated : skip merchant discount adding into order
      if(apiItem.name.contains('Payout') || apiItem.name == TextConstants.discountText){  //Build #1.0.198: do not add payout item again, it is already added by separate function
        continue;
      }
      final itemId = apiItem.id.toString();
      final double itemPrice = apiItem.productData.regularPrice == '' ?  double.parse(apiItem.productData.price ?? '0.0') : double.parse(apiItem.productData.regularPrice ?? '0.0');
      final int itemQuantity = apiItem.quantity ?? 0;
      final double itemSumPrice = double.parse(apiItem.subtotal); //Build #1.0.134: updated item sum price using from api response

      if (kDebugMode) {
        print("         salesPrice: ${apiItem.productData.salePrice ?? "0.0"}, "
            "regularPrice:${apiItem.productData.regularPrice ?? "0.0"},"
            " unitPrice: ${apiItem.productData.price ?? "0.0"}");
      }

      final String variationName = apiItem.productVariationData?.metaData?.firstWhere((e) => e.key == "custom_name", orElse: () => model.MetaData(id: 0, key: "", value: "")).value ?? "";
      final int variationCount = apiItem.productData.variations?.length ?? 0;
      final String combo = apiItem.metaData.firstWhere((e) => e.value.contains('Combo'), orElse: () => model.MetaData(id: 0, key: "", value: "")).value.split(' ').first ?? "";
      ///Todo: check if these values should come from product data or product variation data or line item data
      // Build #1.0.118: Fix: Use double.tryParse to safely handle invalid or null values
      // final double salesPrice = double.tryParse(apiItem.productData.salePrice ?? "0.0") ?? 0.0;
      // final double regularPrice = double.tryParse(apiItem.productData.regularPrice ?? "0.0") ?? 0.0;
      // final double unitPrice = double.tryParse(apiItem.productData.price ?? "0.0") ?? 0.0;
      /// Build #1.0.168: Fixed Issue - Order Panel gross total seems incorrect again
      /// The issue is we are using productData values always not checking productVariationData if have those!
      final bool hasVariations = apiItem.productData.variations != null && apiItem.productData.variations!.isNotEmpty;
      final double salesPrice = hasVariations
          ? double.tryParse(apiItem.productVariationData?.salePrice?.isNotEmpty == true ? apiItem.productVariationData!.salePrice! : "0.0") ?? 0.0
          : double.tryParse(apiItem.productData.salePrice?.isNotEmpty == true ? apiItem.productData.salePrice! : "0.0") ?? 0.0;
      final double regularPrice = hasVariations
          ? double.tryParse(apiItem.productVariationData?.regularPrice?.isNotEmpty == true ? apiItem.productVariationData!.regularPrice! : "0.0") ?? 0.0
          : double.tryParse(apiItem.productData.regularPrice?.isNotEmpty == true ? apiItem.productData.regularPrice! : "0.0") ?? 0.0;
      final double unitPrice = hasVariations
          ? double.tryParse(apiItem.productVariationData?.price?.isNotEmpty == true ? apiItem.productVariationData!.price! : "0.0") ?? 0.0
          : double.tryParse(apiItem.productData.price?.isNotEmpty == true ? apiItem.productData.price! : "0.0") ?? 0.0;
      if (kDebugMode) {
        print("#### DEBUG: updateOrderItems - Processing API item ID: $itemId, name: ${apiItem.name}, price: $itemPrice, quantity: $itemQuantity, sumPrice: $itemSumPrice");
        print("variationName $variationName, variationCount:$variationCount, combo:$combo, salesPrice: $salesPrice, regularPrice: $regularPrice, unitPrice: $unitPrice");
      }

      if (existingItemsMap.containsKey(itemId)) {
        final existingItem = existingItemsMap[itemId]!;
        await db.update(
          AppDBConst.purchasedItemsTable,
          {
            AppDBConst.itemName: apiItem.name ?? 'Unknown Item',
            AppDBConst.itemPrice: itemPrice,
            AppDBConst.itemCount: itemQuantity,
            AppDBConst.itemSumPrice: itemSumPrice,
            AppDBConst.itemImage: apiItem.image.src ?? '',
            AppDBConst.itemSKU: apiItem.sku ?? '',
            AppDBConst.itemSalesPrice: salesPrice,
            AppDBConst.itemRegularPrice: regularPrice,
            AppDBConst.itemUnitPrice: unitPrice,
            AppDBConst.itemProductId: apiItem.productId, //Build #1.0.128: Update - missed to update productId & variationId
            AppDBConst.itemVariationId: apiItem.variationId,
            // AppDBConst.itemType: isCustomItem ? ItemType.customProduct.value :  ItemType.product.value,
          },
          where: '${AppDBConst.itemServerId} = ?',
          whereArgs: [existingItem[AppDBConst.itemServerId]], //Build #1.0.128: use itemServerId instead of itemId
        );
        if (kDebugMode) {
          print("#### DEBUG: Updated item ID: $itemId for order $orderId");
        }
        existingItemsMap.remove(itemId);
      } else {
        // Safe way to check if the item is a custom product
        bool isCustomItem = false;
        if (apiItem.productData != null &&
            apiItem.productData.tags != null &&
            apiItem.productData.tags.isNotEmpty) {
          isCustomItem = apiItem.productData.tags.any(
                  (tag) => tag.name == TextConstants.customItem
          );
        }
        await db.insert(AppDBConst.purchasedItemsTable, {
          AppDBConst.itemServerId: apiItem.id,
          AppDBConst.itemName: apiItem.name ?? 'Unknown Item',
          AppDBConst.itemSKU: apiItem.sku ?? '',
          AppDBConst.itemPrice: itemPrice,
          AppDBConst.itemImage: apiItem.image.src ?? '',
          AppDBConst.itemCount: itemQuantity,
          AppDBConst.itemSumPrice: itemSumPrice,
          AppDBConst.orderIdForeignKey: orderId,
          AppDBConst.itemType: isCustomItem ? ItemType.customProduct.value :  ItemType.product.value, //Build #1.0.128: Updated - missed to enum type
          AppDBConst.itemVariationCustomName: variationName,
          AppDBConst.itemVariationCount: variationCount,
          AppDBConst.itemCombo: combo,
          AppDBConst.itemSalesPrice: salesPrice,
          AppDBConst.itemRegularPrice: regularPrice, // Build #1.0.80: added
          AppDBConst.itemUnitPrice: unitPrice,
          AppDBConst.itemProductId: apiItem.productId, //Build #1.0.128: Updated - missed to add productId & variationId
          AppDBConst.itemVariationId: apiItem.variationId,
        });
        if (kDebugMode) {
          print("#### DEBUG: Inserted new item ID: $itemId for order $orderId");
        }
      }
    }

    for (var item in existingItemsMap.values) {
      await db.delete(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.itemServerId} = ?', //Build #1.0.128: Updated - itemId to itemServerId
        whereArgs: [item[AppDBConst.itemServerId]],
      );
      if (kDebugMode) {
        print("#### DEBUG: Deleted obsolete item ID: ${item[AppDBConst.itemServerId]} for order $orderId");
      }
    }

    // Calculate order total from items
    final items = await getOrderItems(orderId);
    for (var item in items) {
      if (kDebugMode) {
        print("#### DEBUG: Check after insert if Order items ID: ${item[AppDBConst.itemId]},  ${item[AppDBConst.itemServerId]} for order $orderId is correct?, loadOrderItems 2");
      }
    }

    // var orderTotal = items.fold(0.0, (sum, item) => sum + (item[AppDBConst.itemSumPrice] as num).toDouble());
    //
    // // Fetch discount and tax from the database (set by syncOrdersFromApi)
    // final order = await db.query(
    //   AppDBConst.orderTable,
    //   where: '${AppDBConst.orderServerId} = ?',
    //   whereArgs: [orderId],
    // );
    // double orderDiscount = 0.0;
    // double orderTax = 0.0;
    // if (order.isNotEmpty) {
    //   orderDiscount = order.first[AppDBConst.orderDiscount] as double? ?? 0.0;
    //   orderTax = order.first[AppDBConst.orderTax] as double? ?? 0.0;
    //   orderTotal = order.first[AppDBConst.orderTotal] as double? ?? 0.0;
    // }
    // orderTotal = orderTotal + orderTax;

    // Update order with total, discount, and tax
    // await db.update(
    //   AppDBConst.orderTable,
    //   {
    //     AppDBConst.orderTotal: orderTotal,
    //     AppDBConst.orderDiscount: orderDiscount,
    //     AppDBConst.orderTax: orderTax,
    //   },
    //   where: '${AppDBConst.orderServerId} = ?',
    //   whereArgs: [orderId],
    // );
    if (kDebugMode) {
      print("#### DEBUG: updateOrderItems for order id $orderId completed...");
      // print( "total: $orderTotal, discount: $orderDiscount, tax: $orderTax for order $orderId, items: $items");
    }
  }


  // Build #1.0.64 : Modified updateOrderPayoutItems to align with updateOrderItems
  @Deprecated("This API is deprecated and replaced by 'updateOrderPayoutItem' with line_item")
  Future<void> updateOrderPayoutItems(int orderId, List<model.FeeLine> feeLines) async {
    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems orderId: $orderId");
    }
    final db = await DBHelper.instance.database;
    final existingItems = await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemType} = ?',
      whereArgs: [orderId, ItemType.payout.value],
    );

    final existingItemsMap = {
      for (var item in existingItems) item[AppDBConst.itemServerId].toString(): item,
    };

    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems - Processing ${feeLines.length} payout items for order $orderId, existing items: ${existingItems.length}");
    }
    double merchantDiscount = 0.0;
    var merchantDiscountIds = "";
    for (var feeLine in feeLines) {
      final itemId = feeLine.id.toString();
      if (kDebugMode) {
        print("item id $itemId");
      }
      if (kDebugMode) {
        print("item price value === ${feeLine.total}");
      }
      final double itemPrice = double.parse(feeLine.total ?? '0.0');
      final int itemQuantity = 1;
      final double itemSumPrice = itemPrice;

      if (kDebugMode) {
        print("#### DEBUG: updateOrderPayoutItems - Processing payout item ID: $itemId, name: ${feeLine.name}, price: $itemPrice, quantity: $itemQuantity, sumPrice: $itemSumPrice");
      }

      if (feeLine.name == TextConstants.payout) {
        if (existingItemsMap.containsKey(itemId)) {
          final existingItem = existingItemsMap[itemId]!;
          await db.update(
            AppDBConst.purchasedItemsTable,
            {
              AppDBConst.itemName: feeLine.name ?? 'Payout',
              AppDBConst.itemPrice: itemPrice,
              AppDBConst.itemCount: itemQuantity,
              AppDBConst.itemSumPrice: itemSumPrice,
              AppDBConst.itemImage: 'assets/svg/payout.svg',
              AppDBConst.itemSKU: '',
            },
            where: '${AppDBConst.itemServerId} = ?',
            whereArgs: [existingItem[AppDBConst.itemServerId]],
          );
          if (kDebugMode) {
            print("#### DEBUG: Updated payout item ID: $itemId for order $orderId");
          }
          existingItemsMap.remove(itemId);
        } else {
          await db.insert(AppDBConst.purchasedItemsTable, {
            //   AppDBConst.itemId: orderId,
            AppDBConst.itemServerId: feeLine.id, //Build #1.0.67: updated
            AppDBConst.itemName: feeLine.name ?? 'Payout',
            AppDBConst.itemSKU: '',
            AppDBConst.itemPrice: itemPrice,
            AppDBConst.itemImage: 'assets/svg/payout.svg',
            AppDBConst.itemCount: itemQuantity,
            AppDBConst.itemSumPrice: itemSumPrice,
            AppDBConst.orderIdForeignKey: orderId,
            AppDBConst.itemType: ItemType.payout.value,
          });
          if (kDebugMode) {
            print("#### DEBUG: Inserted new payout item ID: $itemId for order $orderId");
          }
        }
      }
      if (feeLine.name == TextConstants.discountText) {
        merchantDiscount += itemPrice.abs();
        merchantDiscountIds = "$merchantDiscountIds,${feeLine.id}";
      }
    }
    await db.update(
      AppDBConst.orderTable,
      {
        AppDBConst.merchantDiscount: merchantDiscount,
        AppDBConst.merchantDiscountIds: merchantDiscountIds,
      },
      where: '${AppDBConst.orderServerId} = ?',
      whereArgs: [orderId],
    );
    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems - Processing merchantDiscount item IDs: $merchantDiscountIds, discountTotal: $merchantDiscount");
    }

    for (var item in existingItemsMap.values) {
      await db.delete(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.itemServerId} = ?',
        whereArgs: [item[AppDBConst.itemServerId]],
      );
      if (kDebugMode) {
        print("#### DEBUG: Deleted obsolete payout item ID: ${item[AppDBConst.itemServerId]} for order $orderId");
      }
    }
  }

  //  Build #1.0.198 : Modified updateOrderPayoutItem to align with new payout API changes
  Future<void> updateOrderPayoutItem(int orderId, List<model.LineItem> lineItems) async {
    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems orderId: $orderId");
    }
    final db = await DBHelper.instance.database;
    final existingItems = await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemType} = ?',
      whereArgs: [orderId, ItemType.payout.value],
    );

    final existingItemsMap = {
      for (var item in existingItems) item[AppDBConst.itemServerId].toString(): item,
    };

    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems - Processing ${lineItems.length} payout items for order $orderId, existing items: ${existingItems.length}");
    }
    double merchantDiscount = 0.0;
    var merchantDiscountIds = "";
    for (var lineItem in lineItems) {
      final itemId = lineItem.id.toString();
      if (kDebugMode) {
        print("item id $itemId");
      }
      if (kDebugMode) {
        print("item price value === ${lineItem.total}");
      }
      final double itemPrice = double.parse(lineItem.total ?? '0.0');
      final int itemQuantity = 1;
      final double itemSumPrice = itemPrice;

      if (kDebugMode) {
        print("#### DEBUG: updateOrderPayoutItems - Processing payout item ID: $itemId, name: ${lineItem.name}, price: $itemPrice, quantity: $itemQuantity, sumPrice: $itemSumPrice");
      }

      if (lineItem.name == TextConstants.payout) {
        if (existingItemsMap.containsKey(itemId)) {
          final existingItem = existingItemsMap[itemId]!;
          await db.update(
            AppDBConst.purchasedItemsTable,
            {
              AppDBConst.itemName: lineItem.name ?? 'Payout',
              AppDBConst.itemPrice: itemPrice,
              AppDBConst.itemCount: itemQuantity,
              AppDBConst.itemSumPrice: itemSumPrice,
              AppDBConst.itemImage: 'assets/svg/payout.svg',
              AppDBConst.itemSKU: '',
            },
            where: '${AppDBConst.itemServerId} = ?',
            whereArgs: [existingItem[AppDBConst.itemServerId]],
          );
          if (kDebugMode) {
            print("#### DEBUG: Updated payout item ID: $itemId for order $orderId");
          }
          existingItemsMap.remove(itemId);
        } else {
          await db.insert(AppDBConst.purchasedItemsTable, {
            //   AppDBConst.itemId: orderId,
            AppDBConst.itemServerId: lineItem.id, //Build #1.0.67: updated
            AppDBConst.itemName: lineItem.name ?? 'Payout',
            AppDBConst.itemSKU: '',
            AppDBConst.itemPrice: itemPrice,
            AppDBConst.itemImage: 'assets/svg/payout.svg',
            AppDBConst.itemCount: itemQuantity,
            AppDBConst.itemSumPrice: itemSumPrice,
            AppDBConst.orderIdForeignKey: orderId,
            AppDBConst.itemType: ItemType.payout.value,
          });
          if (kDebugMode) {
            print("#### DEBUG: Inserted new payout item ID: $itemId for order $orderId");
          }
        }
      }
      if (lineItem.name == TextConstants.discountText) {
        merchantDiscount += itemPrice.abs();
        merchantDiscountIds = "$merchantDiscountIds,${lineItem.id}";
      }
    }
    await db.update(
      AppDBConst.orderTable,
      {
        AppDBConst.merchantDiscount: merchantDiscount,
        AppDBConst.merchantDiscountIds: merchantDiscountIds,
      },
      where: '${AppDBConst.orderServerId} = ?',
      whereArgs: [orderId],
    );
    if (kDebugMode) {
      print("#### DEBUG: updateOrderPayoutItems - Processing merchantDiscount item IDs: $merchantDiscountIds, discountTotal: $merchantDiscount");
    }

    for (var item in existingItemsMap.values) {
      await db.delete(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.itemServerId} = ?',
        whereArgs: [item[AppDBConst.itemServerId]],
      );
      if (kDebugMode) {
        print("#### DEBUG: Deleted obsolete payout item ID: ${item[AppDBConst.itemServerId]} for order $orderId");
      }
    }
  }

  // Build #1.0.207: Fixed Issue - Always Merchant discount showing "0"
  // Ex: updateOrderPayoutItem modified to lineItems but discount we are getting in fee lines only , we are not using this, that's why merchant discount calculation is 0.
  // Added this function to handle merchant discounts from feeLines
  Future<void> updateOrderMerchantDiscount(int orderId, List<model.LineItem> lineItems) async { // Build #1.0.274 : updated fee lines to line items
    final db = await DBHelper.instance.database;
    double merchantDiscount = 0.0;
    // Use a list instead of string concatenation
    List<String> merchantDiscountIdsList = []; // Build #1.0.216: FIXED Issue - Merchant discount not deleting, showing error "Payout ID not found"

    for (var lineItem in lineItems) {
      if (lineItem.name == TextConstants.discountText) {
        merchantDiscount += double.parse(lineItem.total ?? '0.0').abs();
        merchantDiscountIdsList.add(lineItem.id.toString()); // Added to list
      }
    }
    // Build #1.0.216: Join with commas and ensure no leading comma
    String merchantDiscountIds = merchantDiscountIdsList.join(',');

    await db.update(
      AppDBConst.orderTable,
      {
        AppDBConst.merchantDiscount: merchantDiscount,
        AppDBConst.merchantDiscountIds: merchantDiscountIds,
      },
      where: '${AppDBConst.orderServerId} = ?',
      whereArgs: [orderId],
    );
  }

  // Build #1.0.64 : Modified updateOrderCouponItems to align with updateOrderItems
  Future<void> updateOrderCouponItems(int orderId, List<model.CouponLine> couponLines) async {
    if (kDebugMode) {
      print("#### DEBUG: updateOrderCouponItems orderId: $orderId");
    }
    final db = await DBHelper.instance.database;
    final existingItems = await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemType} = ?',
      whereArgs: [orderId, ItemType.coupon.value],
    );

    final existingItemsMap = {
      for (var item in existingItems) item[AppDBConst.itemServerId].toString(): item,
    };

    if (kDebugMode) {
      print("#### DEBUG: updateOrderCouponItems - Processing ${couponLines.length} coupon items for order $orderId, existing items: ${existingItems.length}");
    }

    for (var coupon in couponLines) {
      final itemId = coupon.id.toString();
      final double itemPrice = coupon.nominalAmount ?? 0.0;
      final int itemQuantity = 1;
      final double itemSumPrice = itemPrice;

      if (kDebugMode) {
        print("#### DEBUG: updateOrderCouponItems - Processing coupon item ID: $itemId, code: ${coupon.code}, price: $itemPrice, quantity: $itemQuantity, sumPrice: $itemSumPrice");
      }

      if (existingItemsMap.containsKey(itemId)) {
        final existingItem = existingItemsMap[itemId]!;
        await db.update(
          AppDBConst.purchasedItemsTable,
          {
            AppDBConst.itemName: coupon.code ?? 'Coupon',
            AppDBConst.itemPrice: itemPrice,
            AppDBConst.itemCount: itemQuantity,
            AppDBConst.itemSumPrice: itemSumPrice,
            AppDBConst.itemImage: 'assets/svg/coupon.svg',
            AppDBConst.itemSKU: '',
          },
          where: '${AppDBConst.itemServerId} = ?', //Build #1.0.128: Updated - itemId to itemServerId
          whereArgs: [existingItem[AppDBConst.itemServerId]],
        );
        if (kDebugMode) {
          print("#### DEBUG: Updated coupon item ID: $itemId for order $orderId");
        }
        existingItemsMap.remove(itemId);
      } else {
        await db.insert(AppDBConst.purchasedItemsTable, {
          //   AppDBConst.itemId: orderId,
          AppDBConst.itemServerId: coupon.id, //Build #1.0.67: updated
          AppDBConst.itemName: coupon.code ?? 'Coupon',
          AppDBConst.itemSKU: '',
          AppDBConst.itemPrice: itemPrice,
          AppDBConst.itemImage: 'assets/svg/coupon.svg',
          AppDBConst.itemCount: itemQuantity,
          AppDBConst.itemSumPrice: itemSumPrice,
          AppDBConst.orderIdForeignKey: orderId,
          AppDBConst.itemType: ItemType.coupon.value,
        });
        if (kDebugMode) {
          print("#### DEBUG: Inserted new coupon item ID: $itemId for order $orderId");
        }
      }
    }

    for (var item in existingItemsMap.values) {
      await db.delete(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.itemServerId} = ?', //Build #1.0.128: Updated - itemId to itemServerId
        whereArgs: [item[AppDBConst.itemServerId]],
      );
      if (kDebugMode) {
        print("#### DEBUG: Deleted obsolete coupon item ID: ${item[AppDBConst.itemServerId]} for order $orderId");
      }
    }
  }

  // Creates a new order and sets it as active
  Future<int> createOrder({int? serverOrderId}) async { // Build #1.0.11 : updated
    ///check if 'orderServerId' is 0 or not, if yes show alert
    final db = await DBHelper.instance.database;
    activeOrderId = serverOrderId;
    await db.insert(AppDBConst.orderTable, {
      AppDBConst.userId: activeUserId ?? 1,
      if (serverOrderId != null) AppDBConst.orderServerId: serverOrderId, /// server created order id, update after order created at backend
      AppDBConst.orderTotal: 0.0, /// initially it will be 0
      AppDBConst.orderStatus: "processing", /// initial value will be 'processing'
      AppDBConst.orderType: 'in-store',
      AppDBConst.orderDate: DateTime.now().toString(), /// update these from order created on server
      AppDBConst.orderTime: DateTime.now().toString(),
    });

    // Update the user's order count
    await db.rawUpdate('''
    UPDATE ${AppDBConst.userTable}
    SET ${AppDBConst.userOrderCount} = ${AppDBConst.userOrderCount} + 1
    WHERE ${AppDBConst.userId} = ?
    ''', [activeUserId ?? 1]);

    // Save the newly created order ID in shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeOrderId', activeOrderId!);

    // Refresh the order list
    await loadData();

    if (kDebugMode) {
      print("#### Order created with ID: $activeOrderId");
    }

    return activeOrderId!;
  }

  // Deletes an order from the database and updates local storage
  Future<void> deleteOrder(int orderId) async {
    final db = await DBHelper.instance.database;
    await db.delete( //Build #1.0.78 : delete from db -> purchasedItemsTable
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ?',
      whereArgs: [orderId],
    );
    await db.delete( //Build #1.0.78 : delete from db -> orderTable
      AppDBConst.orderTable,
      where: '${AppDBConst.orderServerId} = ?',
      whereArgs: [orderId],
    );

    //  orders.removeWhere((order) => order[AppDBConst.orderServerId] == orderId); // read-only property
    // Build #1.0.189: Remove the orderId from orderIds list
    orderIds.remove(orderId);

    final prefs = await SharedPreferences.getInstance();

    // If the deleted order was the active order, reset the activeOrderId
    if (orderId == activeOrderId) {
      activeOrderId = orderIds.isNotEmpty ? orderIds.last : null;
      await prefs.remove('activeOrderId');
    }

    // Reload the updated order list
    await loadData();

    // Debugging logs
    if (kDebugMode) {
      print('#### Order deleted with ID: $orderId');
      print('#### Updated activeOrderId: $activeOrderId');
      print('#### Updated orderIds: $orderIds');
    }
  }

  // Sets a specific order as the active order
  Future<void> setActiveOrder(int orderId) async {
    activeOrderId = orderId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeOrderId', activeOrderId!);

    // Debugging log
    if (kDebugMode) {
      print("#### Active order set to: $activeOrderId");
    }
  }

  // Build #1.0.161: Store current active order before leaving
  /// we are using same "activeOrderId" for both orderPanel & total order screen
  /// we have to save order panel activeOrderId in "lastActiveOrderId" pref value when comes back assign it
  /// Issue: when comes from orders screen to order panel screens selected orderId changing
  Future<void> saveLastActiveOrderId(int orderId) async {
    activeOrderId = orderId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastActiveOrderId', activeOrderId!);
    if (kDebugMode) {
      print("##### Saved last active order ID: $activeOrderId");
    }
  }

  // Build #1.0.161: Restore active order when returning
  Future<void> restoreActiveOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOrderId = prefs.getInt('lastActiveOrderId');

    if (lastOrderId != null && lastOrderId != -1) {
      await setActiveOrder(lastOrderId);
      if (kDebugMode) {
        print("##### Restored active order ID: $lastOrderId");
      }
    }
  }

  // Fetch all orders for a specific user
  Future<List<Map<String, dynamic>>> getUserOrders(int userID) async { // Build #1.0.11 : added here from db_helper
    final db = await DBHelper.instance.database;
    return await db.query(
      AppDBConst.orderTable,
      where: '${AppDBConst.userId} = ?',
      whereArgs: [userID],
    );
  }

  // Fetch order for a specific orderId
  Future<List<Map<String, dynamic>>> getOrderById(int orderId) async { // Build #1.0.11 : added here from db_helper
    final db = await DBHelper.instance.database;
    return await db.query(
      AppDBConst.orderTable,
      where: '${AppDBConst.orderServerId} = ?',
      whereArgs: [orderId],
    );
  }

// Fetch all items for a specific order
  Future<List<Map<String, dynamic>>> getOrderItems(int orderID) async {
    final db = await DBHelper.instance.database;
    return await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ?',
      whereArgs: [orderID],
    );
  }

// Delete an item from an order
  Future<void> deleteItem(int itemServerId) async { // delete the item/product based on serverID not item id
    final db = await DBHelper.instance.database;
    await db.delete(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.itemServerId} = ?', // Build #1.0.92: using item server id , checked used places!!
      whereArgs: [itemServerId],
    );

    if (kDebugMode) {
      print('#### Item deleted with ID: $itemServerId');
    }
  }

  //Build 1.1.36: Clears all items for a specific order before updating order items in order bloc -> updateOrderProducts
  Future<void> clearOrderItems(int orderId) async {
    final db = await DBHelper.instance.database;
    await db.delete(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.orderIdForeignKey} = ?',
      whereArgs: [orderId],
    );

    if (kDebugMode) {
      print('#### Cleared all items for order: $orderId');
    }
  }

  // Adds an item to the currently active order; creates an order if none exists

  // Adds an item to the currently active order; creates an order if none exists
  Future<void> addItemToOrder(
      int? serverItemId,
      String name,
      String image,
      double price,
      int quantity,
      String sku,
      int orderId, {
        VoidCallback? onItemAdded,
        String? type,
        int? productId = -1,
        int? variationId = -1,
        String? variationName,
        int? variationCount,
        String? combo,
        double? salesPrice,
        double? regularPrice,
        double? unitPrice,
      }) async {
    final box = Hive.box('offlineOrders');
    final order = box.get(orderId.toString());

    if (order == null) {
      if (kDebugMode) print("⚠️ No offline order found for $orderId");
      return;
    }

    // Clone existing products
    final List<Map<String, dynamic>> products = (order['products'] ?? [])
        .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
        .toList();

    final normProductId = (productId ?? -1).toInt();
    final normVariationId = (variationId ?? 0).toInt();

    // ✅ Check if product already exists (strict match)
    final existingIndex = products.indexWhere((p) {
      final storedProductId = (p['product_id'] ?? -1).toInt();
      final storedVariationId = (p['variation_id'] ?? 0).toInt();
      return storedProductId == normProductId &&
          storedVariationId == normVariationId;
    });

    if (existingIndex != -1) {
      // 🔁 Update existing product quantity
      final existing = products[existingIndex];
      final oldQty = (existing['quantity'] ?? 0).toInt();
      final newQty = oldQty + quantity;

      products[existingIndex] = {
        ...existing,
        'quantity': newQty,
        'price': price,
      };

      if (kDebugMode) {
        print("🔁 Updated existing product: $name (Qty: $oldQty → $newQty)");
      }
    } else {
      // 🆕 Add new product
      products.add({
        'server_item_id': serverItemId,
        'name': name,
        'image': image,
        'price': price,
        'quantity': quantity,
        'sku': sku,
        'type': type ?? 'product',
        'product_id': productId,
        'variation_id': variationId,
        'variation_name': variationName,
        'variation_count': variationCount,
        'combo': combo,
        'sales_price': salesPrice,
        'regular_price': regularPrice,
        'unit_price': unitPrice,
      });

      if (kDebugMode) print("🆕 Added new product: $name");
    }

    // 💾 Update Hive order
    await box.put(orderId.toString(), {...order, 'products': products});

    // 💾 Sync with SQLite
    final db = await DBHelper.instance.database;

    final existingInDb = await db.query(
      AppDBConst.purchasedItemsTable,
      where:
      '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemProductId} = ? AND ${AppDBConst.itemVariationId} = ?',
      whereArgs: [orderId, normProductId, normVariationId],
    );

    if (existingInDb.isNotEmpty) {
      final existingRow = existingInDb.first;
      final oldQty = existingRow[AppDBConst.itemCount] as int;
      final newQty = oldQty + quantity;

      await db.update(
        AppDBConst.purchasedItemsTable,
        {
          AppDBConst.itemCount: newQty,
          AppDBConst.itemSumPrice: price * newQty,
        },
        where:
        '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemProductId} = ? AND ${AppDBConst.itemVariationId} = ?',
        whereArgs: [orderId, normProductId, normVariationId],
      );

      if (kDebugMode) {
        print("🧮 SQLite updated: $name (Qty: $oldQty → $newQty)");
      }
    } else {
      await db.insert(AppDBConst.purchasedItemsTable, {
        AppDBConst.itemServerId: serverItemId,
        AppDBConst.itemName: name,
        AppDBConst.itemImage: image,
        AppDBConst.itemPrice: price,
        AppDBConst.itemCount: quantity,
        AppDBConst.itemSumPrice: price,
        AppDBConst.orderIdForeignKey: orderId,
        AppDBConst.itemSKU: sku,
        AppDBConst.itemType: type,
        AppDBConst.itemProductId: normProductId,
        AppDBConst.itemVariationId: normVariationId,
        AppDBConst.itemVariationCustomName: variationName,
        AppDBConst.itemVariationCount: variationCount,
        AppDBConst.itemCombo: combo,
        AppDBConst.itemSalesPrice: salesPrice,
        AppDBConst.itemRegularPrice: regularPrice,
        AppDBConst.itemUnitPrice: unitPrice,
      });

      if (kDebugMode) print("💾 Inserted new product in SQLite: $name");
    }

    await loadData();

    if (onItemAdded != null) onItemAdded();
  }


  @Deprecated("Removed from current version, please use Rest API to update")
  //Build 1.1.36: required this func for issue of Edit item not updating count in order panel
  Future<void> updateItemQuantity(int itemId, int newQuantity) async {
    final db = await DBHelper.instance.database;

    // Fetch the item's current price to calculate the new sum price
    final item = await db.query(
      AppDBConst.purchasedItemsTable,
      where: '${AppDBConst.itemId} = ?',
      whereArgs: [itemId],
    );

    if (item.isNotEmpty) {
      double price = (item.first[AppDBConst.itemPrice] as num).toDouble();
      double newSumPrice = price * newQuantity;

      // Update the quantity and sum price in the database
      await db.update(
        AppDBConst.purchasedItemsTable,
        {
          AppDBConst.itemCount: newQuantity,
          AppDBConst.itemSumPrice: newSumPrice,
        },
        where: '${AppDBConst.itemId} = ?',
        whereArgs: [itemId],
      );

      // Update the order total in the orders table
      final items = await getOrderItems(item.first[AppDBConst.orderIdForeignKey] as int);
      double orderTotal = items.fold(0.0, (sum, item) => sum + (item[AppDBConst.itemSumPrice] as num).toDouble());

      await db.update(
        AppDBConst.orderTable,
        {AppDBConst.orderTotal: orderTotal},
        where: '${AppDBConst.orderId} = ?',
        whereArgs: [item.first[AppDBConst.orderIdForeignKey]],
      );

      if (kDebugMode) {
        print('#### Item quantity updated: ID=$itemId, Quantity=$newQuantity, New Sum Price=$newSumPrice');
        print('#### Order total updated: Order ID=${item.first[AppDBConst.orderIdForeignKey]}, Total=$orderTotal');
      }
    }
  }

// If using a StatefulWidget
// Future<void> updateItemQuantity(int itemId, int quantity) async {
//   final db = await DBHelper.instance.database;
//
//   // Calculate the new sum price based on the updated quantity
//   final item = await db.query(
//     AppDBConst.purchasedItemsTable,
//     where: '${AppDBConst.itemId} = ?',
//     whereArgs: [itemId],
//   );
//
//   if (item.isNotEmpty) {
//     double price = (item.first[AppDBConst.itemPrice] as num).toDouble();
//     double newSumPrice = price * quantity;
//
//     await db.update(
//         AppDBConst.purchasedItemsTable,
//         {
//           AppDBConst.itemCount: quantity,
//           AppDBConst.itemSumPrice: newSumPrice
//         },
//         where: '${AppDBConst.itemId} = ?',
//         whereArgs: [itemId]
//     );
//
//     if (kDebugMode) {
//       print('#### Item quantity updated: ID=$itemId, Quantity=$quantity');
//     }
//
//     // After database update, refresh the UI
//     // setState(() {
//     //   // If needed, update any widget state variables here
//     // });
//
//     // Or if using a provider
//     // Provider.of<YourProvider>(context, listen: false).refreshItems();
//   }
// }
}