// import 'package:flutter/foundation.dart';
// import '../models/display_state.dart';
// import '../services/mqtt_customer_display_service.dart';
//
// class DisplayProvider extends ChangeNotifier {
//   final MqttCustomerDisplayService service;
//   DisplayState state = DisplayState.idle();
//   bool connected = false;
//   String statusMessage = 'Starting…';
//   String? lastError;
//   bool isFetchingPoints = false;
//
//   // DisplayProvider(this.service) {
//   //   service.stateStream.listen((newState) {
//   //     // ── FIX: If IDLE/WELCOME but has a real orderId, treat it as CART ──
//   //     if (newState.screen == 'IDLE' || newState.screen == 'WELCOME') {
//   //       final hasRealOrder = newState.orderId.trim().isNotEmpty &&
//   //           newState.orderId.trim() != '0';
//   //       if (hasRealOrder) {
//   //         // Preserve the order data and show CART layout with empty items
//   //         state = newState.copyWith(screen: 'CART');
//   //       } else {
//   //         // True idle – reset everything except store branding
//   //         state = DisplayState.idle().copyWith(
//   //           storeId: state.storeId,
//   //           storeName: state.storeName,
//   //           storeLogoUrl: state.storeLogoUrl,
//   //           storeBaseUrl: state.storeBaseUrl,
//   //           slideshowUrls: state.slideshowUrls,
//   //         );
//   //       }
//   //     } else {
//   //       // For CART, PAYMENT, etc., merge branding normally
//   //       state = newState.mergeBranding(state);
//   //     }
//   //
//   //     statusMessage = 'Live · ${state.screen} · ${state.items.length} items';
//   //     lastError = null;
//   //     notifyListeners();
//   //   });
//   // }
//
//   DisplayProvider(this.service) {
//     service.stateStream.listen((newState) {
//       if (newState.screen == 'IDLE' || newState.screen == 'WELCOME') {
//         final hasRealOrder = newState.orderId.trim().isNotEmpty &&
//             newState.orderId.trim() != '0';
//         if (hasRealOrder) {
//           state = newState.copyWith(screen: 'CART', items: []);
//         } else {
//           state = DisplayState.idle().copyWith(
//             storeId: state.storeId,
//             storeName: state.storeName,
//             storeLogoUrl: state.storeLogoUrl,
//             storeBaseUrl: state.storeBaseUrl,
//             slideshowUrls: state.slideshowUrls,
//           );
//         }
//       } else {
//         state = newState.mergeBranding(state);
//       }
//
//       statusMessage = 'Live · ${state.screen} · ${state.items.length} items';
//       lastError = null;
//       notifyListeners();
//     });
//   }
//
//
//   Future<void> start() async {
//     statusMessage = 'Connecting to POS…';
//     notifyListeners();
//
//     try {
//       connected = await service.connect();
//       if (connected) {
//         statusMessage = 'Connected · waiting for cart';
//       } else {
//         statusMessage = 'Disconnected · check POS IP & broker';
//         lastError = 'Could not reach any MQTT broker';
//       }
//     } catch (e) {
//       connected = false;
//       statusMessage = 'Connection error';
//       lastError = e.toString();
//     }
//     notifyListeners();
//   }
//
//   Future<void> retry() async {
//     service.disconnect();
//     await start();
//   }
//
//   // ---------------------------------------------------------------------------
//   // Loyalty / redeem
//   // ---------------------------------------------------------------------------
//
//   Future<void> submitLoyaltyContact(String contact) async {
//     isFetchingPoints = true;
//     state = state.copyWith(loyaltyContact: contact);
//     notifyListeners();
//     // TODO: publish to MQTT when ready
//   }
//
//   void applyRedeemResult({
//     required bool success,
//     String message = '',
//     int points = 0,
//     double redeemedAmount = 0.0,
//   }) {
//     isFetchingPoints = false;
//     if (success) {
//       state = state.copyWith(
//         availablePoints: points,
//         redeemedAmount: redeemedAmount,
//       );
//     } else {
//       lastError = message.isNotEmpty ? message : 'Something went wrong';
//     }
//     notifyListeners();
//   }
//
//   void unlockPhoneInput() {
//     state = state.copyWith(phoneInputUnlocked: true);
//     notifyListeners();
//   }
//
//   void closeRedeemPopup() {
//     // TODO: publish 'customerDisplayPopupClosed' if needed
//   }
//
//   // ── Optional: explicit reset from outside ──
//   void resetToWelcome() {
//     state = DisplayState.idle().copyWith(
//       storeId: state.storeId,
//       storeName: state.storeName,
//       storeLogoUrl: state.storeLogoUrl,
//       storeBaseUrl: state.storeBaseUrl,
//       slideshowUrls: state.slideshowUrls,
//     );
//     notifyListeners();
//   }
// }


///////======

import 'package:flutter/foundation.dart';
import '../models/display_state.dart';
import '../services/mqtt_customer_display_service.dart';

class DisplayProvider extends ChangeNotifier {
  MqttCustomerDisplayService _service;
  DisplayState state = DisplayState.idle();
  bool connected = false;
  String statusMessage = 'Starting…';
  String? lastError;
  bool isFetchingPoints = false;

  /// Public read-only access (keeps existing call-sites working).
  MqttCustomerDisplayService get service => _service;

  DisplayProvider(this._service) {
    _attachStateListener();
  }

  void _attachStateListener() {
    _service.stateStream.listen((newState) {
      if (newState.screen == 'IDLE' || newState.screen == 'WELCOME') {
        final hasRealOrder = newState.orderId.trim().isNotEmpty &&
            newState.orderId.trim() != '0';
        if (hasRealOrder) {
          state = newState.copyWith(screen: 'CART', items: []);
        } else {
          state = DisplayState.idle().copyWith(
            storeId: state.storeId,
            storeName: state.storeName,
            storeLogoUrl: state.storeLogoUrl,
            storeBaseUrl: state.storeBaseUrl,
            slideshowUrls: state.slideshowUrls,
          );
        }
      } else {
        state = newState.mergeBranding(state);
      }

      statusMessage = 'Live · ${state.screen} · ${state.items.length} items';
      lastError = null;
      notifyListeners();
    });
  }

  Future<void> start() async {
    statusMessage = 'Connecting to POS…';
    notifyListeners();

    try {
      connected = await _service.connect();
      if (connected) {
        statusMessage = 'Connected · waiting for cart';
      } else {
        statusMessage = 'Disconnected · check POS IP & broker';
        lastError = 'Could not reach any MQTT broker';
      }
    } catch (e) {
      connected = false;
      statusMessage = 'Connection error';
      lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> retry() async {
    _service.disconnect();
    await start();
  }

  // ---------------------------------------------------------------------------
  // NEW — Reconnect (mDNS rediscovery of the current POS)
  // ---------------------------------------------------------------------------

  /// Re-run discovery / reconnect to the currently advertised POS.
  Future<void> reconnect() async {
    statusMessage = 'Reconnecting…';
    lastError = null;
    notifyListeners();

    try {
      _service.disconnect();

      // Fresh service that uses mDNS (brokerHost left null).
      final next = MqttCustomerDisplayService(
        brokerPort: _service.brokerPort,
        displayId: 'CFD-${DateTime.now().millisecondsSinceEpoch}',
        username: _service.username,
        token: _service.token,
        // optional filters if the original service had them
        terminalId: _service.terminalId,
        merchantId: _service.merchantId,
        storeId: _service.storeId,
      );

      _service = next;
      _attachStateListener();

      connected = await _service.connect();
      if (connected) {
        statusMessage = 'Reconnected · waiting for cart';
      } else {
        statusMessage = 'Reconnect failed · POS not found';
        lastError = 'Could not discover any POS via mDNS';
      }
    } catch (e) {
      connected = false;
      statusMessage = 'Reconnect error';
      lastError = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // NEW — Connect from scanned QR payload
  // ---------------------------------------------------------------------------

  /// Connect using the exact broker / credentials encoded in the POS Settings QR.
  Future<void> connectWithScannedConfig({
    required String brokerIp,
    required int brokerPort,
    required String merchantId,
    required String storeId,
    required String terminalId,
    required String brokerUsername,
    required String brokerToken,
  }) async {
    statusMessage = 'Connecting via QR…';
    lastError = null;
    notifyListeners();

    try {
      _service.disconnect();

      final next = MqttCustomerDisplayService(
        brokerPort: brokerPort,
        displayId: 'CFD-${DateTime.now().millisecondsSinceEpoch}',
        username: brokerUsername,
        token: brokerToken,
        brokerHost: brokerIp,          // direct connect — skip mDNS
        merchantId: merchantId,
        storeId: storeId,
        terminalId: terminalId,
      );

      _service = next;
      _attachStateListener();

      connected = await _service.connect();
      if (connected) {
        statusMessage = 'Connected via QR · waiting for cart';
      } else {
        statusMessage = 'QR connect failed';
        lastError = 'Could not reach $brokerIp:$brokerPort';
      }
    } catch (e) {
      connected = false;
      statusMessage = 'QR connect error';
      lastError = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Loyalty / redeem  (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> submitLoyaltyContact(String contact) async {
    isFetchingPoints = true;
    state = state.copyWith(loyaltyContact: contact);
    notifyListeners();
    // TODO: publish to MQTT when ready
  }

  void applyRedeemResult({
    required bool success,
    String message = '',
    int points = 0,
    double redeemedAmount = 0.0,
  }) {
    isFetchingPoints = false;
    if (success) {
      state = state.copyWith(
        availablePoints: points,
        redeemedAmount: redeemedAmount,
      );
    } else {
      lastError = message.isNotEmpty ? message : 'Something went wrong';
    }
    notifyListeners();
  }

  void unlockPhoneInput() {
    state = state.copyWith(phoneInputUnlocked: true);
    notifyListeners();
  }

  void closeRedeemPopup() {
    // TODO: publish 'customerDisplayPopupClosed' if needed
  }

  // ── Optional: explicit reset from outside ──
  void resetToWelcome() {
    state = DisplayState.idle().copyWith(
      storeId: state.storeId,
      storeName: state.storeName,
      storeLogoUrl: state.storeLogoUrl,
      storeBaseUrl: state.storeBaseUrl,
      slideshowUrls: state.slideshowUrls,
    );
    notifyListeners();
  }
}