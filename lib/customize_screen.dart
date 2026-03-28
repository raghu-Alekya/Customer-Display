import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cart_manger.dart';
import 'model/addon_model.dart';
import 'model/product model.dart';

class CustomizeScreen extends StatefulWidget {
  final ProductModel product;
  final List<AddonModel> addons;
  final String orderType;

  const CustomizeScreen({
    super.key,
    required this.product,
    required this.addons,
    required this.orderType,
  });

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  int qty = 1;
  late List<AddonModel> addons;

  @override
  void initState() {
    super.initState();
    addons = widget.addons;
  }

  double get basePrice {
    return double.tryParse(
      widget.product.price.replaceAll("₹", ""),
    ) ??
        0;
  }

  double get addonsTotal {
    return addons
        .where((a) => a.isSelected)
        .fold(0, (sum, item) => sum + item.price);
  }

  double get totalPrice => (basePrice + addonsTotal) * qty;

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          const SizedBox(height: 20),

          /// 🔶 TOP BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8), // 👈 ripple shape
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF9B17), // ✅ same as text color
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.arrow_back_ios,
                          size: 14,
                          color: Color(0xFFFF9B17),
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Menu",
                          style: TextStyle(
                            color: Color(0xFFFF9B17),
                            fontWeight: FontWeight.w600, // 👈 better UI
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text("Customize",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          color: Color(0xFF506796), // ✅ same as text color
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      /// 📝 TEXT
                      Text(
                        widget.orderType,
                        style: const TextStyle(
                          color: Color(0xFF506796), // ✅ your color
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// 🔹 MAIN CARD
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 HEADER
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E2CC), // ✅ SAME AS ITEM CARD
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 5,
                          child: Text(
                            "Item Name",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Qty",
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          flex: 2,
                          child: Text(
                            "Sub Total",
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Final",
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 10),

                  /// 🔹 ITEM CARD
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E2CC), // 🔥 beige
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, size: 18),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          flex: 4,
                          child: Text(widget.product.name),
                        ),

                        /// 🔹 QTY
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (qty > 1) setState(() => qty--);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child:
                                  const Icon(Icons.remove, size: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text("$qty"),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() => qty++);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7A00),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Icon(Icons.add,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text("\$${basePrice.toStringAsFixed(2)}"),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text("\$${totalPrice.toStringAsFixed(2)}"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 CUSTOMIZE
                  const Text("Customize",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Choose one or more add ons"),

                  const SizedBox(height: 10),

                  /// 🔹 ADDONS GRID
                  Row(
                    children: List.generate(addons.length, (index) {
                      final addon = addons[index];
                      final isSelected = addon.isSelected;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            addon.isSelected = !isSelected;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(10),
                          width: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF7A00)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              /// 🔥 IMAGE + CHECK ICON
                              Stack(
                                children: [
                                  Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.fastfood),
                                  ),

                                  /// ✅ CHECK ICON (LIKE YOUR IMAGE)
                                  if (isSelected)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF7A00),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              Text(
                                addon.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? const Color(0xFFFF7A00)
                                      : Colors.black,
                                ),
                              ),

                              Text(
                                "₹${addon.price}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  )
                ],
              ),
            ),
          ),

          /// 🔻 BOTTOM BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF7A00)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ ADD THIS
                      ),
                    ),
                    child: const Text(
                      "Check Out",
                      style: TextStyle(color: Color(0xFFFF7A00)),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ ADD THIS
                      ),
                    ),
                    onPressed: () {
                      /// 👉 Get selected addons
                      final selectedAddons =
                      addons.where((a) => a.isSelected).toList();

                      /// 👉 Add to global cart
                      CartManager.cartItems.add({
                        "product": widget.product,
                        "addons": selectedAddons,
                        "qty": qty,
                      });

                      print("🛒 Cart Count: ${CartManager.cartItems.length}");

                      /// 👉 Go back
                      Navigator.pop(context);
                    },
                    child: const Text("Add to Cart"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}