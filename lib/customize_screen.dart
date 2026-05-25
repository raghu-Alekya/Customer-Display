import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keyos_app/widgets/kiosk_header_widgets.dart';

import 'cart_manger.dart';
import 'model/addon_model.dart';
import 'model/product model.dart';
import 'repository/addon_repository.dart';

class CustomizeScreen extends StatefulWidget {
  final ProductModel product;
  final List<AddonModel> addons;
  final String orderType;

  final int initialQty;
  final bool isEditFromCart;
  final bool openedFromSearch;

  const CustomizeScreen({
    super.key,
    required this.product,
    required this.addons,
    required this.orderType,
    this.initialQty = 1,
    this.isEditFromCart = false,
    this.openedFromSearch = false,
  });

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  int qty = 1;
  late List<AddonModel> addons;
  bool isLoading = false;
  String? loadError;
  // final int initialQty;
  final int minQty = 1;
  final int maxQty = 99;


  @override
  void initState() {
    super.initState();
    qty = widget.initialQty;
    addons = List<AddonModel>.from(widget.addons);
    _loadAddons();

    // if (addons.isEmpty) {
    //   _loadAddons();
    // }
  }

  Future<void> _loadAddons() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      // IDs already selected when opening from cart
      final selectedIds = widget.addons.map((a) => a.id).toSet();

      final fetched = await AddonRepository().getAddons(
        productId: widget.product.id,
        token: token,
      );

      // Keep previous selections in fetched full list
      for (final addon in fetched) {
        addon.isSelected = selectedIds.contains(addon.id);
      }

      if (!mounted) return;
      setState(() {
        addons = fetched;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = "Failed to load addons";
      });
    }
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
  Widget build(BuildContext context) {
    const horizontalInset = 16.0;
    const cardPadding = 12.0;
    /// Same as item row: 40 (thumb) + 8 (gap).
    const tableLeadWidth = 48.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          const SizedBox(height: 20),

          /// 🔶 TOP BAR (same horizontal inset as card content area)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                KioskMenuBackButton(
                  label: 'Menu',
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  "Customize",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                KioskOrderTypeChip(orderType: widget.orderType),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// 🔹 MAIN CARD — horizontal margin matches top bar; inner [cardPadding] aligns list with header grid
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                horizontalInset,
                0,
                horizontalInset,
                horizontalInset,
              ),
              // padding: const EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 HEADER — spacer + flex match item row below (4+3+2+2)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E2CC), // ✅ SAME AS ITEM CARD
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: tableLeadWidth),
                        const Expanded(
                          flex: 4,
                          child: Text(
                            "Item Name",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Center(
                            child: Text(
                              "Qty",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Sub Total",
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Total",
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 10),

                  /// 🔹 ITEM CARD
                  Container(
                    padding: const EdgeInsets.all(18),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E2CC), // 🔥 beige
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: Colors.orange.shade100,
                            child: (widget.product.imageUrl != null &&
                                widget.product.imageUrl!.trim().isNotEmpty)
                                ? Image.network(
                              widget.product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.fastfood, size: 18),
                            )
                                : const Icon(Icons.fastfood, size: 18),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          flex: 4,
                          child: Text(widget.product.name),
                        ),

                        /// 🔹 QTY
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: qty > minQty ? () => setState(() => qty--) : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: qty > minQty
                                          ? const Color(0xFFFF7A00) // same as add button
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: qty > minQty
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text("$qty"),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: qty < maxQty ? () => setState(() => qty++) : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7A00),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 18,
                                      color: qty < maxQty
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "\$${basePrice.toStringAsFixed(2)}",
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "\$${totalPrice.toStringAsFixed(2)}",
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 CUSTOMIZE
                  if (isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (loadError != null)
                    Expanded(
                      child: Center(
                        child: Text(
                          loadError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (addons.isNotEmpty) ...[
                      const Text(
                        "Customize",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const Text("Choose one or more add ons"),

                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
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
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            height: 50,
                                            width: 50,
                                            color: Colors.orange.shade100,
                                            child: (addon.imageUrl != null &&
                                                addon.imageUrl!.trim().isNotEmpty)
                                                ? Image.network(
                                              addon.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.fastfood),
                                            )
                                                : const Icon(Icons.fastfood),
                                          ),
                                        ),
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
                                      "\$${addon.price.toStringAsFixed(2)}",
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
                        ),
                      ),
                    ]
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                      final selectedAddons =
                      addons.where((a) => a.isSelected).toList();

                      // EDIT MODE
                      if (widget.isEditFromCart) {
                        Navigator.pop(context, {
                          "qty": qty,
                          "addons": selectedAddons,
                        });
                        return;
                      }

                      // ADD MODE
                      final existingIndex =
                      CartManager.cartItems.indexWhere((item) {
                        final product = item["product"];
                        if (product.id != widget.product.id) return false;

                        final List existingAddons = item["addons"] as List;

                        if (existingAddons.length != selectedAddons.length) {
                          return false;
                        }

                        final existingIds =
                        existingAddons.map((a) => a.id).toSet();

                        final newIds =
                        selectedAddons.map((a) => a.id).toSet();

                        return existingIds.length == newIds.length &&
                            existingIds.containsAll(newIds);
                      });

                      if (existingIndex >= 0) {
                        CartManager.cartItems[existingIndex]["qty"] += qty;
                      } else {
                        CartManager.addItem(
                          product: widget.product,
                          addons: selectedAddons,
                          qty: qty,
                        );
                      }

                      if (widget.openedFromSearch) {
                        Navigator.pop(context, true); // close customize
                        Navigator.pop(context);       // close search -> category
                      } else {
                        Navigator.pop(context, true); // category -> back to category only
                      }
                    },
                    child: const Text(
                      "Add to Cart",
                      style: TextStyle(color: Colors.white),
                    ),
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