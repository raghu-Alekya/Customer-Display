import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class CustomerService {
  static late MqttServerClient client;
  static bool connected = false;

  static const String _topic = 'store/1001/pos/1/order';

  static bool get _isReady =>
      connected && client.connectionStatus?.state == MqttConnectionState.connected;

  // 🔹 ADD THIS METHOD INSIDE THE CLASS
  static void _publish(Map<String, dynamic> payload) {
    if (!_isReady) {
      print("⚠ MQTT not connected, skipping publish");
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));

    client.publishMessage(
      _topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print("📡 Sent to display: ${payload['event']} status=${payload['paymentStatus']}");
  }


  /// CONNECT TO MQTT BROKER
  static Future<void> connect() async {

    client = MqttServerClient('172.17.7.80', 'pos_terminal');

    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;

    try {

      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        connected = true;
        print("✅ POS connected to MQTT");
      }

    } catch (e) {
      print("❌ MQTT connection error: $e");
      client.disconnect();
    }
  }
  static Future<void> publishStoreInfo({
    required int storeId,
    required String storeName,
    String? logoUrl,
  }) async {
    _publish({
      "event": "store_info",
      "storeId": storeId,
      "storeName": storeName,
      "logoUrl": logoUrl,
    });
  }


  /// PUBLISH CART UPDATE
  static Future publishCartUpdate(
      int orderId,
      List products, {
        required double subtotal,
        required double tax,
        required double total,
      }) async {
    if (!connected) {
      print("⚠ MQTT not connected");
      return;
    }

    final builder = MqttClientPayloadBuilder();

    builder.addString(jsonEncode({
      "event": "cart_updated",
      "orderId": orderId,
      "items": products.map((p) => {
        "name": p["name"],
        "qty": p["quantity"],
        "price": p["price"],
      }).toList(),
      "subtotal": subtotal,
      "tax": tax,
      "total": total,
    }));

    client.publishMessage(
      "store/1001/pos/1/order",
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print("📡 Cart update sent to display");
  }
  /// CALL THIS WHEN CASH BUTTON IS PRESSED (before/while processing)
  static Future<void> publishProcessingPayment(
      int orderId,
      List products, {
        required double subtotal,
        required double tax,
        required double total,
      }) async {
    _publish({
      "event": "payment_status",
      "paymentStatus": "PROCESSING", // display watches this
      "orderId": orderId,
      "items": products
          .map((p) => {
        "name": p["name"],
        "qty": p["quantity"],
        "price": p["price"],
      })
          .toList(),
      "subtotal": subtotal,
      "tax": tax,
      "total": total,
    });
  }
  /// CALL THIS AFTER PAYMENT IS SUCCESSFUL
  static Future<void> publishPaymentSuccess(
      int orderId,
      List products, {
        required double subtotal,
        required double tax,
        required double total,
      }) async {
    _publish({
      "event": "payment_status",
      "paymentStatus": "PAID", // display will switch to thank-you screen
      "orderId": orderId,
      "items": products
          .map((p) => {
        "name": p["name"],
        "qty": p["quantity"],
        "price": p["price"],
      })
          .toList(),
      "subtotal": subtotal,
      "tax": tax,
      "total": total,
    });
  }
}
