class CartManager {
  static final List<Map<String, dynamic>> cartItems = [];

  static String _lineId() => DateTime.now().microsecondsSinceEpoch.toString();

  static void addItem({
    required dynamic product,
    required List addons,
    required int qty,
  }) {
    cartItems.add({
      "lineId": _lineId(),
      "product": product,
      "addons": addons,
      "qty": qty,
    });
  }

  static void updateItemByLineId({
    required String lineId,
    required int qty,
    required List addons,
  }) {
    final i = cartItems.indexWhere((e) => e["lineId"] == lineId);
    if (i >= 0) {
      cartItems[i]["qty"] = qty;
      cartItems[i]["addons"] = addons;
    }
  }

  static void removeAt(int index) => cartItems.removeAt(index);
}