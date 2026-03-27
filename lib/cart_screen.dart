import 'package:flutter/material.dart';
import 'package:keyos_app/widgets/payment_method.dart';
// import 'cart_manager.dart';
import 'cart_manger.dart';

class CartScreen extends StatefulWidget {
  final String orderType;
  const CartScreen({super.key,required this.orderType});

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

      double addonTotal = 0;
      for (var a in addons) {
        addonTotal += a.price;
      }

      t += (price + addonTotal) * qty;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔷 HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                /// 🔙 BACK BUTTON (CLICKABLE)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // ✅ go back to category screen
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          "Back to Menu",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                /// 🧾 TITLE
                const Text(
                  "YOUR CART",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                /// 🍽 ORDER TYPE
                const Text("Order Type : Dine In"),
              ],
            ),

            const SizedBox(height: 10),

            /// 🔷 CART CONTAINER
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [

                    /// 🔹 HEADER ROW
                    Row(
                      children: const [
                        Expanded(flex: 5, child: Text("Item Name")),
                        Expanded(flex: 2, child: Text("Qty")),
                        Expanded(flex: 2, child: Text("Sub total")),
                        Expanded(flex: 2, child: Text("Action")),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// 🔹 ITEMS
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

                          double addonTotal = 0;
                          for (var a in addons) {
                            addonTotal += a.price;
                          }

                          double finalPrice = (price + addonTotal) * qty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E2CC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [

                                /// ITEM
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),

                                      /// ADDONS
                                      if (addons.isNotEmpty)
                                        Text(
                                          addons
                                              .map((a) => a.name)
                                              .join(", "),
                                          style:
                                          const TextStyle(fontSize: 10),
                                        ),

                                      const SizedBox(height: 4),

                                      /// CUSTOM TAG
                                      if (addons.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.orange),
                                            borderRadius:
                                            BorderRadius.circular(4),
                                          ),
                                          child: const Text("Customized",
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange)),
                                        )
                                    ],
                                  ),
                                ),

                                /// QTY
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      _qty("-", () {
                                        if (qty > 1) {
                                          setState(() {
                                            item["qty"]--;
                                          });
                                        }
                                      }),
                                      Padding(
                                        padding:
                                        const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text("$qty"),
                                      ),
                                      _qty("+", () {
                                        setState(() {
                                          item["qty"]++;
                                        });
                                      }),
                                    ],
                                  ),
                                ),

                                /// PRICE
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      "₹${finalPrice.toStringAsFixed(0)}"),
                                ),

                                /// DELETE
                                Expanded(
                                  flex: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        CartManager.cartItems.removeAt(index);
                                      });
                                    },
                                    child: const Icon(Icons.delete),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    /// 🔷 BILL
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          _row("Sub total", total),
                          _row("CGST (2.5%)", total * 0.025),
                          _row("SGST (2.5%)", total * 0.025),
                          const Divider(),
                          _row("Total", total * 1.05, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            /// 🔶 BUTTON
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentMethods(orderType: ""),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Proceed Payment",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _qty(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0C2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.orange)),
      ),
    );
  }

  Widget _row(String title, double value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.orange : Colors.black,
          ),
        ),
      ],
    );
  }
}