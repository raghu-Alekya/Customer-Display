// repositories/order_repository.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Orders/apply_discount_model.dart';
import '../../Models/Orders/get_orders_model.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Orders/total_orders_count_model.dart';
import '../../Utilities/global_utility.dart';

class OrderRepository {  // Build #1.0.25 - added by naveen
  final APIHelper _helper = APIHelper();

  // 1. Create Order
  Future<CreateOrderResponseModel> createOrder() async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}";

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
    ];

    final request = CreateOrderRequestModel(metaData: metaData);

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      // ---------- OFFLINE MODE ----------
      final box = Hive.box('offlineOrders');

      // Generate 4-digit order ID
      int lastOrderId = box.get('lastOrderId', defaultValue: 1000);
      int newOrderId = lastOrderId + 1;
      box.put('lastOrderId', newOrderId);

      final localOrder = {
        'order_id': newOrderId,
        'request': request.toJson(),
        'created_at': DateTime.now().toIso8601String(),
        'synced': false,
        'products': [],
      };

      await box.put(newOrderId.toString(), localOrder);

      if (kDebugMode) {
        print("📦 Saved offline order: $localOrder");
      }

      // Return local response for UI consistency
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
    } else {
      // ---------- ONLINE MODE ----------
      if (kDebugMode) {
        print("OrderRepository - POST URL: $url");
        print("OrderRepository - Request Body: ${request.toJson()}");
      }

      final response = await _helper.post(url, request.toJson(), true);

      if (response is String) {
        final responseData = json.decode(response);
        return CreateOrderResponseModel.fromJson(responseData);
      } else if (response is Map<String, dynamic>) {
        return CreateOrderResponseModel.fromJson(response);
      } else {
        throw Exception("Unexpected response type in order POST");
      }
    }
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


  /// 🌀 Sync all offline orders when online
  Future<void> syncOfflineOrders() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final box = Hive.box('offlineOrders');
    final orders = box.toMap();

    for (final entry in orders.entries) {
      if (entry.key == 'lastOrderId') continue;

      final order = entry.value;
      if (order['synced'] == true) continue;

      try {
        final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}";
        final response = await _helper.post(url, order['request'], true);

        if (response is String) {
          final responseData = json.decode(response);
          if (responseData['id'] != null) {
            await box.delete(entry.key);
            if (kDebugMode) {
              print("✅ Synced order ${order['order_id']} successfully");
            }
          }
        } else if (response is Map<String, dynamic> &&
            response['id'] != null) {
          await box.delete(entry.key);
          if (kDebugMode) {
            print("✅ Synced order ${order['order_id']} successfully");
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("❌ Failed to sync order ${order['order_id']}: $e");
        }
      }
    }
  }

  // 2. Update Order Products
  Future<OrderModel> updateOrderProducts({required int orderId, required UpdateOrderRequestModel request,}) async {
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

  // 4. Delete Order Item (uses updateOrderProducts with quantity=0)
  Future<UpdateOrderResponseModel> deleteOrderItem({required int orderId, required UpdateOrderRequestModel request,}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - POST URL: $url");
      print("OrderRepository - Request Body (delete items): ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Raw Response (delete): $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return UpdateOrderResponseModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing delete order item response: $e");
        throw Exception("Failed to parse delete order item response");
      }
    } else if (response is Map<String, dynamic>) {
      return UpdateOrderResponseModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in delete order item PUT");
    }
  }

  // Build #1.0.49: Added changeOrderStatus api call code
  Future<UpdateOrderResponseModel> changeOrderStatus({required int orderId, required OrderStatusRequest request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}/$orderId";

    if (kDebugMode) {
      print("OrderRepository - POST URL for status change: $url");
      print("OrderRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("OrderRepository - Change status Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return UpdateOrderResponseModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing change order status response: $e");
        throw Exception("Failed to parse change order status response");
      }
    } else if (response is Map<String, dynamic>) {
      return UpdateOrderResponseModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in change order status POST");
    }
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

  // Build #1.0.198 : Add Payout as a product to Order
  Future<OrderModel> addPayoutAsProduct({required int orderId, required AddPayoutAsProductRequestModel request}) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.orders}${EndUrlConstants.addPayoutEndUrl}";

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