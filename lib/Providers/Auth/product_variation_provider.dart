import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Blocs/Orders/order_bloc.dart';
import 'package:pinaka_pos/Blocs/Search/product_search_bloc.dart';
import 'package:pinaka_pos/Database/order_panel_db_helper.dart';
import 'package:pinaka_pos/Repositories/Orders/order_repository.dart';
import 'package:pinaka_pos/Repositories/Search/product_search_repository.dart';
import '../../Constants/misc_features.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Helper/api_response.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Search/product_variation_model.dart';
import '../../Widgets/widget_logs_toast.dart';
import '../../Widgets/widget_variants_dialog.dart';

class VariationPopup {
  final ProductBloc _productBloc = ProductBloc(ProductRepository());
  final OrderBloc _orderBloc = OrderBloc(OrderRepository());
  final int productId;
  final String productName;
  final OrderHelper orderHelper;
  final Function({required bool isVariant})? onProductSelected;
  StreamSubscription? _updateOrderSubscription;
  bool _isAddingItemLoading = false;

  VariationPopup(
      this.productId,
      this.productName,
      this.orderHelper, {
        this.onProductSelected,
      }) {
    _productBloc.fetchProductVariations(productId);
  }

  Future<void> showVariantDialog({required BuildContext context}) async {
    // Build #1.0.256: Start variation check timer immediately when dialog opens
    Stopwatch? variationStopwatch;
    bool? variationDone = false;
    if (Misc.enableUILogMessages) {
      variationStopwatch = Stopwatch()..start();
    }
    return showDialog(
        context: context,
        barrierDismissible: false, // Build #1.0.200: Prevent dismissing by tapping outside
        builder: (context) => AbsorbPointer(
          absorbing: _isAddingItemLoading, // Block interactions only when loading
          child: Stack(
            children: [
              StreamBuilder<APIResponse<List<ProductVariation>>>(
                stream: _productBloc.variationStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.status == Status.LOADING) { // Build #1.0.148: updated condition , no need two if's
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.status == Status.COMPLETED) {
                    if (kDebugMode) {
                      print("#### TEST variations");
                    }
                    final variations = snapshot.data!.data!;

                    if (Misc.enableUILogMessages && variationStopwatch != null) { // Build #1.0.256: It will work only misc bool value is true for testing
                      variationStopwatch.stop();
                      variationDone = true;
                      globalProcessSteps.add(ProcessStep(
                        name: TextConstants.variationCheck,
                        timeTaken: variationStopwatch.elapsedMilliseconds / 1000.0, // Approximate time for fetch
                      ));
                    }
                    if (variations.isNotEmpty) {
                      return VariantsDialog(
                        title: productName,
                        variations: variations.map((v) => {
                          "id": v.id,
                          "name": v.name,
                          "price": v.regularPrice,
                          "image": v.image.src,
                          "sku": v.sku ?? '',
                        }).toList(),
                        onAddVariant: (variant, quantity) async {
                          ///Comment below code not we are using only server order id as to check orders, skip checking db order id
                          // final order = orderHelper.orders.firstWhere(
                          //       (order) => order[AppDBConst.orderId] == orderHelper.activeOrderId,
                          //   orElse: () => {},
                          // );
                          final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
                          final dbOrderId = orderHelper.activeOrderId;
                          ///Build #1.0.128: No need to check this condition
                          // if (dbOrderId == null) {
                          //   if (kDebugMode) {
                          //     print("No active order selected");
                          //   }
                          //   ScaffoldMessenger.of(context).showSnackBar(
                          //     const SnackBar(
                          //       content: Text("No active order selected"),
                          //       backgroundColor: Colors.red,
                          //       duration: Duration(seconds: 2),
                          //     ),
                          //   );
                          //   return;
                          // }

                          _isAddingItemLoading = true;
                          _showLoaderOverlay(context);

                          try {
                            // if (serverOrderId != null) { //Build #1.0.128: No need to check this condition
                            _updateOrderSubscription?.cancel();

                            // Build #1.0.256: Measure time for adding product
                            Stopwatch? addVariationProdStopwatch;
                            if (Misc.enableUILogMessages) {
                              addVariationProdStopwatch = Stopwatch()..start(); // Start timer before verifyAge
                            }
                            _updateOrderSubscription = _orderBloc.updateOrderStream.listen(
                                  (response) async {
                                _isAddingItemLoading = false;
                                _removeLoaderOverlay();

                                if (!context.mounted) {
                                  _updateOrderSubscription?.cancel();
                                  return;
                                }
                                if (response.status == Status.LOADING) {
                                  const Center(child: CircularProgressIndicator());
                                }else
                                if (response.status == Status.COMPLETED) {
                                  if (kDebugMode) {
                                    print("Variant added to order $dbOrderId via API");
                                  }
                                  if (Misc.showDebugSnackBar) { // Build #1.0.256: Fix: No need to show toast on success
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Variant '${variant['name']}' added to order"),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                  //   Navigator.pop(context);
                                  if (Misc.enableUILogMessages && addVariationProdStopwatch != null) { // Build #1.0.256
                                    addVariationProdStopwatch.stop();
                                    globalProcessSteps.add(
                                      ProcessStep(
                                        name: TextConstants.addProductToOrder,
                                        timeTaken: addVariationProdStopwatch.elapsedMilliseconds / 1000.0,
                                      ),
                                    );
                                  }
                                  onProductSelected?.call(isVariant: true);
                                  _updateOrderSubscription?.cancel();
                                } else if (response.status == Status.ERROR) {
                                  if (kDebugMode) {
                                    print("Error adding variant: ${response.message}");
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response.message ?? 'Failed to add variant'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  if (Misc.enableUILogMessages && addVariationProdStopwatch != null) { // Build #1.0.256
                                    addVariationProdStopwatch.stop();
                                    // Clear global steps when toast is closed
                                    globalProcessSteps.clear();
                                    // Added to steps even on error
                                    // globalProcessSteps.add(
                                    //   ProcessStep(
                                    //     name: TextConstants.addProductToOrder,
                                    //     timeTaken: addVariationProdStopwatch.elapsedMilliseconds / 1000.0,
                                    //   ),
                                    // );
                                  }
                                  onProductSelected?.call(isVariant: true);
                                  _updateOrderSubscription?.cancel();
                                }
                              },
                            );

                            await _orderBloc.updateOrderProducts(
                              orderId: serverOrderId,
                              dbOrderId: dbOrderId,
                              lineItems: [
                                OrderLineItem(
                                  productId: variant["id"],
                                  quantity: quantity,
                                  // sku: variant["sku"],
                                ),
                              ],
                            );
                            // } else { ///Build #1.0.128: No need
                            //   // await orderHelper.addItemToOrder(
                            //   //   variant["id"],
                            //   //   variant["name"],
                            //   //   variant["image"],
                            //   //   double.tryParse(variant["price"].toString()) ?? 0.0,
                            //   //   quantity,
                            //   //   '',
                            //   //   onItemAdded: () {
                            //   //   //  Navigator.pop(context);
                            //   //     onProductSelected?.call(isVariant: true);
                            //   //   },
                            //   // );
                            //   _isAddingItemLoading = false;
                            //   _removeLoaderOverlay();
                            //   if (context.mounted) {
                            //     ScaffoldMessenger.of(context).showSnackBar(
                            //       SnackBar(
                            //         content: Text("Variant '${variant['name']}' did not added to order. OrderId not found."),
                            //         backgroundColor: Colors.green,
                            //         duration: const Duration(seconds: 2),
                            //       ),
                            //     );
                            //   }
                            // }
                          } catch (e,s) {
                            if (kDebugMode) {
                              print("Exception adding variant: $e, Stack: $s");
                            }
                            _isAddingItemLoading = false;
                            _removeLoaderOverlay();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error adding variant"),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      );
                    } else { ///if variation is empty, it will add main product
                      if (kDebugMode) {
                        print("#### TEST  111 variations");
                      }
                      onProductSelected?.call(isVariant: false);
                      //  Navigator.pop(context);
                      return const Center(child: CircularProgressIndicator()); // Build #1.0.148: Fixed issue - when we select a product to add in the order panel, we are getting a delay after selecting the product.
                    }
                  }
                  if (kDebugMode) {
                    print("#### TEST 222 variations");
                  }
                  if (Misc.enableUILogMessages && variationStopwatch != null && variationDone == false) { // Build #1.0.256
                    variationStopwatch.stop();
                    globalProcessSteps.add(ProcessStep(
                      name: TextConstants.variationCheck,
                      timeTaken: variationStopwatch.elapsedMilliseconds / 1000.0, // Approximate time for fetch
                    ));
                  }
                  onProductSelected?.call(isVariant: false);
                  //  Navigator.pop(context);
                  return const Center(child: CircularProgressIndicator()); // Build #1.0.148: Fixed issue - when we select a product to add in the order panel, we are getting a delay after selecting the product.
                },
              ),
              if (_isAddingItemLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        )
    );
  }

  OverlayEntry? _loaderOverlay;

  void _showLoaderOverlay(BuildContext context) {
    _removeLoaderOverlay();
    _loaderOverlay = OverlayEntry(
      builder: (context) => AbsorbPointer( // Build #1.0.200: Prevent dismissing by tapping outside
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loaderOverlay!);
  }

  void _removeLoaderOverlay() {
    _loaderOverlay?.remove();
    _loaderOverlay = null;
  }

  void dispose() {
    _productBloc.dispose();
    _orderBloc.dispose();
    _updateOrderSubscription?.cancel();
    _removeLoaderOverlay();
  }
}