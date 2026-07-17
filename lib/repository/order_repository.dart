import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/appconstant.dart';

class OrderRepository {
  String get _orderUrl => AppConstants.ordersEndpoint;

  String get _paymentUrl => AppConstants.createPaymentEndpoint;
  Future<Map<String, dynamic>> createCashPayment({
    required int orderId,
    required double amount,
  }) async {
    print('[OrderRepository] createCashPayment called');
    print('[OrderRepository] payment orderId: $orderId, amount: $amount');

    if (orderId <= 0) {
      print('[OrderRepository] invalid order id for payment');
      throw Exception('Invalid order id for cash payment.');
    }

    final token = await _getAuthToken(flowName: 'CashPayment');

    final payload = {
      'order_id': orderId,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'payment_method': 'cash',
      'service_type': 'kiosk',
      'notes': 'Paid via kiosk - cash',
    };
    print(
      '[OrderRepository][CashPayment] request payload: ${jsonEncode(payload)}',
    );

    final response = await http.post(
      Uri.parse(_paymentUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print(
      '[OrderRepository][CashPayment] response status: ${response.statusCode}',
    );
    print('[OrderRepository][CashPayment] response body: ${response.body}');

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[OrderRepository][CashPayment] payment failed');
      throw Exception('Cash payment API failed (${response.statusCode}): $decoded');
    }

    print('[OrderRepository][CashPayment] payment success');
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> createCardPayment({
    required int orderId,
    required double amount,
  }) async {
    print('[OrderRepository] createCardPayment called');
    print('[OrderRepository] payment orderId: $orderId, amount: $amount');

    if (orderId <= 0) {
      print('[OrderRepository] invalid order id for card payment');
      throw Exception('Invalid order id for card payment.');
    }

    final token = await _getAuthToken(flowName: 'CardPayment');

    final payload = {
      'order_id': orderId,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'payment_method': 'card',
      'service_type': 'kiosk',
      'transaction_id': 'CARD_TXN_${DateTime.now().millisecondsSinceEpoch}',
      'transaction_details': {
        'card_type': 'visa',
        'last4': '1234',
      },
      'notes': 'Paid via kiosk - card',
    };
    print(
      '[OrderRepository][CardPayment] request payload: ${jsonEncode(payload)}',
    );

    final response = await http.post(
      Uri.parse(_paymentUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print(
      '[OrderRepository][CardPayment] response status: ${response.statusCode}',
    );
    print('[OrderRepository][CardPayment] response body: ${response.body}');

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[OrderRepository][CardPayment] payment failed');
      throw Exception('Card payment API failed (${response.statusCode}): $decoded');
    }

    print('[OrderRepository][CardPayment] payment success');
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> createDineInOrder({
    required List<Map<String, dynamic>> cartItems,
  }) async {
    print('[OrderRepository] createDineInOrder called');
    print('[OrderRepository] cart item count: ${cartItems.length}');
    final payload = {
      'status': 'processing',
      'parent_id': 0,
      'created_via': 'rest-api',
      'meta_data': [
        {
          'key': 'pos_device_id',
          'value': 'b31b723b92047f4b',
        },
        {
          'key': 'order_created_via',
          'value': 'pinakapos',
        },
        {
          'key': '_wc_order_created_by',
          'value': '1',
        }
      ],
      'line_items': cartItems.map(_buildLineItem).toList(growable: false),
    };
    return _postOrder(
      cartItems: cartItems,
      payload: payload,
      flowName: 'Dine-In',
    );
  }

  Future<Map<String, dynamic>> createTakeAwayOrder({
    required List<Map<String, dynamic>> cartItems,
  }) async {
    print('[OrderRepository] createTakeAwayOrder called');
    print('[OrderRepository] cart item count: ${cartItems.length}');

    final payload = {
      'status': 'processing',
      'parent_id': 0,
      'created_via': 'take away',
      'meta_data': [
        {
          'key': 'pos_device_id',
          'value': 'b31b723b92047f4b',
        },
        {
          'key': '_wc_order_created_by',
          'value': '1',
        }
      ],
      'line_items': cartItems.map(_buildLineItem).toList(growable: false),
    };
    return _postOrder(
      cartItems: cartItems,
      payload: payload,
      flowName: 'Take Away',
    );
  }

  Future<Map<String, dynamic>> _postOrder({
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> payload,
    required String flowName,
  }) async {
    if (cartItems.isEmpty) {
      print('[OrderRepository][$flowName] cart is empty, aborting');
      throw Exception('Cart is empty. Add items before payment.');
    }

    final token = await _getAuthToken(flowName: flowName);
    print('[OrderRepository][$flowName] request payload: ${jsonEncode(payload)}');

    final response = await http.post(
      Uri.parse(_orderUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    print('[OrderRepository][$flowName] response status: ${response.statusCode}');
    print('[OrderRepository][$flowName] response body: ${response.body}');

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[OrderRepository][$flowName] order creation failed');
      throw Exception('Order API failed (${response.statusCode}): $decoded');
    }

    print('[OrderRepository][$flowName] order creation success');
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Map<String, dynamic> _buildLineItem(Map<String, dynamic> item) {
    final product = item['product'];
    final quantity = (item['qty'] as num?)?.toInt() ?? 1;
    final addons = (item['addons'] as List?) ?? const [];

    final productId = (product?.id as num?)?.toInt() ?? 0;
    final baseUnitPrice = _parsePrice(product?.price?.toString() ?? '0');

    final addonUnitTotal = addons.fold<double>(0, (sum, addon) {
      return sum + _asDouble(addon?.price);
    });

    final subtotal = baseUnitPrice * quantity;
    final total = (baseUnitPrice + addonUnitTotal) * quantity;
    print(
      '[OrderRepository] line item -> product_id: $productId, qty: $quantity, '
          'baseUnitPrice: $baseUnitPrice, addonUnitTotal: $addonUnitTotal, '
          'subtotal: $subtotal, total: $total',
    );

    return {
      'product_id': productId,
      'quantity': quantity,
      'subtotal': subtotal.toStringAsFixed(2),
      'total': total.toStringAsFixed(2),
      'meta_data': [
        {
          'key': '_addons',
          'value': addons
              .map((addon) => {
            'id': (addon?.id as num?)?.toInt() ?? 0,
            'name': addon?.name?.toString() ?? '',
            'quantity': 1,
            'price': _asDouble(addon?.price),
          })
              .toList(growable: false),
        },
        {
          'key': '_modifiers',
          'value': const [],
        },
        {
          'key': '_extra_modifier_amount',
          'value': (addonUnitTotal * quantity).toStringAsFixed(2),
        },
      ],
    };
  }

  double _parsePrice(String rawPrice) {
    final cleaned = rawPrice.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<String> _getAuthToken({required String flowName}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) {
      print('[OrderRepository][$flowName] missing auth token in SharedPreferences');
      throw Exception('Authentication token missing. Please login again.');
    }
    print('[OrderRepository][$flowName] using token source: SharedPreferences');
    return token;
  }
}