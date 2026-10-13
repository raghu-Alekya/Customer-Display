import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Constants/text.dart';
import '../Helper/Extentions/theme_notifier.dart';
import 'widget_quantity_input_control.dart';

class VariantsDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> variations;
  final Function(Map<String, dynamic>, int)? onAddVariant;

  const VariantsDialog({
    Key? key,
    required this.title,
    required this.variations,
    this.onAddVariant,
  }) : super(key: key);

  @override
  State<VariantsDialog> createState() => _VariantsDialogState();
}

class _VariantsDialogState extends State<VariantsDialog> with SingleTickerProviderStateMixin {
  Map<int, int> variantQuantities = {}; // Track quantities for each variant
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    // Initialize quantities for all variants
    for (int i = 0; i < widget.variations.length; i++) { //Build 1.1.36
      variantQuantities[i] = 0;
    }
    if (kDebugMode) {
      print("VariantsDialog - Initialized with ${widget.variations.length} variations");
    }
  }
  bool get isAnyVariantSelected {
    return variantQuantities.values.any((qty) => qty > 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    if (kDebugMode) {
      print("VariantsDialog - Disposed");
    }
    super.dispose();
  }

  Future<void> closeDialog() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.pop(context);
    } else {
      if (kDebugMode) {
        print("VariantsDialog - Context not mounted, skipping pop");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Stack(
      children: [
        // Background Blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.2),
          ),
        ),

        // Dialog Center
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.popUpsBackground : Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800, minHeight: 500),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),

                      // Row ➔ Column (left) + Close button (right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                TextConstants.chooseVariants,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark :Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: closeDialog,
                            child: const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              radius: 20,
                              child: Icon(Icons.close, size: 24, color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Variant List - Using GridView for 3 items per row
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        height: 400, // Fixed height for the grid
                        child: Scrollbar(
                          controller: _scrollController,
                          scrollbarOrientation: ScrollbarOrientation.right,
                          thumbVisibility: true,
                          thickness: 8.0,
                          interactive: false,
                          radius: const Radius.circular(8),
                          trackVisibility: true,
                          child: GridView.builder( //Build 1.1.36: updated variations dialog UI because previous ui getting only horizontal infinite list
                            shrinkWrap: true,
                            controller: _scrollController,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, // 3 items per row
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.78, // Adjusted for better layout
                            ),
                            itemCount: widget.variations.length,
                            itemBuilder: (context, index) {
                              final variant = widget.variations[index];
                              final quantity = variantQuantities[index] ?? 0;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground :Colors.white,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      spreadRadius: 2,
                                      offset: Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 140,
                                        width: double.infinity,
                                        child: Image.network(
                                          variant["image"] ?? "",
                                          height: 140,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 140,
                                              color: themeHelper.themeMode == ThemeMode.dark
                                                  ? Colors.white70
                                                  : Colors.grey.shade300,
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      variant["name"],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${TextConstants.currencySymbol}${variant["price"]}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    quantity > 0
                                        ? QuantityControl(
                                      controller: TextEditingController(text: quantity.toString()),
                                      quantity: quantity,
                                      onDecrement: (newQuantity) {
                                        setState(() {
                                          // Reset all quantities to 0
                                          variantQuantities.forEach((key, _) { //Build #1.0.74: fixed -  multiple products adding
                                            variantQuantities[key] = 0;
                                          });
                                          // Set the selected variant to new quantity
                                          variantQuantities[index] = newQuantity;
                                        });
                                        if (kDebugMode) {
                                          print("VariantsDialog - Quantity decremented to $newQuantity for variant ${variant['name']}");
                                        }
                                      },
                                      onIncrement: (newQuantity) {
                                        setState(() {
                                          // Reset all quantities to 0
                                          variantQuantities.forEach((key, _) { //Build #1.0.74: fixed - multiple products adding
                                            variantQuantities[key] = 0;
                                          });
                                          // Set the selected variant to new quantity
                                          variantQuantities[index] = newQuantity;
                                        });
                                        if (kDebugMode) {
                                          print("VariantsDialog - Quantity incremented to $newQuantity for variant ${variant['name']}");
                                        }
                                      },
                                    )
                                        : SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () {

                                          setState(() {
                                            // Reset all quantities to 0
                                            variantQuantities.forEach((key, _) {
                                              variantQuantities[key] = 0;
                                            });
                                            // Set the selected variant to 1
                                            variantQuantities[index] = 1;
                                          });
                                          if (kDebugMode) {
                                            print("VariantsDialog - Selected variant: ${variant['name']}, ID: ${variant['id']}");
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                          side: const BorderSide(color: Color(0xFF1BA672)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          TextConstants.addText,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1BA672),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Done Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: (_isLoading || !isAnyVariantSelected)
                              ? null
                              : () async {
                            setState(() {
                              _isLoading = true;
                            });

                            int? selectedIndex;

                            variantQuantities.forEach((index, qty) {
                              if (qty > 0) {
                                selectedIndex = index;
                              }
                            });

                            if (selectedIndex != null) {
                              await widget.onAddVariant?.call(
                                widget.variations[selectedIndex!],
                                variantQuantities[selectedIndex!]!,
                              );
                              await closeDialog();
                            }

                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF1BA672),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            TextConstants.done,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}