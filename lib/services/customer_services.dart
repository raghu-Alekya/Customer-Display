import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:pinaka_pos/Preferences/pinaka_preferences.dart';

class CustomerService {
  static late MqttServerClient client;
  static bool connected = false;

  static int _storeId = 1001;
  /// MQTT topic segment `store/{storeId}/pos/{_posId}/order`.
  /// Default **1** so POS and customer display stay aligned.
  /// Override at compile time: `--dart-define=MQTT_POS_ID=2`
  /// Or derive from Android device id (usually wrong for a second screen device):
  /// `--dart-define=MQTT_POS_ID_FROM_DEVICE=true`
  static int _posId =
      int.tryParse(const String.fromEnvironment('MQTT_POS_ID', defaultValue: '1')) ?? 1;

  static String get _topic => 'store/$_storeId/pos/$_posId/order';
  static String _storeName = '';
  static String? _storeLogoUrl;
  static String? _storeBaseUrl;

  /// Always pull latest store name / logo / base URL from prefs before MQTT publish
  /// so the customer display gets dynamic branding even if `publishStoreInfo` was skipped.
  static void _syncStoreFromPreferences() {
    try {
      final store = PinakaPreferences.getLoggedInStore();
      if (store.isEmpty) return;

      final idStr = store['storeId']?.trim() ?? '';
      final parsed = int.tryParse(idStr);
      if (parsed != null && parsed > 0) {
        _storeId = parsed;
      }

      final name = store['storeName']?.trim();
      if (name != null && name.isNotEmpty) {
        _storeName = name;
      }

      final logo = store['storeLogoUrl']?.trim();
      if (logo != null && logo.isNotEmpty) {
        _storeLogoUrl = logo;
      }

      final base = store['storeBaseUrl']?.trim();
      if (base != null && base.isNotEmpty) {
        _storeBaseUrl = base;
      }
    } catch (e) {
      print('⚠ MQTT store sync from prefs failed: $e');
    }
  }

  /// Fields every customer-display message should carry (name + logo + topic routing).
  static Map<String, dynamic> _storeBrandingFields() {
    _syncStoreFromPreferences();
    final logo = _storeLogoUrl ?? '';
    return {
      'storeId': _storeId,
      'storeName': _storeName,
      // Both keys — receiver can use either
      'logoUrl': logo,
      'storeLogoUrl': logo,
      if (_storeBaseUrl != null && _storeBaseUrl!.isNotEmpty)
        'storeBaseUrl': _storeBaseUrl,
    };
  }

  /// Optional runtime override (e.g. from settings).
  static void setPosTerminalId(int id) {
    if (id > 0) {
      _posId = id;
      print('🧭 MQTT POS topic id set explicitly: $_posId');
    }
  }

  static void setPosIdFromDevice(String? deviceId) {
    const useDevice = bool.fromEnvironment(
      'MQTT_POS_ID_FROM_DEVICE',
      defaultValue: false,
    );
    if (!useDevice) {
      return;
    }

    final raw = (deviceId ?? '').trim();
    if (raw.isEmpty) return;

    _posId = (raw.hashCode & 0x7fffffff) % 100000;
    if (_posId == 0) {
      _posId = 1;
    }
    print('🧭 MQTT POS topic id set from device: $_posId');
  }

  static bool get _isReady =>
      connected && client.connectionStatus?.state == MqttConnectionState.connected;

  // 🔹 ADD THIS METHOD INSIDE THE CLASS
  static void _publish(Map<String, dynamic> payload) {
    if (!_isReady) {
      print("⚠ MQTT not connected, skipping publish");
      return;
    }

    final merged = {..._storeBrandingFields(), ...payload};

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(merged));

    client.publishMessage(
      _topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print(
        "📡 Sent to display topic=$_topic event=${merged['event']} status=${merged['paymentStatus']} store=${merged['storeName']}");
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
        _syncStoreFromPreferences();
        print("✅ POS connected to MQTT (store=$_storeName id=$_storeId)");
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
    _storeId = storeId > 0 ? storeId : _storeId;
    _storeName = storeName;
    _storeLogoUrl = logoUrl;
    _syncStoreFromPreferences(); // pick up storeBaseUrl from prefs if set

    _publish({
      "event": "store_info",
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

    final cartPayload = {
      ..._storeBrandingFields(),
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
    };

    builder.addString(jsonEncode(cartPayload));

    client.publishMessage(
      _topic,
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