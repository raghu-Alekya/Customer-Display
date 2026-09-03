import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/mqtt_server/store_messaging_service.dart';
import 'cart_item.dart';
import 'cart_state.dart';
import 'cfd_store_payload.dart';

class CartProvider extends ChangeNotifier {
  final StoreMessagingService messagingService;
  final String sessionId;

  final List<CartItem> _items = [];
  String _screen = 'IDLE';
  int? _orderId;
  double _tax = 0;
  double _orderDiscount = 0;
  double _merchantDiscount = 0;
  double _cashbackFee = 0;
  double _netPayable = 0;

  CartProvider({required this.messagingService, required this.sessionId});

  List<CartItem> get items => List.unmodifiable(_items);
  String get screen => _screen;
  int? get orderId => _orderId;

  void setOrderId(int? id) {
    _orderId = id;
  }

  void addItem(CartItem item) {
    final existingIndex =
    _items.indexWhere((i) => i.productId == item.productId);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = CartItem(
        productId: existing.productId,
        name: existing.name,
        qty: existing.qty + item.qty,
        unitPrice: existing.unitPrice,
        discount: existing.discount,
        sku: existing.sku,
        itemType: existing.itemType,
        image: existing.image,
        weightQty: existing.weightQty,
        itemTax: existing.itemTax,
        loyaltyPoints: existing.loyaltyPoints,
        variationId: existing.variationId,
        isEbtEligible: existing.isEbtEligible,
      );
    } else {
      _items.add(item);
    }
    _screen = 'CART';
    unawaited(_publishAndNotify());
  }

  void updateQty(String productId, int qty) {
    final index = _items.indexWhere((i) => i.productId == productId);
    if (index < 0) return;
    if (qty <= 0) {
      _items.removeAt(index);
    } else {
      final existing = _items[index];
      _items[index] = CartItem(
        productId: existing.productId,
        name: existing.name,
        qty: qty,
        unitPrice: existing.unitPrice,
        discount: existing.discount,
        sku: existing.sku,
        itemType: existing.itemType,
        image: existing.image,
        weightQty: existing.weightQty,
        itemTax: existing.itemTax,
        loyaltyPoints: existing.loyaltyPoints,
        variationId: existing.variationId,
        isEbtEligible: existing.isEbtEligible,
      );
    }
    unawaited(_publishAndNotify());
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    unawaited(_publishAndNotify());
  }

  /// Preferred: full cart + totals + store from order panel
  Future<void> replaceFromOrderItems({
    required int? orderId,
    required List<Map<String, dynamic>> orderItems,
    double tax = 0,
    double orderDiscount = 0,
    double merchantDiscount = 0,
    double cashbackFee = 0,
    double netPayable = 0,
    double? grossTotal,
    bool isPayment = false,
    bool summaryEnabled = false,
    String? orderDate,
    String? orderTime,
  }) async {
    _orderId = orderId;
    _items
      ..clear()
      ..addAll(orderItems.map(CartItem.fromOrderItem));
    _tax = tax;
    _orderDiscount = orderDiscount;
    _merchantDiscount = merchantDiscount;
    _cashbackFee = cashbackFee;
    _netPayable = netPayable;
    _screen = isPayment
        ? 'PAYMENT'
        : (_items.isEmpty ? 'IDLE' : 'CART');

    final store = await CfdStorePayload.load();

    final state = CartState(
      sessionId: 'ORDER-${orderId ?? 0}',
      sequence: 0,
      screen: _screen,
      items: List.unmodifiable(_items),
      tax: _tax,
      message: isPayment ? 'Please complete payment' : null,
      orderId: orderId,
      subtotalOverride: grossTotal ?? 0,
      orderDiscount: _orderDiscount,
      merchantDiscount: _merchantDiscount,
      cashbackFee: _cashbackFee,
      netPayable: _netPayable,
      totalItems: _items.fold(0, (s, i) => s + i.qty),
      orderDate: orderDate,
      orderTime: orderTime,
      summaryEnabled: summaryEnabled,
      storeId: store.storeId,
      storeName: store.storeName,
      storeLogoUrl: store.storeLogoUrl,
      storeBaseUrl: store.storeBaseUrl,
      slideshowUrls: store.slideshowUrls,
    );
    await messagingService.publishState(state);
    notifyListeners();
  }

  Future<void> publishWelcome() async {
    final store = await CfdStorePayload.load();
    _screen = 'WELCOME';
    await messagingService.publishState(
      CartState(
        sessionId: 'WELCOME',
        sequence: 0,
        screen: 'WELCOME',
        items: const [],
        storeId: store.storeId,
        storeName: store.storeName,
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
      ),
    );
    notifyListeners();
  }

  void goToPayment(double total) {
    _screen = 'PAYMENT';
    _netPayable = total;
    messagingService.publishScreen(
      'PAYMENT',
      total: total,
      message: 'Please complete payment',
    );
    notifyListeners();
  }

  void completeSale(double total) {
    _screen = 'SUCCESS';
    messagingService.publishScreen(
      'SUCCESS',
      total: total,
      message: 'Thank you!',
    );
    _items.clear();
    notifyListeners();
  }

  Future<void> resetToIdle() async {
    _screen = 'IDLE';
    _items.clear();
    _orderId = null;
    final store = await CfdStorePayload.load();
    await messagingService.publishState(
      CartState(
        sessionId: 'IDLE',
        sequence: 0,
        screen: 'IDLE',
        items: const [],
        storeId: store.storeId,
        storeName: store.storeName,
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
      ),
    );
    notifyListeners();
  }

  Future<void> _publishAndNotify() async {
    final store = await CfdStorePayload.load();
    final state = CartState(
      sessionId: 'ORDER-${_orderId ?? 0}',
      sequence: 0,
      screen: _screen,
      items: List.unmodifiable(_items),
      tax: _tax,
      orderId: _orderId,
      orderDiscount: _orderDiscount,
      merchantDiscount: _merchantDiscount,
      cashbackFee: _cashbackFee,
      netPayable: _netPayable,
      totalItems: _items.fold(0, (s, i) => s + i.qty),
      storeId: store.storeId,
      storeName: store.storeName,
      storeLogoUrl: store.storeLogoUrl,
      storeBaseUrl: store.storeBaseUrl,
      slideshowUrls: store.slideshowUrls,
    );
    await messagingService.publishState(state);
    notifyListeners();
  }
}

void unawaited(Future<void> f) {}