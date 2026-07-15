import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
// import 'package:kiosk/_app/widgets/payment_method.dart';
import 'package:kiosk/widgets/payment_method.dart';
import 'cart_manger.dart';
import 'customize_screen.dart';
import 'helper.dart';
import 'model/addon_model.dart';

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
  bool get hasItems => CartManager.cartItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final containerPadding = isDesktop ? 20.0 : isTablet ? 16.0 : 12.0;
    final itemPadding = isDesktop ? 16.0 : isTablet ? 14.0 : 10.0;

    final titleFont = isDesktop ? 18.0 : isTablet ? 22.0 : 20.0;
    final normalFont = isDesktop ? 15.0 : isTablet ? 14.0 : 12.0;
    final smallFont = isDesktop ? 13.0 : isTablet ? 12.0 : 11.0;

    final iconSize = isDesktop ? 24.0 : isTablet ? 22.0 : 20.0;
    final deleteIconSize = isDesktop ? 26.0 : isTablet ? 22.0 : 20.0;

    final spacing = isDesktop ? 16.0 : isTablet ? 12.0 : 8.0;
    final actionSpacing = isDesktop ? 30.0 : isTablet ? 24.0 : 18.0;

    final borderRadius = isDesktop ? 16.0 : isTablet ? 14.0 : 12.0;


    final headerHeight = Responsive.isDesktop(context)
        ? 55.0
        : Responsive.isTablet(context)
        ? 50.0
        : 45.0;

    final horizontalPadding = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 16.0
        : 12.0;
    final billRadius = Responsive.isDesktop(context)
        ? 16.0
        : Responsive.isTablet(context)
        ? 14.0
        : 12.0;

    final billPadding = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 16.0
        : 12.0;

    final billSpacing = Responsive.isDesktop(context)
        ? 10.0
        : Responsive.isTablet(context)
        ? 8.0
        : 6.0;

    final blurRadius = Responsive.isDesktop(context)
        ? 12.0
        : Responsive.isTablet(context)
        ? 10.0
        : 8.0;
    final itemImageSize = Responsive.isDesktop(context)
        ? 70.0
        : Responsive.isTablet(context)
        ? 60.0
        : 50.0;

    final itemNameFont = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 16.0
        : 14.0;

    final priceFont = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 16.0
        : 14.0;

    final addonFont = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 13.0
        : 12.0;

    final qtyFont = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 16.0
        : 14.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔷 HEADER
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SizedBox(
                height: headerHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// Left - Menu Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: KioskMenuBackButton(
                        label: 'Menu',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    /// Center - Title
                    Center(
                      child: Text(
                        "Your Cart",
                        style: TextStyle(
                          fontSize: titleFont,
                          fontWeight: FontWeight.w900
                        ),
                      ),
                    ),

                    /// Right - Order Type
                    Align(
                      alignment: Alignment.centerRight,
                      child: KioskOrderTypeChip(
                        orderType: widget.orderType,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 26),
            //
            /// Header OUTSIDE
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: containerPadding,
                vertical: spacing,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cart Summary",
                    style: TextStyle(
                      fontSize: titleFont,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        CartManager.cartItems.clear();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.isDesktop(context)
                            ? 16
                            : Responsive.isTablet(context)
                            ? 14
                            : 12,
                        vertical: Responsive.isDesktop(context)
                            ? 10
                            : Responsive.isTablet(context)
                            ? 8
                            : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDF2626),
                        borderRadius: BorderRadius.circular(
                          Responsive.isDesktop(context)
                              ? 8
                              : Responsive.isTablet(context)
                              ? 7
                              : 6,
                        ),
                      ),
                      child: Text(
                        "Clear Cart",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.isDesktop(context)
                              ? 15
                              : Responsive.isTablet(context)
                              ? 14
                              : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),


            /// 🔷 CART CARD
            Expanded(
              child: Container(
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  children: [

                    // /// HEADER
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //
                    //     /// 🧾 CART SUMMARY
                    //     Text(
                    //       "Cart Summary",
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         fontSize: titleFont,// 👈 increased size
                    //       ),
                    //     ),
                    //
                    //     /// 🗑 CLEAR CART
                    //     GestureDetector(
                    //       onTap: () {
                    //         setState(() {
                    //           CartManager.cartItems.clear();
                    //         });
                    //       },
                    //       child: Text(
                    //         "Clear Cart",
                    //         style: TextStyle(
                    //           color: const Color(0xFFDF2626),
                    //           fontSize: normalFont,
                    //           decoration: TextDecoration.underline,
                    //           decorationColor: const Color(0xFFDF2626), // underline color
                    //           fontWeight: FontWeight.w500,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    //
                    // SizedBox(height: spacing),
                    /// COLUMN HEADERS
                    Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            "Item Name",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              "Qty",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Sub Total",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              "Action",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),
                    const DottedLine(
                      dashLength: 6,
                      dashGapLength: 4,
                      lineThickness: 1,
                      dashColor: Colors.grey,
                    ),
                    const SizedBox(height: 15),
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
                            margin: EdgeInsets.only(bottom: spacing),
                            padding: EdgeInsets.all(itemPadding),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [

                                /// ITEM DETAILS
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _cartItemImage(
                                            product.imageUrl,
                                            size: itemImageSize,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: normalFont,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // ✅ ADDONS NAME (existing)
                                      if (addons.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: addons.map<Widget>((addon) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFDEFE6),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      addon.name,
                                                      style: TextStyle(fontSize: smallFont, color: Colors.black87),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          addons.remove(addon);
                                                        });
                                                      },
                                                      child: const Icon(
                                                        Icons.cancel,
                                                        size: 14,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),

                                      // // ✅ ADDON PRICES (NEW - like your image)
                                      // if (addons.isNotEmpty)
                                      //   Padding(
                                      //     padding: const EdgeInsets.only(top: 4),
                                      //     child: Column(
                                      //       crossAxisAlignment: CrossAxisAlignment.start,
                                      //       children: addons.map<Widget>((addon) {
                                      //         return Text(
                                      //           "\$${addon.price}",
                                      //           style: const TextStyle(
                                      //             fontSize: 11,
                                      //             color: Colors.grey,
                                      //             decoration: TextDecoration.lineThrough, // optional
                                      //           ),
                                      //         );
                                      //       }).toList(),
                                      //     ),
                                      //   ),

                                      // ✅ CUSTOMIZE BUTTON (IMPROVED)
                                      if (addons.isNotEmpty)
                                        GestureDetector(
                                          onTap: () async {
                                            final result = await showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  backgroundColor: Colors.transparent,
                                                  insetPadding: EdgeInsets.symmetric(
                                                    horizontal: Responsive.isDesktop(context)
                                                        ? 120
                                                        : Responsive.isTablet(context)
                                                        ? 70
                                                        : 20,
                                                    vertical: Responsive.isDesktop(context)
                                                        ? 40
                                                        : Responsive.isTablet(context)
                                                        ? 30
                                                        : 20,
                                                  ),
                                                  child: SizedBox(
                                                    width: Responsive.isDesktop(context)
                                                        ? MediaQuery.of(context).size.width * 0.85
                                                        : Responsive.isTablet(context)
                                                        ? MediaQuery.of(context).size.width * 0.70
                                                        : MediaQuery.of(context).size.width * 0.65,
                                                    height: Responsive.isDesktop(context)
                                                        ? MediaQuery.of(context).size.height * 0.65
                                                        : Responsive.isTablet(context)
                                                        ? MediaQuery.of(context).size.height * 0.60
                                                        : MediaQuery.of(context).size.height * 0.60,
                                                    child: CustomizeScreen(
                                                      product: product,
                                                      addons: List<AddonModel>.from(addons),
                                                      orderType: widget.orderType,
                                                      initialQty: qty,
                                                      isEditFromCart: true,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );

                                            if (result != null && result is Map<String, dynamic>) {
                                              setState(() {
                                                item["qty"] = result["qty"] ?? item["qty"];
                                                item["addons"] = result["addons"] ?? item["addons"];
                                              });
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              "Customize",
                                              style: TextStyle(
                                                fontSize: smallFont,
                                                color: Colors.orange,
                                                decoration: TextDecoration.underline,
                                                decorationColor: Colors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                /// QTY
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _qty(
                                        "-",
                                            () {
                                          if (qty > 1) {
                                            setState(() => item["qty"]--);
                                          }
                                        },
                                        enabled: qty > 1,
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: spacing * .6,
                                        ),
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
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "\$${finalPrice.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (addons.isNotEmpty)
                                        ...addons.map((addon) {
                                          return Text(
                                            "\$${addon.price}",
                                            style: TextStyle(
                                              fontSize: smallFont,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                ),
                                SizedBox(width: actionSpacing),

                                /// DELETE
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      size: deleteIconSize,
                                      color: const Color(0xFFE01F1F), // red color
                                    ),
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
                    // Container(
                    //   width: double.infinity,
                    //   padding: EdgeInsets.all(billPadding),
                    //   margin: EdgeInsets.only(top: billSpacing),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white,
                    //     borderRadius: BorderRadius.circular(billRadius),
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: Colors.black.withOpacity(0.05),
                    //         blurRadius: blurRadius,
                    //         offset: const Offset(0, 3),
                    //       ),
                    //     ],
                    //   ),
                    //   child: Column(
                    //     children: [
                    //       _billRow("Sub Total", total),
                    //
                    //       SizedBox(height: billSpacing),
                    //
                    //       _billRow("Tax", tax),
                    //
                    //       Divider(
                    //         height: billSpacing * 3,
                    //         thickness: 1,
                    //       ),
                    //
                    //       _billRow(
                    //         "Net Payable",
                    //         grandTotal,
                    //         isTotal: true,
                    //       ),
                    //     ],
                    //   ),
                    // )
                  ],
                ),
              ),
            ),


            const SizedBox(height: 152),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: billPadding,
                vertical: Responsive.isDesktop(context)
                    ? 28
                    : Responsive.isTablet(context)
                    ? 54
                    : 40,
              ),
              margin: EdgeInsets.only(top: billSpacing),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(billRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: blurRadius,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _billRow("Sub Total", total),

                  SizedBox(height: 20),

                  _billRow("Tax", tax),

                  Divider(
                    height: 24,
                    thickness: 1,
                  ),

                  _billRow(
                    "Net Payable",
                    grandTotal,
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 78),



            /// 🔶 CONFIRM BUTTON
            GestureDetector(
              onTap: hasItems
                  ? () {
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
              }
                  : null,
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: hasItems ? const Color(0xFFFF8A00) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Confirm Order",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasItems ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartItemImage(String? imageUrl, {required double size}) {
    final borderRadius = Responsive.isDesktop(context)
        ? 12.0
        : Responsive.isTablet(context)
        ? 10.0
        : 8.0;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          Icons.fastfood_rounded,
          size: size * 0.5,
          color: Colors.black54,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.fastfood_rounded,
            size: size * 0.5,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  /// 🔘 QTY BUTTON
  Widget _qty(
      String text,
      VoidCallback onTap, {
        bool enabled = true,
      }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 36,
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFFFE0C2)
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: enabled
                ? Colors.orange
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  /// 🧾 BILL ROW
  Widget _billRow(
      String title,
      double value, {
        bool isTotal = false,
      }) {
    final fontSize = Responsive.isDesktop(context)
        ? (isTotal ? 28.0 : 15.0)
        : Responsive.isTablet(context)
        ? (isTotal ? 24.0 : 18.0)
        : (isTotal ? 24.0 : 18.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight:
            isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight:
            isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal
                ? const Color(0xFFFF7A00)
                : Colors.black,
          ),
        ),
      ],
    );
  }
}