import 'package:flutter/material.dart';
import 'package:keyos_app/widgets/payment_method.dart';
import 'cart_manger.dart';

class CartScreen extends StatefulWidget {
  final String orderType;
  const CartScreen({super.key, required this.orderType});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {

  double get total {
    double t = 0;
    for (var item in CartManager.cartItems) {
      final product = item["product"];
      final qty = item["qty"];
      final addons = item["addons"] as List;

      double price =
          double.tryParse(product.price.replaceAll("₹", "")) ?? 0;

      double addonTotal = addons.fold(0, (sum, a) => sum + a.price);

      t += (price + addonTotal) * qty;
    }
    return t;
  }

  double get tax => total * 0.091;
  double get grandTotal => total + tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔷 HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                /// BACK BUTTON
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF8A00), // ✅ same as text color
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min, // 👈 important
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 14,
                          color: Color(0xFFFF8A00),
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Menu",
                          style: TextStyle(
                            color: Color(0xFFFF8A00),
                            fontWeight: FontWeight.w600, // 👈 better UI
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Text(
                  "Your Cart (2)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // 👈 important
                    children: [
                      /// 🔵 DOT
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF506796), // ✅ your color
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      /// 📝 TEXT
                      Text(
                        widget.orderType.isEmpty ? "Dine-In" : widget.orderType,
                        style: const TextStyle(
                          color: Color(0xFF506796), // ✅ your color
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 16),

            /// 🔷 CART CARD
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  children: [

                    /// HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        /// 🧾 CART SUMMARY
                        const Text(
                          "Cart Summary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16, // 👈 increased size
                          ),
                        ),

                        /// 🗑 CLEAR CART
                        Text(
                          "ClearCart",
                          style: const TextStyle(
                            color: Color(0xFFDF2626),
                            fontSize: 14, // 👈 increased size
                            decoration: TextDecoration.underline, // ✅ underline
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    /// COLUMN HEADERS
                    Row(
                      children: const [
                        Expanded(flex: 4, child: Text("Item Name")),
                        Expanded(flex: 2, child: Text("Qty")),
                        Expanded(flex: 2, child: Text("Sub Total")),
                        Expanded(flex: 1, child: Text("action")),
                      ],
                    ),

                    const SizedBox(height: 5),

                    /// ITEMS
                    Expanded(
                      child: ListView.builder(
                        itemCount: CartManager.cartItems.length,
                        itemBuilder: (context, index) {

                          final item = CartManager.cartItems[index];
                          final product = item["product"];
                          final qty = item["qty"];
                          final addons = item["addons"] as List;

                          double price =
                              double.tryParse(product.price.replaceAll("₹", "")) ?? 0;

                          double addonTotal =
                          addons.fold(0, (sum, a) => sum + a.price);

                          double finalPrice = (price + addonTotal) * qty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [

                                /// ITEM DETAILS
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      Text(product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),

                                      if (addons.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            addons.map((a) => a.name).join(", "),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ),

                                      if (addons.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.orange),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "Customize",
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange),
                                          ),
                                        )
                                    ],
                                  ),
                                ),

                                /// QTY
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      _qty("-", () {
                                        if (qty > 1) {
                                          setState(() => item["qty"]--);
                                        }
                                      }),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text("$qty"),
                                      ),
                                      _qty("+", () {
                                        setState(() => item["qty"]++);
                                      }),
                                    ],
                                  ),
                                ),

                                /// PRICE
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      "\$${finalPrice.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),

                                /// DELETE
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        CartManager.cartItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    /// 🔷 BILL SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          _billRow("Sub Total", total),
                          const SizedBox(height: 6),
                          _billRow("Tax (9.1%)", tax),
                          const Divider(height: 20),
                          _billRow("Net Payable", grandTotal, isTotal: true),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// 🔶 CONFIRM BUTTON
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentMethods(
                      orderType: widget.orderType,
                      subtotal: total,
                      tax: tax,
                      total: grandTotal,
                    ),
                  ),
                );
              },
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Confirm Order",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// 🔘 QTY BUTTON
  Widget _qty(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36, // 👈 increased size
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0C2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18, // 👈 bigger icon
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }

  /// 🧾 BILL ROW
  Widget _billRow(String title, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.orange : Colors.grey[700],
          ),
        ),
        Text(
        "\$${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.orange : Colors.black,
          ),
        ),
      ],
    );
  }
}