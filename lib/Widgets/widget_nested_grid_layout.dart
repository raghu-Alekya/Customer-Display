<<<<<<< HEAD
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:pinaka_pos/Models/FastKey/fastkey_product_model.dart';
// import 'package:pinaka_pos/Utilities/textfield_search.dart';
// import 'package:reorderable_grid_view/reorderable_grid_view.dart';
//
// import '../Blocs/Search/product_search_bloc.dart';
// import '../Constants/text.dart';
// import '../Database/db_helper.dart';
// import '../Database/fast_key_db_helper.dart';
// import '../Database/order_panel_db_helper.dart';
// import '../Helper/auto_search.dart';
// import '../Helper/api_response.dart';
// import '../Models/Search/product_search_model.dart';
// import '../Repositories/Search/product_search_repository.dart';
// import '../Utilities/shimmer_effect.dart';
// import 'package:pinaka_pos/Blocs/FastKey/fastkey_product_bloc.dart';
// import 'package:pinaka_pos/Repositories/FastKey/fastkey_product_repository.dart';
//
// class NestedGridWidget extends StatefulWidget {
//   final bool isHorizontal;
//   final bool isLoading;
//   final VoidCallback? onItemAdded;
//   final ValueNotifier<int?> fastKeyTabIdNotifier;
//   final bool showAddButton; // Build #1.0.12: New parameter to control add button visibility in category screen
//
//   const NestedGridWidget({
//     super.key,
//     required this.isHorizontal,
//     this.isLoading = false,
//     this.onItemAdded,
//     required this.fastKeyTabIdNotifier,
//     this.showAddButton = true, // Default to true for backward compatibility
//   });
//
//   @override
//   _NestedGridWidgetState createState() => _NestedGridWidgetState();
// }
//
// class _NestedGridWidgetState extends State<NestedGridWidget> {
//   List<List<Map<String, dynamic>>> nestedItems = [
//     [
//       {"id": 101, "title": "Apple", "icon": Icons.apple, "price": "\$0.99", "image": "https://via.placeholder.com/50"},
//       {"id": 102, "title": "Banana", "icon": Icons.local_grocery_store, "price": "\$1.99", "image": "https://via.placeholder.com/50"},
//       {"id": 103, "title": "Carrot", "icon": Icons.eco, "price": "\$2.99", "image": "https://via.placeholder.com/50"},
//     ],
//     [
//       {"id": 104, "title": "Milk", "icon": Icons.local_drink, "price": "\$3.99", "image": "https://via.placeholder.com/50"},
//       {"id": 105, "title": "Bread", "icon": Icons.bakery_dining, "price": "\$4.99", "image": "https://via.placeholder.com/50"},
//       {"id": 106, "title": "Cheese", "icon": Icons.lunch_dining, "price": "\$5.99", "image": "https://via.placeholder.com/50"},
//     ],
//   ];
//
//   int currentLevel = 0;
//   List<String> navigationPath = ["Home"];
//   bool isLoading = false;
//   List<int?> reorderedIndices = [];
//   int? selectedItemIndex;
//   int? _fastKeyTabId;
//
//   File? _pickedImage;
//   final ImagePicker _picker = ImagePicker();
//   final OrderHelper orderHelper = OrderHelper();
//   final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
//   final DBHelper dbHelper = DBHelper.instance;
//
//   List<Map<String, dynamic>> fastKeyProductItems = [];
//   final TextEditingController searchController = TextEditingController();
//   List<Map<String, dynamic>> searchResults = [];
//   Map<String, dynamic>? selectedProduct;
//
//   TextEditingController _productSearchController = TextEditingController();
//   final _searchTextGridKey = GlobalKey<TextFieldSearchState>();
//   late SearchProduct _autoSuggest;
//   late FastKeyProductBloc _fastKeyProductBloc;
//
//   @override
//   void initState() {
//     super.initState();
//     _fastKeyProductBloc = FastKeyProductBloc(FastKeyProductRepository());
//     reorderedIndices = List.filled(fastKeyProductItems.length, null);
//     _loadActiveFastKeyTabId().then((_) { // Build #1.0.12: fixed fast key tab related issues
//       widget.fastKeyTabIdNotifier.addListener(_onTabChanged);
//     });
//     _autoSuggest= SearchProduct();
//     _productSearchController.addListener(_listenProductItemSearch);
//   }
//
//   _listenProductItemSearch(){
//     if(_productSearchController.text.isEmpty) {
//       _searchTextGridKey.currentState?.resetList();
//     }
//     _autoSuggest.listentextchange(_productSearchController.text ?? "");
//   }
//
//
//   void _onTabChanged() { // Build #1.0.12: fixed fast key tab related issues
//     if (kDebugMode) {
//       print("### _onTabChanged: New Tab ID: ${widget.fastKeyTabIdNotifier.value}");
//     }
//     if (widget.fastKeyTabIdNotifier.value == null) {
//       if (kDebugMode) {
//         print("### _onTabChanged: Tab ID is null, skipping update");
//       }
//       return;
//     }
//     setState(() {
//       _fastKeyTabId = widget.fastKeyTabIdNotifier.value;
//     });
//     fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId); // Save the active tab ID
//     _loadFastKeyTabItems(); // Reload items when the tab changes
//   }
//
//   @override
//   void dispose() {
//     widget.fastKeyTabIdNotifier.removeListener(_onTabChanged);
//     super.dispose();
//   }
//
//   Future<void> _loadActiveFastKeyTabId() async {
//     final lastSelectedTabId = await fastKeyDBHelper.getActiveFastKeyTab();
//     if (kDebugMode) {
//       print("### _loadActiveFastKeyTabId: Last Selected Tab ID: $lastSelectedTabId");
//     }
//     setState(() {
//       _fastKeyTabId = lastSelectedTabId;
//     });
//     if (kDebugMode) {
//       print("### _loadActiveFastKeyTabId: _fastKeyTabId set to $_fastKeyTabId");
//     }
//     _loadFastKeyTabItems();
//   }
//
//   Future<void> _loadFastKeyTabItems() async {
//     if (_fastKeyTabId == null) {
//       if (kDebugMode) {
//         print("### _fastKeyTabId is null, cannot load items");
//       }
//       return;
//     }
//
//     ///1. Get the active fastkey server id from _fastKeyTabId
//     var tabs = await fastKeyDBHelper.getFastKeyTabsByTabId(_fastKeyTabId ?? 1);
//     if(tabs.length == 0){
//       return;
//     }
//     var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
//     ///2. call 'Get Fast Key products by Fast Key ID' API
//
//     await _fastKeyProductBloc.fetchProductsByFastKeyId(_fastKeyTabId ?? 1, fastKeyServerId).whenComplete(() async {
//       ///3. load products from API into DB
//       final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
//       setState(() {
//         fastKeyProductItems = List<Map<String, dynamic>>.from(items);
//         reorderedIndices = List.filled(fastKeyProductItems.length, null); // Resize reorderedIndices
//       });
//     });
//
//   }
//
//   Future<void> _addFastKeyTabItem(String name, String image, String price) async {
//     if (_fastKeyTabId == null) {
//       if (kDebugMode) {
//         print("### _fastKeyTabId is null, cannot add item");
//       }
//       return;
//     }
//     if (kDebugMode) {
//       print("### _addFastKeyTabItem _fastKeyTabId: $_fastKeyTabId");
//     }
//     ///Add a logic to add to API then push to DB and final load from DB
//     ///1. get fastkey_server_id from DB and use for step 2
//     var tabs = await fastKeyDBHelper.getFastKeyTabsByTabId(_fastKeyTabId ?? 1);
//     if(tabs.length == 0){
//       return;
//     }
//     var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
//
//     ///2. get list of products in this tab from db
//     var productsInFastKey = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId ?? 1);
//     var countProductInFastKey = productsInFastKey.length;
//
//     ///3. create a FastKeyProductItem and pass to add product
//     FastKeyProductItem item = FastKeyProductItem(productId: selectedProduct!['id'], slNumber: countProductInFastKey+1);
//     ///4. call add fast keys product API
//     _fastKeyProductBloc.addProducts(fastKeyId: fastKeyServerId, products: [item]);
//
//     if (kDebugMode) {
//       print("save product $name in DB");
//     }
//     ///5. save to DB along with productid and index
//     await fastKeyDBHelper.addFastKeyItem(
//       _fastKeyTabId!,
//       name,
//       image,
//       price,
//       selectedProduct!['id'], // productId
//       sku: selectedProduct!['sku'] ?? 'N/A',
//       variantId: selectedProduct!['variantId'] ?? 'N/A',
//       slNumber: countProductInFastKey + 1,
//     );
//
//     // Update count and reload
//     await fastKeyDBHelper.updateFastKeyTabCount(_fastKeyTabId!, countProductInFastKey + 1);
//     await _loadFastKeyTabItems();
//
//     await _loadFastKeyTabItems(); // Reload items after adding
//     // Call setState synchronously after all async operations
//     if (mounted) {
//       setState(() {});
//     }
//     widget.fastKeyTabIdNotifier.notifyListeners(); // Notify listeners
//   }
//
//   Future<void> _deleteFastKeyTabItem(int fastKeyTabItemId) async { // Build #1.0.11
//     if (_fastKeyTabId == null) return;
//
//     await fastKeyDBHelper.deleteFastKeyItem(fastKeyTabItemId);
//     await _loadFastKeyTabItems(); // Reload items after deleting
//     await fastKeyDBHelper.updateFastKeyTabCount(_fastKeyTabId!, fastKeyProductItems.length);
//
//     // Call setState synchronously after all async operations
//     if (mounted) {
//       setState(() {});
//     }
//
//     widget.fastKeyTabIdNotifier.notifyListeners(); // Notify listeners
//   }
//
//   Future<void> _pickImage() async {
//     final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (imageFile != null) {
//       setState(() {
//         _pickedImage = File(imageFile.path);
//       });
//     }
//   }
//
//   void _onItemSelected(int index) async {
//     if (kDebugMode) {
//       print("Item selected: $index");
//     }
//     if (currentLevel + 1 < navigationPath.length) {
//       setState(() {
//         currentLevel++;
//         navigationPath.add(fastKeyProductItems[index]["fast_key_item_name"]);
//       });
//     } else {
//       final selectedProduct = fastKeyProductItems[index];
//       if (kDebugMode) {
//         print("Selected Product: $selectedProduct");
//       }
//
//       // Generate a unique key for each item to prevent merging
//     //  final uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
//
//       await orderHelper.addItemToOrder(
//         selectedProduct["fast_key_item_name"],
//         selectedProduct["fast_key_item_image"],
//         selectedProduct["fast_key_item_price"],
//         1, // Default quantity
//         'SKU${selectedProduct["fast_key_item_name"]}', // Build #1.0.13 : Fix - Fast key tab item issue
//         onItemAdded: widget.onItemAdded,
//       );
//
//       if (kDebugMode) {
//         print("Item added to order successfully!");
//       }
//     }
//   }
//
//   void _onBackPressed() {
//     if (currentLevel > 0) {
//       setState(() {
//         currentLevel--;
//         navigationPath.removeLast();
//       });
//     }
//   }
//
//   void _onNavigationPathTapped(int index) {
//     if (index < currentLevel) {
//       setState(() {
//         currentLevel = index;
//         navigationPath = navigationPath.sublist(0, index + 1);
//       });
//     }
//   }
//
//   Future<void> _deleteItem(int itemIndex) async {
//     final itemId = fastKeyProductItems[itemIndex]["fast_key_item_id"];
//     await _deleteFastKeyTabItem(itemId);
//   }
//
//   // Replace the existing searchProducts method with this:
//   Future<void> searchProducts(String query, StateSetter setStateDialog) async {
//     if (query.isEmpty) {
//       setStateDialog(() {
//         searchResults.clear();
//       });
//       return;
//     }
//     // This is now handled by the ProductBloc in the StreamBuilder
//     // So we don't need to manually set searchResults here
//   }
//
//   // Update the _showAddItemDialog method in NestedGridWidget
//   Future<void> _showAddItemDialog(int listIndex) async {
//     searchController.clear(); // Clear the search text
//     selectedProduct = null; // Reset the selected product
//     searchResults.clear(); // Clear previous search results
//
//     // Initialize ProductBloc
//     final productBloc = ProductBloc(ProductRepository());
//
//     return showDialog<void>(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(builder: (context, setStateDialog) {
//           return AlertDialog(
//             title: const Text(TextConstants.searchAddItemText),
//             content: SingleChildScrollView(
//               child: SizedBox(
//                 width: 300,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     TextField(
//                       controller: searchController,
//                       decoration: const InputDecoration(
//                         labelText: TextConstants.searchItemText,
//                         hintText: TextConstants.typeSearchText,
//                       ),
//                       onChanged: (value) {
//                         // Call fetchProducts with search query
//                         productBloc.fetchProducts(searchQuery: value);
//                       },
//                     ),
//                     TextFieldSearch(
//                       label: "Search Product",
//                       controller: _productSearchController,
//                       key: _searchTextGridKey,
//                       minStringLength: 0,
//                       itemsInView: 5,
//                       future: () { return _autoSuggest.getProductResults();},
//                       getSelectedValue: (item) async {
//                         if (item is ProductItem) {
//                           _productSearchController.text = item.label;
//                           var product = item.value;
//                           // Update where selectedProduct is set to include all required fields
//                           setStateDialog(() {
//                             selectedProduct = {
//                               'title': product.name ?? 'Unknown',
//                               'image': product.images?.isNotEmpty == true ? product.images!.first : '',
//                               'price': product.regularPrice ?? '0.00',
//                               'id': product.id,
//                               'sku': product.sku ?? 'N/A',
//                               'variantId': product.variantId ?? 'N/A',
//                             };
//                           });
//
//                           FocusManager.instance.primaryFocus?.unfocus();
//                         }
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                     StreamBuilder<APIResponse<List<ProductResponse>>>( // Build #1.0.13 : auto search for product item in alert when tap on add item in grid
//                       stream: productBloc.productStream,
//                       builder: (context, snapshot) {
//                         if (snapshot.hasData) {
//                           switch (snapshot.data!.status) {
//                             case Status.LOADING:
//                               return const Center(child: CircularProgressIndicator());
//                             case Status.COMPLETED:
//                               final products = snapshot.data!.data;
//                               if (products == null || products.isEmpty) {
//                                 return const Center(child: Text("No products found"));
//                               }
//
//                               return SizedBox(
//                                 height: 200,
//                                 child: ListView.builder(
//                                   shrinkWrap: true,
//                                   physics: const BouncingScrollPhysics(),
//                                   itemCount: products.length,
//                                   itemBuilder: (context, index) {
//                                     final product = products[index];
//                                     return ListTile(
//                                       leading: product.images != null && product.images!.isNotEmpty
//                                           ? Image.network(
//                                         product.images!.first,
//                                         width: 50,
//                                         height: 50,
//                                         fit: BoxFit.cover,
//                                         errorBuilder: (context, error, stackTrace) =>
//                                         const Icon(Icons.broken_image),
//                                       )
//                                           : const Icon(Icons.image),
//                                       title: Text(product.name ?? 'No Name'),
//                                       subtitle: Text('\$${product.price ?? '0.00'}'),
//                                       onTap: () {
//                                         setStateDialog(() {
//                                           selectedProduct = {
//                                             'title': product.name ?? 'Unknown',
//                                             'image': product.images?.isNotEmpty == true
//                                                 ? product.images!.first
//                                                 : '',
//                                             'price': product.regularPrice ?? '0.00',
//                                             'id': product.id,
//                                             'sku': product.sku ?? 'N/A',
//                                           };
//                                         });
//                                       },
//                                       selected: selectedProduct != null &&
//                                           selectedProduct!['id'] == product.id,
//                                       selectedTileColor: Colors.grey[300],
//                                     );
//                                   },
//                                 ),
//                               );
//                             case Status.ERROR:
//                               print("BIG ERROR");
//                               return Center(
//                                 child: Text(snapshot.data!.message ?? "Error loading products"),
//                               );
//                           }
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             actions: <Widget>[
//               TextButton(
//                 onPressed: () {
//                   productBloc.dispose();
//                   Navigator.of(context).pop();
//                 },
//                 child: const Text(TextConstants.cancelText),
//               ),
//               TextButton(
//                 onPressed: selectedProduct != null ? () async {
//                   if (kDebugMode) {
//                     print("Adding product: $selectedProduct");
//                   }
//                   if (_fastKeyTabId != null) {
//                     await _addFastKeyTabItem(
//                       selectedProduct!['title'],
//                       selectedProduct!['image'],
//                       selectedProduct!['price'],
//                     );
//
//                     await fastKeyDBHelper.updateFastKeyTabCount(
//                       _fastKeyTabId!,
//                       fastKeyProductItems.length,
//                     );
//
//                     await _loadFastKeyTabItems();
//
//                     if (mounted) {
//                       setState(() {});
//                     }
//
//                     widget.fastKeyTabIdNotifier?.notifyListeners();
//                   }
//
//                   _productSearchController.text = "";
//                   productBloc.dispose();
//                   Navigator.of(context).pop();
//                 } : null,
//                 child: const Text(TextConstants.addText),
//               ),
//             ],
//           );
//         });
//       },
//     ).then((_) {
//       productBloc.dispose();
//     });
//   }
//
//   Widget _buildImage(String imagePath) {
//     if (imagePath.startsWith("http")) {
//       return Image.network(
//         imagePath,
//         width: 50,
//         height: 50,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) {
//           return Container(
//             width: 50,
//             height: 50,
//             color: Colors.grey.shade300,
//             child: const Icon(Icons.broken_image, color: Colors.grey),
//           );
//         },
//       );
//     } else {
//       return Image.file(
//         File(imagePath),
//         width: 50,
//         height: 50,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) {
//           return Container(
//             width: 50,
//             height: 50,
//             color: Colors.grey.shade300,
//             child: const Icon(Icons.broken_image, color: Colors.grey),
//           );
//         },
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final totalCount = fastKeyProductItems.length +
//         (_fastKeyTabId != null && widget.showAddButton ? 1 : 0); // Build #1.0.12: Modified condition
//     final theme = Theme.of(context);
//
//     return Expanded(
//       child: Column(
//         children: [
//           if (currentLevel > 0)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//               child: Row(
//                 children: [
//                   ElevatedButton(
//                     onPressed: _onBackPressed,
//                     style: ElevatedButton.styleFrom(
//                       side: BorderSide(color: theme.secondaryHeaderColor),
//                     ),
//                     child: Text(TextConstants.backText, style: TextStyle(color: theme.secondaryHeaderColor)),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       child: Row(
//                         children: List.generate(navigationPath.length, (index) {
//                           return GestureDetector(
//                             onTap: () => _onNavigationPathTapped(index),
//                             child: Row(
//                               children: [
//                                 Text(
//                                   navigationPath[index],
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.blue,
//                                     decoration: TextDecoration.underline,
//                                   ),
//                                 ),
//                                 if (index < navigationPath.length - 1)
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                                     child: Icon(Icons.arrow_forward, size: 16, color: theme.secondaryHeaderColor),
//                                   ),
//                               ],
//                             ),
//                           );
//                         }),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           Expanded(
//             child: Container(
//               color: Colors.transparent,
//               child: widget.isLoading
//                   ? ShimmerEffect.rectangular(height: 200)
//                   : Material(
//                 color: Colors.transparent,
//                 child: ReorderableGridView.builder(
//                   padding: const EdgeInsets.all(16),
//                   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 3,
//                     mainAxisSpacing: 20,
//                     crossAxisSpacing: 10,
//                     childAspectRatio: widget.isHorizontal ? 2.2 : 1.8,
//                   ),
//                   itemCount: totalCount,
//                   onReorder: (oldIndex, newIndex) {
//                     if (oldIndex == 0 || newIndex == 0) return;
//
//                     final adjustedOldIndex = oldIndex - (widget.showAddButton ? 1 : 0); // Build #1.0.12:
//                     final adjustedNewIndex = newIndex - (widget.showAddButton ? 1 : 0);
//
//                     if (adjustedOldIndex < 0 || adjustedNewIndex < 0 || adjustedOldIndex >= fastKeyProductItems.length || adjustedNewIndex >= fastKeyProductItems.length) {
//                       return;
//                     }
//
//                     setState(() {
//                       fastKeyProductItems = List<Map<String, dynamic>>.from(fastKeyProductItems); // Make mutable
//                       final item = fastKeyProductItems.removeAt(adjustedOldIndex);
//                       fastKeyProductItems.insert(adjustedNewIndex, item);
//
//                       reorderedIndices = List.filled(fastKeyProductItems.length, null);
//                       reorderedIndices[adjustedNewIndex] = adjustedNewIndex;  // Mark as reordered
//                       selectedItemIndex = adjustedNewIndex;
//                     });
//                   },
//                   itemBuilder: (context, index) {
//                     // Show add button only if showAddButton is true and it's the first item
//                     if (widget.showAddButton && _fastKeyTabId != null && index == 0) { // Build #1.0.12:
//                       return Container(
//                         key: const ValueKey('add_button'),
//                         child: GestureDetector(
//                           onTap: () => _showAddItemDialog(currentLevel),
//                           child: Card(
//                             color: Colors.white,
//                             elevation: 4,
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: const [
//                                 Icon(Icons.add, size: 50, color: Colors.green),
//                                 SizedBox(height: 8),
//                                 Text(TextConstants.addItemText, style: TextStyle(color: Colors.green)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     } else {
//                       final itemIndex = widget.showAddButton && _fastKeyTabId != null ? index - 1 : index; // Build #1.0.12
//                       if (itemIndex >= fastKeyProductItems.length) {
//                         return SizedBox.shrink(); // Handle out-of-bounds index
//                       }
//                       final isReordered = reorderedIndices.isNotEmpty && reorderedIndices.contains(itemIndex);
//                       final item = fastKeyProductItems[itemIndex];
//                       if (kDebugMode) {
//                         print(">>>>>>>>>>>>>>>> Grid Layout key: grid_item_${currentLevel}_${itemIndex}_${item["fast_key_item_name"]}");
//                       }
//                       return AnimatedContainer(
//                         duration: const Duration(milliseconds: 300),
//                         decoration: BoxDecoration(
//                           border: isReordered ? Border.all(color: Colors.blue, width: 3) : null,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         key: ValueKey('grid_item_${currentLevel}_${itemIndex}_${item["fast_key_item_name"]}'),
//                         child: Stack(
//                           clipBehavior: Clip.none,
//                           children: [
//                             GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   if (selectedItemIndex == itemIndex) {
//                                     selectedItemIndex = null;
//                                   } else {
//                                     selectedItemIndex = itemIndex;
//                                     reorderedIndices = List.filled(fastKeyProductItems.length, null); // Reset reorderedIndices
//                                   }
//                                   _onItemSelected(itemIndex);
//                                 });
//                               },
//                               child: Card(
//                                 color: Colors.white,
//                                 elevation: 4,
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Row(
//                                     children: [
//                                       _buildImage(item["fast_key_item_image"]),
//                                       const SizedBox(width: 12),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           mainAxisAlignment: MainAxisAlignment.center,
//                                           children: [
//                                             Text(
//                                               item["fast_key_item_name"],
//                                               style: TextStyle(
//                                                 fontSize: 16,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.black,
//                                               ),
//                                               overflow: TextOverflow.ellipsis,
//                                             ),
//                                             Text(
//                                               '\$${item["fast_key_item_price"]}',
//                                               style: TextStyle(
//                                                 fontSize: 12,
//                                                 color: Colors.black,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             if (isReordered)
//                               Positioned(
//                                 top: widget.isHorizontal ? -5 : -9,
//                                 right: widget.isHorizontal ? -2 : -4,
//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     IconButton(
//                                       icon: const Icon(Icons.delete, color: Colors.red, size: 20),
//                                       onPressed: () {
//                                         _deleteItem(itemIndex);
//                                       },
//                                     ),
//                                     const SizedBox(width: 0),
//                                     IconButton(
//                                       icon: const Icon(Icons.close, color: Colors.grey, size: 20),
//                                       onPressed: () {
//                                         setState(() {
//                                           reorderedIndices = List.filled(fastKeyProductItems.length, null); // Reset reorderedIndices
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                           ],
//                         ),
//                       );
//                     }
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Helper/auto_search.dart';
=======
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar_community/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:pinaka_pos/Helper/auto_search.dart';
import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
>>>>>>> origin/Grocery_pch_api_integration
import 'package:pinaka_pos/Widgets/widget_age_verification_popup_dialog.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
<<<<<<< HEAD
=======
import '../Helper/url_helper.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../Helper/api_response.dart';
import '../Models/Search/product_variation_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Providers/Auth/product_variation_provider.dart';
<<<<<<< HEAD
import '../Utilities/shimmer_effect.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../Utilities/svg_images_utility.dart';
=======
import '../Database/isar_service.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/shimmer_effect.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../Utilities/svg_images_utility.dart';
import 'ManualPriceDialog.dart';
import 'OrderPopupHelper.dart';
import 'widget_logs_toast.dart';
import 'widget_topbar.dart';
>>>>>>> origin/Grocery_pch_api_integration

class NestedGridWidget extends StatelessWidget {
  final bool isHorizontal;
  final bool isLoading;
  final bool showAddButton;
  final bool showBackButton; // New property to show "Back to Categories" button
  final List<Map<String, dynamic>> items;
  final int? selectedItemIndex;
  final List<int?> reorderedIndices;
  final VoidCallback? onAddButtonPressed;
  final VoidCallback? onBackButtonPressed; // Callback for "Back to Categories"
<<<<<<< HEAD
  final Function(int, {bool variantAdded}) onItemTapped; // Update the callback to accept a named parameter
=======
  final Function(int, {bool variantAdded})
  onItemTapped; // Update the callback to accept a named parameter
>>>>>>> origin/Grocery_pch_api_integration
  final Function(int, int) onReorder;
  final Function(int) onDeleteItem;
  final bool showDeleteButton;
  final Function() onCancelReorder;
  final bool? enableIcons; // Build #1.0.204: Added this
  final Function(int)? onLongPress; // Added this
  final ProductBloc? productBloc; //Build 1.1.36
  final OrderBloc? orderBloc;
<<<<<<< HEAD
  final OrderHelper? orderHelper;
=======
  final OrderHelper orderHelper;
  final bool isPaginating;


  static final Map<int, Map<String, dynamic>> _productMetaCache = {};

  static void clearProductMetaCache() {
    _productMetaCache.clear();
  }

  static int? _nestedProductMetaIdFromCacheMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final dynamic idRaw =
        m["fast_key_product_id"] ?? m["product_id"] ?? m["id"];
    if (idRaw is int) return idRaw;
    return int.tryParse(idRaw?.toString() ?? "");
  }

  // ── 🔧 FIX: Robust tag parser ──────────────────────────────────────────────
  // `fast_key_item_tags` (and `tags`) can arrive in TWO shapes:
  //   1) an already-decoded List<Map>            (normal / hydrated path)
  //   2) a raw JSON-encoded String straight from SQLite (cold start / first
  //      tap, before any decode step has touched the item)
  //
  // Every tag-reading spot in this file used to do `if (source is List)`
  // ONLY. When tags were still a raw JSON string (case 2), that check
  // silently failed, `tags` resolved to an empty list, and NOTHING using
  // tags worked correctly on first load: EBT badge, variant icon,
  // "variable" price detection, and — the one you reported — the
  // "produce" tag (weighed items) detection in the tap handler. No error
  // was thrown, it just silently fell back to "simple product" behavior.
  //
  // This helper is now the SINGLE source of truth for reading tags in this
  // widget, and it handles both shapes.
  static List<Map<String, dynamic>> _parseNestedTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
        }
      } catch (e) {
        if (kDebugMode) {
          print("⚠️ NestedGridWidget: failed to decode tags string: $e");
        }
      }
    }
    return const [];
  }


  /// One product-add flow at a time across the grid (fast taps otherwise queue heavy async work).
  static bool _productTapInFlight = false;
>>>>>>> origin/Grocery_pch_api_integration

  const NestedGridWidget({
    super.key,
    required this.isHorizontal,
    required this.isLoading,
    required this.showAddButton,
    required this.showBackButton,
    required this.items,
    this.selectedItemIndex,
    required this.reorderedIndices,
    this.onAddButtonPressed,
    this.onBackButtonPressed,
    required this.onItemTapped,
    required this.onReorder,
    required this.onDeleteItem,
    this.showDeleteButton = true,
    required this.onCancelReorder,
    this.enableIcons,
    this.onLongPress,
    this.productBloc,
    this.orderBloc,
<<<<<<< HEAD
    this.orderHelper,
  });

=======
    required this.orderHelper,
    required this.isPaginating,
  });

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
    if (!_productMetaCache.containsKey(productId)) {
      // 🔧 FIX: On cold start / first tab open, TopBar's merged Isar/Hive
      // product cache may not be ready yet. Ingesting before it's ready means
      // this product's tags/meta_data (produce, EBT, variable-price, age
      // restriction) resolve to nothing, and the tap silently falls back to
      // "simple product" behavior. FastKeyScreen used to guard against this
      // (_awaitMergedProductCacheReadyForFastKeys) but that code path is now
      // dead — NestedGridWidget is what actually owns the tap flow, so the
      // guard needs to live here instead.
      try {
        await TopBar.waitForFirstMergedProductCacheReload()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // timed out / errored — proceed with whatever is available rather
        // than blocking the tap forever
      }
      await _ingestNestedProductMetaFromMerged();
    }
    return _productMetaCache[productId];
  }

  static Future<void> _ingestNestedProductMetaFromMerged() async {
    try {
      _productMetaCache.clear(); // Force fresh
      final allCached = await TopBar.mergedCachedProductsForSearch();
      for (final raw in allCached) {
        final pid = _nestedProductMetaIdFromCacheMap(raw);
        if (pid != null) {
          _productMetaCache[pid] = Map<String, dynamic>.from(raw as Map);
        }
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ _ingestNestedProductMetaFromMerged failed: $e");
    }
  }

  Future<bool> _fastKeyHasVariants(Map<String, dynamic> item) async {
    final int? productId =
    int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    if (productId == null) return false;

    // 1️⃣ Fast item-level check
    if (item["type"] == "variable") return true;
    if (item["variations"] is List && item["variations"].isNotEmpty) return true;

    // 2️⃣ Check product meta cache
    final cached = await _getCachedProductFromIsar(productId);

    if (cached?["type"] == "variable") return true;
    if (cached?["has_variants"] == true) return true;

    // 3️⃣ 🔥 CHECK VARIATION CACHE (THIS WAS MISSING)
    try {
      final box = StorageProvider.productCache;
      final variationKey = "product_${productId}_variations";
      final variationData = await box.get(variationKey);

      if (variationData is Map &&
          variationData["variations"] is List &&
          (variationData["variations"] as List).isNotEmpty) {
        return true;
      }

      if (variationData is List && variationData.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  // 🔧 FIX: was `if (tagsRaw is List)` only — now uses _parseNestedTags so a
  // raw JSON-string tags column (cold start / first tap) is handled too.
  bool _isProductEbtEligible(Map<String, dynamic> item) {
    if (_truthyEbtNested(item["is_ebt_eligible"])) return true;
    if (_ebtMetaNested(item["meta_data"])) return true;

    final tags =
    _parseNestedTags(item["fast_key_item_tags"] ?? item["tags"]);
    for (final t in tags) {
      final name = (t["name"] ?? "").toString().toLowerCase();
      final slug = (t["slug"] ?? "").toString().toLowerCase();
      if (name.contains("ebt") || slug.contains("ebt")) return true;
    }

    return false;
  }

  // 🔧 FIX: was `if (tagsRaw is List)` only — now uses _parseNestedTags.
  bool _isVariableProduct(Map<String, dynamic> item) {
    final tags =
    _parseNestedTags(item["fast_key_item_tags"] ?? item["tags"]);
    return tags.any((t) {
      final name = (t["name"] ?? "").toString().toLowerCase();
      final slug = (t["slug"] ?? "").toString().toLowerCase();
      return name.contains("variable") || slug.contains("variable");
    });
  }


>>>>>>> origin/Grocery_pch_api_integration
  Widget _buildImage(String imagePath) {
    final imageWidget = imagePath.startsWith("http")
        ? SizedBox(
      width: 75,
      height: 75,
      child: Image.network(
        imagePath,
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 75,
            height: 75,
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      ),
    )
        : Platform.isWindows
        ? Image.asset(
      'assets/default.png',
      height: 75,
      width: 75,
    )
        : Image.file(
      File(imagePath),
      width: 75,
      height: 75,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 75,
          height: 75,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final totalCount = (showAddButton ? 1 : 0) + (showBackButton ? 1 : 0) + items.length;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Expanded(
      child: Container(
        margin: EdgeInsets.fromLTRB(6, 0, 8, 10),
        height: MediaQuery.of(context).size.height /2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white,
        ),
        child: isLoading
            ? ShimmerEffect.rectangular(height: 200)
            : Material(
          color: Colors.transparent,
          child: ReorderableGridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: totalCount,
            dragEnabled: Misc.enableReordering, // Build #1.0.204: Disable Re-Order for grid & Added this line to control drag functionality
            onReorder: Misc.enableReordering ? onReorder : (oldIndex, newIndex) {}, // Disable reorder callback if not enabled
            itemBuilder: (context, index) {
              // Handle "Add" button if enabled
              if (showAddButton && index == 0) {
                return Container(
                  key: const ValueKey('add_button'),
                  child: GestureDetector(
                    onTap: onAddButtonPressed ?? () {},
                    child: _getCardWidget(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 40, color: Color(0xFFFE6464)),
                        //SizedBox(height: 2),
                        Text(TextConstants.addProductText, style: TextStyle(color: Color(0xFFFE6464),fontSize: 17,fontWeight: FontWeight.bold)),
                      ],
                    ),themeHelper, accentColor: Colors.redAccent),
                  ),
                );
              }

              // Handle "Back to Categories" button if enabled
              if (showBackButton && index == (showAddButton ? 1 : 0)) {
                return Container(
                  key: const ValueKey('back_button'),
                  child: GestureDetector(
                    onTap: onBackButtonPressed ?? () {},
                    child: _getCardWidget(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_back, size: 50, color: Colors.blue),
                        SizedBox(height: 5),
                        Text(TextConstants.backToCategories, style: TextStyle(color: Colors.blue)),
                      ],
                    ), themeHelper),
                  ),
                );
              }

              // Adjust the index based on the presence of "Add" and "Back" buttons
              final itemIndex = index - (showAddButton ? 1 : 0) - (showBackButton ? 1 : 0);
              if (itemIndex < 0 || itemIndex >= items.length) {
                return const SizedBox.shrink();
              }

              final isReordered = reorderedIndices.isNotEmpty && reorderedIndices[itemIndex] != null;
              final item = items[itemIndex];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  border: isReordered ? Border.all(color: Colors.blue, width: 3) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                key: ValueKey('grid_item_${itemIndex}_${item["fast_key_item_name"]}'),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector( //Build 1.1.36: updated code for variations dialog conditions
                      onTap: () async {
                        if (productBloc == null) {
                          if (kDebugMode) {
                            print("NestedGridWidget - productBloc is null, cannot fetch variations");
                          }
                          onItemTapped(index);
                          return;
                        }

                        final productId = int.tryParse(item["fast_key_product_id"].toString()) ?? -1; //Build #1.0.54: fixed variant dialog issue
                        if (kDebugMode) {
                          print("NestedGridWidget - Product tapped: ${item['fast_key_item_name']}, ID: $productId, (${item["fast_key_product_id"]})");
                          print("NestedGridWidget - minAge ${item[AppDBConst.fastKeyItemMinAge] ?? 0}");
                          print("TEST 11 - fast_key_item_has_variant ${item[AppDBConst.fastKeyItemHasVariant]}");
                        }
                        /// use product id:22, sku:woo-fashion-socks
                        //var isVerified = await _ageRestrictedProduct(context, minAge: item[AppDBConst.fastKeyItemMinAge] ?? 0);
                        //Build #1.0.234: Checking stored age restriction before verifying -> Age
                        final order = orderHelper?.orders.firstWhere(
                              (order) => order[AppDBConst.orderServerId] == orderHelper?.activeOrderId,
                          orElse: () => {},
                        );
                        final String ageRestrictedValue = order?[AppDBConst.orderAgeRestricted]?.toString() ?? 'false';
                        final bool isAgeRestricted = ageRestrictedValue.toLowerCase() == 'true' || ageRestrictedValue == "1";

                        if (!isAgeRestricted) {
                          /// Verify Age and proceed else return
                          final ageVerificationProvider = AgeVerificationProvider();
                          var isVerified = await ageVerificationProvider.verifyAge(context, minAge: item[AppDBConst.fastKeyItemMinAge] ?? 0);
                          if(!isVerified){
                            return;
                          }
                        }
                        /// Build #1.0.157: Added to check before calling variation API for saving loading time issue
                        //  if (item['type'] == 'variable' || item['fast_key_item_has_variant'] == 1) {
                        //    if (kDebugMode) {
                        //      print("##### NestedGridWidget - Item Type: ${item['type']}, productId: $productId");
                        //    }
                        //    VariationPopup(productId, item['fast_key_item_name'], orderHelper!, onProductSelected: ({required bool isVariant}) {
                        //
                        //      onItemTapped(index, variantAdded: isVariant);
                        //      if (kDebugMode) {
                        //        print("##### NestedGridWidget - Variant $isVariant");
                        //      }
                        //    }).showVariantDialog(context: context);
                        //  } else {
                        //    if (kDebugMode) {
                        //      print("##### NestedGridWidget - NO Variant, productId: $productId");
                        //    }
                        // //   Center(child: CircularProgressIndicator());
                        //    onItemTapped(index, variantAdded: false);
                        //  }

                        VariationPopup(productId, item['fast_key_item_name'], orderHelper!,onProductSelected: ({required bool isVariant}) {
                          // Navigator.pop(context); // Build #1.0.148: loader/dialog popping after product adds into order panel in _onItemSelected in fastKey/categories screen
                          onItemTapped(index, variantAdded: isVariant); //Build #1.0.78: Pass isVariant to onItemTapped
                        },
                        ).showVariantDialog(context: context);
                        // // Fetch variations for the product
                        // productBloc!.fetchProductVariations(productId);
                        //
                        // // Show dialog and listen to the variation stream
                        // if (context.mounted) {
                        //   showDialog(
                        //     context: context,
                        //     builder: (context) => StreamBuilder<APIResponse<List<ProductVariation>>>(
                        //       stream: productBloc!.variationStream,
                        //       builder: (context, snapshot) {
                        //         if (!snapshot.hasData) {
                        //           if (kDebugMode) {
                        //             print("NestedGridWidget - No data in stream, waiting...");
                        //           }
                        //           return const Center(child: CircularProgressIndicator());
                        //         }
                        //
                        //         final response = snapshot.data!;
                        //         if (response.status == Status.LOADING) {
                        //           return const Center(child: CircularProgressIndicator());
                        //         } else if (response.status == Status.COMPLETED) {
                        //           final variations = response.data!;
                        //           if (variations.isNotEmpty) {
                        //             if (kDebugMode) {
                        //               print("NestedGridWidget - Variations found: ${variations.length}");
                        //             }
                        //             return VariantsDialog(
                        //               title: item["fast_key_item_name"],
                        //               variations: variations
                        //                   .map((v) => {
                        //                 "id": v.id,
                        //                 "name": v.name,
                        //                 "price": v.regularPrice,
                        //                 "image": v.image.src,
                        //               }).toList(),
                        //               onAddVariant: (variant, quantity) {
                        //                 if (kDebugMode) {
                        //                   print("NestedGridWidget - Adding variant to order: ID=${variant['id']}, Name=${variant['name']}, Quantity=$quantity");
                        //                 }
                        //                 orderHelper?.addItemToOrder(
                        //                   variant["name"],
                        //                   variant["image"],
                        //                   double.tryParse(variant["price"].toString()) ?? 0.0,
                        //                   quantity,
                        //                   'SKU${variant["name"]}',
                        //                   onItemAdded: () {
                        //                     Navigator.pop(context);
                        //                     onItemTapped(index, variantAdded: true);
                        //                   },
                        //                 );
                        //               },
                        //             );
                        //           } else {
                        //             if (kDebugMode) {
                        //               print("NestedGridWidget - No variations found, proceeding with product");
                        //             }
                        //             Navigator.pop(context);
                        //             onItemTapped(index);
                        //             return const SizedBox.shrink();
                        //           }
                        //         } else {
                        //           if (kDebugMode) {
                        //             print("NestedGridWidget - Error fetching variations: ${response.message}");
                        //           }
                        //           Navigator.pop(context);
                        //           onItemTapped(index);
                        //           return const SizedBox.shrink();
                        //         }
                        //       },
                        //     ),
                        //   );
                        // }
                      },
                      onLongPress: () {
                        if (onLongPress != null) { // Build #1.0.204
                          onLongPress!(itemIndex); // Safe to use ! since we checked for null
                          if (kDebugMode) {
                            print("### TEST onLongPress");
                          }
                        } else {
                          if (kDebugMode) {
                            print("### onLongPress is null, skipping");
                          }
                        }
                      },
                      child: _getCardWidget(Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            _buildImage(item["fast_key_item_image"]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Text(
                                    item["fast_key_item_name"],
                                    style: TextStyle(
                                      fontSize: 12,
                                      //fontWeight: FontWeight.bold,
                                      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${TextConstants.currencySymbol}${double.tryParse(item["fast_key_item_price"].toString())?.toStringAsFixed(2) ?? "0.00"}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                                        ),
                                      ),
                                      const SizedBox(width: 16), // Space between price and variations
                                      if (item['variations'] != null && item['variations'].isNotEmpty) // Build #1.0.157: show variationIcon with count
                                        Row(
                                          children: [
                                            SvgPicture.asset(SvgUtils.variationIcon, height: 10, width: 10),
                                            // SizedBox(width: 4),
                                            // Text(
                                            //   '${item["variations"].length}',
                                            //   style: TextStyle(
                                            //     fontSize: 12,
                                            //     color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ), themeHelper),
                    ),
                    if (enableIcons == true && itemIndex == selectedItemIndex) // Build #1.0.204: Show icons only for long-pressed item
                      Positioned(
                        top: -5,
                        right: -2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDeleteButton)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => onDeleteItem(itemIndex),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                              onPressed: onCancelReorder,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

=======
    final totalCount =
        (showAddButton ? 1 : 0) + (showBackButton ? 1 : 0) + items.length;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    // Must not use [Expanded] here: callers already wrap this widget in
    // `Expanded` + `ValueListenableBuilder`. Nesting [Expanded] causes
    // competing FlexParentData (ParentDataWidget assertion on hot restart).
    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Colors.white,
        ),
        child: Stack(
          children: [
            /// 🔹 GRID
            isLoading
                ? ShimmerEffect.rectangular(height: 900)
                : ReorderableGridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: totalCount,
              dragEnabled: Misc
                  .enableReordering, // Build #1.0.204: Disable Re-Order for grid & Added this line to control drag functionality
              onReorder: Misc.enableReordering
                  ? onReorder
                  : (oldIndex,
                  newIndex) {}, // Disable reorder callback if not enabled
              itemBuilder: (context, index) {
                // Handle "Add" button if enabled
                if (showAddButton && index == 0) {
                  return Container(
                    key: const ValueKey('add_button'),
                    child: GestureDetector(
                      onTap: onAddButtonPressed ?? () {},
                      child: _getCardWidget(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add,
                                  size: 40, color: Color(0xFFFE6464)),
                              //SizedBox(height: 2),
                              Text(TextConstants.addProductText,
                                  style:
                                  TextStyle(color: Color(0xFFFE6464))),
                            ],
                          ),
                          themeHelper,
                          accentColor: Colors.redAccent),
                    ),
                  );
                }



                // Handle "Back to Categories" button if enabled
                if (showBackButton && index == (showAddButton ? 1 : 0)) {
                  return Container(
                    key: const ValueKey('back_button'),
                    child: GestureDetector(
                      onTap: onBackButtonPressed ?? () {},
                      child: _getCardWidget(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.arrow_back,
                                  size: 50, color: Colors.blue),
                              SizedBox(height: 5),
                              Text(TextConstants.backToCategories,
                                  style: TextStyle(color: Colors.blue)),
                            ],
                          ),
                          themeHelper),
                    ),
                  );
                }


                // Adjust the index based on the presence of "Add" and "Back" buttons
                final itemIndex = index -
                    (showAddButton ? 1 : 0) -
                    (showBackButton ? 1 : 0);
                if (itemIndex < 0 || itemIndex >= items.length) {
                  return const SizedBox.shrink();
                }

                final isReordered = reorderedIndices.isNotEmpty &&
                    reorderedIndices[itemIndex] != null;
                final item = items[itemIndex];

                // Normalise EBT eligibility from multiple possible flags/encodings
                final dynamic rawEbtFlag = item['is_ebt_eligible'] ??
                    item['ebt_eligible'] ??
                    item['isEbtEligible'];
                final bool ebtFromFlag = rawEbtFlag == true ||
                    rawEbtFlag == 1 ||
                    rawEbtFlag == '1' ||
                    rawEbtFlag == 'true';

                final String itemTypeStr =
                (item['type'] ?? '').toString().toLowerCase();
                final dynamic hvDb = item['fast_key_item_has_variant'];
                final bool hasVariantFromApiRow = hvDb == 1 ||
                    hvDb == true ||
                    hvDb == '1';
                final bool showVariantIcon = hasVariantFromApiRow ||
                    item['has_variants'] == true ||
                    item['has_variants'] == 1 ||
                    item['has_variants'] == '1' ||
                    item['has_variants'] == 'true' ||
                    (item['variations'] is List &&
                        (item['variations'] as List).isNotEmpty) ||
                    itemTypeStr == 'variable';

                final bool showEbtTag =
                    ebtFromFlag || _isProductEbtEligible(item);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: isReordered
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  key: ValueKey(
                      'grid_item_${itemIndex}_${item["fast_key_item_name"]}'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (_productTapInFlight) return;
                          _productTapInFlight = true;

                          // ─────────────────────────────────────────────────────────────
                          // 🔍 NEW: DEBUG PRINTS WHEN ITEM IS TAPPED
                          // ─────────────────────────────────────────────────────────────
                          print("🔍 [NestedGridWidget] ITEM TAPPED → Index: $itemIndex");
                          print("📦 Full Item Data: ${jsonEncode(item)}"); // Pretty print full item

                          // Parse and print tags
                          final tags = _parseNestedTags(item["fast_key_item_tags"] ?? item["tags"]);
                          print("🏷️ Has Tags: ${tags.isNotEmpty}");
                          if (tags.isNotEmpty) {
                            print("📋 Tags Count: ${tags.length}");
                            for (final tag in tags) {
                              print("   • Tag: ${tag['name']} | Slug: ${tag['slug']}");
                            }
                          } else {
                            print("⚠️ No tags found in item or cache");
                          }
                          print("────────────────────────────────────────────────────");

                          // if (orderHelper?.activeOrderId == null) {
                          //   print("⛔ No active order → Show popup and block product adding");
                          //
                          //   await OrderPopupHelper.showNoOrderPopup(context);
                          //
                          //   return; // 🚫 STOP item adding
                          // }

                          try {
                            final orderId = await orderHelper.ensureOrderExists();

                            if (orderId == null) {
                              final msg = OrderHelper.lastEnsureOrderError ??
                                  "Failed to create or restore order. Please try again.";
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                              return;
                            }

                            print("🆔 Active Order ID (ensured): $orderId");

                            print("🟩 TAP: Starting product add flow for item → ${item["fast_key_item_name"]}");

                            // 🧠 Hydrate from Isar cache (same flow as category load)
                            final productId =
                                int.tryParse(item["fast_key_product_id"].toString()) ?? -1;
                            // FORCE refresh from latest cache
                            if (productId > 0) {
                              await _enrichFastKeyItemSkuForNested(item);
                              final cached = await _getCachedProductFromIsar(productId);
                              if (cached != null) {
                                item.addAll(cached); // merge latest
                              }
                            }
                            final cachedProduct =
                            productId > 0 ? await _getCachedProductFromIsar(productId) : null;

                            // 🏷 Collect tags from item first, then from cache.
                            // 🔧 FIX: previously this used a local `addTags()`
                            // closure that only accepted `List` sources. If
                            // `fast_key_item_tags` was still a raw JSON string
                            // (which happens on cold start / first tap before
                            // any prep step has decoded it), `tags` silently
                            // ended up empty and every tag-dependent check
                            // below (produce/weighed, variable-price, EBT,
                            // variant) fell back to "simple product" with no
                            // error printed. Now uses _parseNestedTags, which
                            // handles both List and JSON-string shapes.
                            // ─────────────────────────────────────────────────────
                            // ✅ NEW: Prioritize FastKey API data (same as FastKeyScreen)
                            // ─────────────────────────────────────────────────────
                            List<Map<String, dynamic>> tags = [];

                            // 1. Direct from FastKey item (best source)
                            tags = _parseNestedTags(item["fast_key_item_tags"] ?? item["tags"]);

                            // 2. Fallback to cached product
                            if (tags.isEmpty) {
                              tags = _parseNestedTags(cachedProduct?["tags"] ?? cachedProduct?["fast_key_item_tags"]);
                            }

                            // 3. Final safety net
                            if (tags.isEmpty && item["meta_data"] is List) {
                              // Sometimes tags come inside meta_data in some responses
                              tags = _parseNestedTags(item["meta_data"]);
                            }


                            if (tags.isNotEmpty) {
                              print("🏷️ Tags: ${tags.map((t) => "${t['name'] ?? ''} (${t['slug'] ?? ''})").toList()}");
                            } else {
                              print("⚠️ No tags found even after all fallbacks");
                            }

                            if (kDebugMode) {
                              print(
                                  "🏷️ [NestedGrid] TAP → product=$productId "
                                      "rawTagsType=${item["fast_key_item_tags"]?.runtimeType} "
                                      "parsedTagCount=${tags.length} "
                                      "tags=${tags.map((t) => t["name"] ?? t["slug"] ?? "").toList()}");
                            }

                            // ✅ DECLARE HERE (VERY IMPORTANT)
                            bool hasVariablePriceTag = tags.any((t) {
                              final slug = (t["slug"] ?? "").toString().toLowerCase();
                              final name = (t["name"] ?? "").toString().toLowerCase();
                              return slug.contains("variable") || name.contains("variable");
                            });

                            if (kDebugMode) {
                              print("🧪 hasVariablePriceTag = $hasVariablePriceTag");
                            }

                            // 🆔 Extract core product fields
                            final productName = (item["fast_key_item_name"] is String)
                                ? item["fast_key_item_name"]
                                : item["fast_key_item_name"]?["rendered"] ?? "Unnamed Product";

                            // ⭐ EBT eligibility from Isar cache or tags
                            bool isEbtEligible =
                                item["is_ebt_eligible"] == true || cachedProduct?["is_ebt_eligible"] == true;

                            if (!isEbtEligible && tags.isNotEmpty) {
                              isEbtEligible = tags.any((t) {
                                final name = (t["name"] ?? "").toString().toLowerCase();
                                final slug = (t["slug"] ?? "").toString().toLowerCase();
                                return name.contains("ebt") || slug.contains("ebt");
                              });
                            }

                            if (kDebugMode) {
                              print(
                                  "🥗 EBT CHECK → Product: $productName | Eligible: $isEbtEligible | Cached=${cachedProduct != null}");
                            }
                            final dynamic priceSource = item["fast_key_item_price"] ??
                                item["price"] ??
                                cachedProduct?["fast_key_item_price"] ??
                                cachedProduct?["price"];
                            var productPrice =
                                double.tryParse(priceSource?.toString() ?? "0") ?? 0.0;

                            if (kDebugMode) {
                              final itemPrice = item["fast_key_item_price"] ?? item["price"];
                              final cachedPrice = cachedProduct?["fast_key_item_price"] ?? cachedProduct?["price"];
                              print("💰 PRICE SOURCE → Item: $itemPrice | Cached: $cachedPrice | Final: $productPrice");
                            }

                            final productSku =
                                cachedProduct?["sku"] ?? item["fast_key_item_sku"] ?? "SKU-$productId";

                            final dynamic rawImage =
                                cachedProduct?["fast_key_item_image"] ??
                                    cachedProduct?["image"] ??
                                    item["fast_key_item_image"];
                            final productImage = rawImage is String
                                ? rawImage
                                : (rawImage is Map ? rawImage["src"] ?? "" : "");

                            // ✅ Detect variants & restrictions
                            // Use the same rules as FastKey screen + DB flag so
                            // tap behaviour matches category grid behaviour.
                            final dynamic hvDb = item['fast_key_item_has_variant'];
                            final bool hasVariantFromApiRow =
                                hvDb == 1 || hvDb == true || hvDb == '1';

                            final String typeStr =
                            (item["type"] ?? cachedProduct?["type"] ?? "")
                                .toString()
                                .toLowerCase();

                            final bool hasVariants =
                                hasVariantFromApiRow ||
                                    (cachedProduct?["has_variants"] == true) ||
                                    typeStr == "variable" ||
                                    (item["variations"] != null &&
                                        item["variations"].isNotEmpty);

                            // 🔞 Detect min age (field OR tags)
                            final dynamic minAgeSource =
                                cachedProduct?["min_age"] ?? item["fast_key_item_min_age"];
                            int minAge =
                                int.tryParse(minAgeSource?.toString() ?? "0") ?? 0;

// ✅ FALLBACK → derive from tags (VERY IMPORTANT)
                            if (minAge == 0) {
                              for (final t in tags) {
                                final name = (t["name"] ?? "").toString().toLowerCase();
                                final slug = (t["slug"] ?? "").toString();

                                if (name.contains("age") || name.contains("restricted")) {
                                  final parsedAge = int.tryParse(slug);
                                  if (parsedAge != null && parsedAge > 0) {
                                    minAge = parsedAge;
                                    break;
                                  }
                                  minAge = 18;
                                  break;
                                }
                              }
                            }

                            final bool hasAgeRestriction = minAge > 0;

                            if (kDebugMode) {
                              print("🔞 Age detection → hasAgeRestriction=$hasAgeRestriction, minAge=$minAge");
                            }

                            int loyaltyPoints = 0;
// Read from item meta_data
                            if (item['meta_data'] is List) {
                              for (var m in item['meta_data']) {
                                if (m is Map && m['key'] == '_product_loyalty_points') {
                                  loyaltyPoints = int.tryParse(m['value'].toString()) ?? 0;
                                  break;
                                }
                              }
                            }

                            print("🎯 LOYALTY POINTS forrrrrrrr ${productName}: $loyaltyPoints");

                            // ==================== END LOYALTY ====================
                            print(
                                "🔍 Product details: id=$productId, name=$productName, price=$productPrice, hasVariants=$hasVariants, hasAgeRestriction=$hasAgeRestriction, minAge=$minAge");

                            // 🧠 Init or restore offline order
                            final box = StorageProvider.offlineOrders;
                            int activeOrderId =
                                orderHelper.activeOrderId ?? (await box.get('lastOrderId')) ?? 1000;

                            if (orderHelper.activeOrderId == null) {
                              orderHelper.activeOrderId = activeOrderId;
                              await box.put('lastOrderId', activeOrderId);
                            }

                            print("🆔 Active Order ID: $activeOrderId");

                            // 🔞 Age Verification Flow
                            if (hasAgeRestriction && minAge > 0) {
                              print("🔞 Age restriction detected → Checking verification for order $activeOrderId...");
                              // Use SAME age key as barcode scan flow
                              // Use SAME age key as barcode scan flow
                              final orderKey = activeOrderId.toString();
                              final rawOrder = await box.get(orderKey);
                              final hiveOrder = Map<String, dynamic>.from(
                                rawOrder is Map ? rawOrder : {},
                              );

                              final alreadyVerified =
                                  hiveOrder["age_verified"] == true ||
                                      hiveOrder["age_verified"] == 1 ||
                                      hiveOrder["age_verified"]?.toString().toLowerCase() == "true";

                              if (alreadyVerified) {
                                print("✅ Age already verified → Skipping popup (Unified).");
                              } else {
                                print("🔞 Showing Age Verification Popup (Unified)");

                                // FIX → create provider
                                final prov = AgeVerificationProvider();

                                final isVerified =
                                await prov.verifyAge(context, minAge: minAge);

                                if (!isVerified) {
                                  print("❌ Age verification failed → Product blocked");
                                  return;
                                }

                                // SAVE SUCCESS FLAG
                                hiveOrder["age_verified"] = true;
                                await box.put(orderKey, hiveOrder);

                                print("💾 Saved age_verified = TRUE for order $orderKey");
                              }

                            } else {
                              print("✅ No age restriction for this product.");

                            }


                            //  PRODUCE (WEIGHED ITEMS) HANDLING
                            // final bool hasProduceTag = tags.any((t) {
                            //   final slug = (t["slug"] ?? "").toString().toLowerCase();
                            //   final name = (t["name"] ?? "").toString().toLowerCase();
                            //   return slug.contains("produce") || name.contains("produce");
                            // });
                            //
                            // if (hasProduceTag) {
                            //   print(" Produce product detected → Showing AutoWeightPriceDialog");
                            //
                            //   // Show AutoWeightPriceDialog
                            //   final result = await showDialog(
                            //     context: context,
                            //     barrierDismissible: false,
                            //     builder: (_) => AutoWeightPriceDialog(
                            //       productName: productName,
                            //       unitPrice: productPrice,
                            //     ),
                            //   );
                            //
                            //   if (result == null) {
                            //     print(" Auto weight cancelled");
                            //     return;
                            //   }
                            //
                            //   final double finalPrice = result["finalPrice"];
                            //   final double weight = result["weight"];
                            //
                            //   print(" Weight: ${weight}kg, Final Price: ₹$finalPrice");
                            //
                            //   await orderHelper.addItemToOrder(
                            //     null,
                            //     productName,
                            //     productImage,
                            //     finalPrice,
                            //     1, // quantity is 1 since weight determines the amount
                            //     productSku,
                            //     activeOrderId,
                            //     type: 'weighted', // Use a special type for weighed items
                            //     weightQty: weight,
                            //     productId: productId,
                            //     variationId: -1,
                            //     salesPrice: finalPrice,
                            //     regularPrice: productPrice,
                            //     unitPrice: productPrice,
                            //     isEbtEligible: isEbtEligible,
                            //     // You might want to store weight info in metadata
                            //     // metaData: {
                            //     //   'weight': weight,
                            //     //   'unit': 'kg',
                            //     // },
                            //     onItemAdded: () async {
                            //       print(" Weighted product added successfully!");
                            //       onItemTapped(index, variantAdded: false);
                            //     },
                            //   );
                            //
                            //   return; //  IMPORTANT: Stop further processing
                            // }


// ─────────────────────────────────────────────────────────────────────────────
// PRODUCE / WEIGHTED ITEM — Use LIVE scale weight + Clear after add
// ─────────────────────────────────────────────────────────────────────────────
                            final bool hasProduceTag = tags.any((t) {
                              final slug = (t["slug"] ?? "").toString().toLowerCase();
                              final name = (t["name"] ?? "").toString().toLowerCase();
                              return slug.contains("produce") || name.contains("produce");
                            });

                            // 🔧 FIX: diagnostic print so it's obvious in logs
                            // whether the produce tag was actually detected —
                            // this was previously impossible to tell from the
                            // logs when `tags` silently came back empty.
                            if (kDebugMode) {
                              print(
                                  "🧺 [NestedGrid] hasProduceTag=$hasProduceTag "
                                      "product=$productId tagCount=${tags.length}");
                            }

                            if (hasProduceTag) {
                              final weightProvider = Provider.of<WeightProvider>(context, listen: false);

                              // weightText already holds the value in the scale's native unit (kg here) —
                              // same as TopBar. Do NOT apply an lb→kg conversion on top of it.
                              double liveWeight = 0.0;
                              try {
                                final parts = weightProvider.weightText.trim().split(' ');
                                if (parts.isNotEmpty) {
                                  liveWeight = double.tryParse(parts[0]) ?? 0.0;
                                }
                              } catch (_) {}

                              // Fallback only if scale hasn't reported anything yet
                              final double weightToUse = liveWeight > 0.00001 ? liveWeight : 0.0001;

                              final double finalPrice = productPrice * weightToUse;

                              // Add the item
                              await orderHelper.addItemToOrder(
                                null,
                                productName,
                                productImage,
                                finalPrice,
                                1,
                                productSku,
                                activeOrderId,
                                type: 'weighted',
                                weightQty: weightToUse,
                                productId: productId,
                                variationId: -1,
                                salesPrice: finalPrice,
                                regularPrice: productPrice,
                                unitPrice: productPrice,
                                isEbtEligible: isEbtEligible,
                                metaData: item['meta_data'] is List
                                    ? List<Map<String, dynamic>>.from(item['meta_data'])
                                    : null,
                                loyaltyPoints: loyaltyPoints,
                                onItemAdded: () async {
                                  print(" Weighted product added successfully!");
                                  onItemTapped(index, variantAdded: false);
                                },
                              );
                              return;
                            }



// 💰 Variable Price (Manual Entry)
                            // 💰 Variable Price (Manual Entry)
                            double finalPrice = productPrice;

// RUN THIS BEFORE ANY POPUP
                            if (hasVariablePriceTag && !hasVariants) {
                              print("💰 Variable price product detected → Checking global first-add status…");

                              final orderKey = activeOrderId.toString();
                              final rawOrder = await box.get(orderKey);
                              final hiveOrder = Map<String, dynamic>.from(
                                rawOrder is Map ? rawOrder : {},
                              );

                              final variableKey = "variable_price_added_$productId";
                              final savedPriceKey = "selected_price_$productId";
                              final savedPrice = hiveOrder[savedPriceKey];

                              if (savedPrice != null) {
                                print("🔁 Auto-loading saved manual price for productId=$productId → ₹$savedPrice");
                                productPrice = savedPrice; // <-- FORCE OVERRIDE DEFAULT PRICE
                              }

                              // ⛔ GLOBAL CHECK: Has popup been shown before?
                              final alreadyAddedBefore =
                                  hiveOrder[variableKey] == true ||
                                      hiveOrder[variableKey] == 1 ||
                                      hiveOrder[variableKey]?.toString().toLowerCase() == "true";

                              // -------------------------------------------------------------
                              //1️⃣ PRODUCT ADDED BEFORE → SKIP POPUP ALWAYS
                              // -------------------------------------------------------------
                              if (alreadyAddedBefore) {
                                print("🔁 Variable product already added earlier → SKIPPING POPUP → increment quantity");

                                // Load saved manual price
                                final savedPrice = hiveOrder[savedPriceKey];
                                finalPrice = savedPrice ?? productPrice;

                                await orderHelper.addItemToOrder(
                                  null,
                                  productName,
                                  productImage,
                                  finalPrice,
                                  1,
                                  productSku,
                                  activeOrderId,
                                  type: 'product',
                                  productId: productId,
                                  variationId: -1,
                                  salesPrice: finalPrice,
                                  regularPrice: finalPrice,
                                  unitPrice: finalPrice,
                                  isEbtEligible: isEbtEligible,
                                  metaData: item['meta_data'] is List
                                      ? List<Map<String, dynamic>>.from(item['meta_data'])
                                      : null,
                                  loyaltyPoints: loyaltyPoints,
                                  onItemAdded: () async {
                                    //await orderHelper.loadData();
                                  },
                                );

                                onItemTapped(index, variantAdded: false);
                                return; //  VERY IMPORTANT — stop popup here
                              }

                              // -------------------------------------------------------------
                              // 2️⃣ FIRST TIME EVER → SHOW POPUP
                              // -------------------------------------------------------------
                              print("💰 First-time variable product → showing manual price popup");

                              final enteredPrice = await ManualPriceDialog.show(
                                context,
                                productName: productName,
                                productImage: productImage,
                                minPrice: productPrice,
                              );

                              if (enteredPrice == null) {
                                print("❌ Manual price cancelled");
                                return;
                              }

                              finalPrice = enteredPrice;

                              // SAVE FLAGS
                              hiveOrder[variableKey] = true;       // mark popup shown
                              hiveOrder[savedPriceKey] = finalPrice; // store price

                              await box.put(orderKey, hiveOrder);

                              print("💾 Stored $variableKey = true");
                              print("💾 Stored $savedPriceKey = $finalPrice");
                            }

                            // 🧩 Variant Handling
                            if (hasVariants) {
                              if (kDebugMode) {
                                print("🧩 Product has variants → Loading offline variants...");
                              }
                              // Show loading immediately for instant feedback
                              bool loadingDialogShown = false;
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => PopScope(
                                    canPop: false,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                                loadingDialogShown = true;
                              }

                              List<Map<String, dynamic>> offlineVariations = [];

                              try {
                                final productBox = StorageProvider.productCache;
                                final cacheKey = "product_${productId}_variations";
                                final cachedData = await productBox.get(cacheKey);
                                if (kDebugMode) {
                                  print("📦 Checking cachedData for key=$cacheKey");
                                }

                                List rawVariations = [];

                                // 🔹 Try cached data
                                if (cachedData != null) {
                                  if (cachedData is Map && cachedData["variations"] is List) {
                                    rawVariations = cachedData["variations"];
                                  } else if (cachedData is List) {
                                    rawVariations = cachedData;
                                  } else if (cachedData is String) {
                                    try {
                                      final decoded = jsonDecode(cachedData);
                                      rawVariations =
                                      decoded is Map ? decoded["variations"] ?? [] : decoded;
                                    } catch (_) {
                                      if (kDebugMode) {
                                        print("⚠️ Error decoding cachedData string");
                                      }
                                    }
                                  }
                                }

                                // 🩵 Fallback: Try item["variations"] if cache is empty (parallel lookups)
                                if (rawVariations.isEmpty && item["variations"] != null) {
                                  final variationIds = item["variations"] as List;
                                  final results = await Future.wait(
                                    variationIds.map((id) => productBox.get("product_$id")),
                                  );
                                  for (var i = 0; i < variationIds.length; i++) {
                                    final id = variationIds[i];
                                    var variantData = results[i];

                                    if (variantData == null) {
                                      if (kDebugMode) {
                                        print("⚠️ No cache found for variant id=$id, using fallback");
                                      }
                                      continue;
                                    }

                                    if (variantData is String) {
                                      try {
                                        variantData = jsonDecode(variantData);
                                      } catch (_) {}
                                    }

                                    String name = "";
                                    if (variantData?["name"] != null &&
                                        variantData["name"].toString().isNotEmpty) {
                                      name = variantData["name"];
                                    } else if (variantData?["attributes"] != null &&
                                        variantData["attributes"] is List &&
                                        (variantData["attributes"] as List).isNotEmpty) {
                                      name = (variantData["attributes"] as List)
                                          .map((a) => a["option"] ?? "")
                                          .where((o) => o.toString().isNotEmpty)
                                          .join(", ");
                                    } else {
                                      name = "Variant $id";
                                    }

                                    final price = (variantData?["price"] ??
                                        variantData?["regular_price"] ??
                                        variantData?["sale_price"] ??
                                        productPrice)
                                        .toString();

                                    final image = (variantData?["image"] is Map)
                                        ? variantData["image"]["src"] ?? productImage
                                        : (variantData?["image"] ?? productImage);

                                    // ✅ Extract meta_data from variantData
                                    List<Map<String, dynamic>> metaData = [];
                                    if (variantData?["meta_data"] is List) {
                                      metaData = (variantData["meta_data"] as List)
                                          .whereType<Map>()
                                          .map((m) => Map<String, dynamic>.from(m))
                                          .toList();
                                    }

                                    // ✅ Extract loyalty points
                                    final loyaltyEntry = metaData.firstWhere(
                                          (m) => m['key'] == '_product_loyalty_points',
                                      orElse: () => <String, dynamic>{},
                                    );
                                    final int loyaltyPoints = loyaltyEntry.isNotEmpty
                                        ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
                                        : 0;

                                    rawVariations.add({
                                      "id": id,
                                      "name": name,
                                      "price": price,
                                      "sku": variantData?["sku"] ?? "",
                                      "image": image,
                                      "meta_data": metaData,  // ✅ Preserve meta_data
                                      "loyalty_points": loyaltyPoints,  // ✅ Store loyalty points
                                    });
                                  }

                                  if (kDebugMode) {
                                    print("📥 Built ${rawVariations.length} variant objects manually.");
                                  }
                                }

// 🧠 Normalize all variants with meta_data preservation
                                offlineVariations = rawVariations.map<Map<String, dynamic>>((v) {
                                  if (v is String) {
                                    try {
                                      v = jsonDecode(v);
                                    } catch (_) {}
                                  }
                                  if (v is Map) {
                                    final map = v.map((key, value) => MapEntry(key.toString(), value));

                                    map["image"] = (map["image"] is Map && map["image"]["src"] != null)
                                        ? map["image"]["src"]
                                        : (map["image"] is String ? map["image"] : "");
                                    map["name"] = (map["name"] is Map &&
                                        map["name"]["rendered"] != null)
                                        ? map["name"]["rendered"]
                                        : (map["name"] is String
                                        ? map["name"]
                                        : "Unnamed Variant");
                                    map["price"] = map["price"]?.toString() ?? "0";

                                    // ✅ Preserve meta_data
                                    if (map["meta_data"] is! List) {
                                      map["meta_data"] = <Map<String, dynamic>>[];
                                    }

                                    // ✅ Ensure loyalty_points is set
                                    if (map["loyalty_points"] == null || map["loyalty_points"] == 0) {
                                      final metaData = map["meta_data"] as List<Map<String, dynamic>>;
                                      final loyaltyEntry = metaData.firstWhere(
                                            (m) => m['key'] == '_product_loyalty_points',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (loyaltyEntry.isNotEmpty) {
                                        map["loyalty_points"] = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                      } else {
                                        map["loyalty_points"] = 0;
                                      }
                                    }

                                    return map;
                                  }
                                  return <String, dynamic>{};
                                }).where((v) => v.isNotEmpty).toList();

                                if (kDebugMode) {
                                  print("✅ Found ${offlineVariations.length} offline variants.");
                                }

                                // 🧩 Auto-refetch if variants are incomplete
                                final allSameAsParent = offlineVariations.isEmpty ||
                                    offlineVariations
                                        .every((v) => v["price"].toString() == productPrice.toString());

                                if (allSameAsParent) {
                                  // print("🔁 Cached variants incomplete → Refetching from API...");
                                  // await ProductRepository().fetchProductVariations(productId);
                                  //
                                  // final refreshed = await productBox.get(cacheKey);
                                  // if (refreshed is Map && refreshed["variations"] is List) {
                                  //   offlineVariations = (refreshed["variations"] as List)
                                  //       .map((v) => Map<String, dynamic>.from(v as Map))
                                  //       .toList();
                                  // }
                                }
                              } catch (e, st) {
                                if (kDebugMode) {
                                  print("⚠️ Error decoding offline variations: $e");
                                  print(st);
                                }
                              }

                              // 🔥 Same as category screen: fetch WooCommerce variations when cache is empty
                              if (offlineVariations.isEmpty && productId > 0) {
                                final fetched =
                                await _fetchVariationsFromApiNestedGrid(productId);
                                if (fetched.isNotEmpty) {
                                  offlineVariations = fetched;
                                  try {
                                    final box = StorageProvider.productCache;
                                    await box.put(
                                      "product_${productId}_variations",
                                      {
                                        "variations": fetched,
                                        "timestamp":
                                        DateTime.now().toIso8601String(),
                                      },
                                    );
                                  } catch (_) {}
                                }
                              }

                              if (offlineVariations.isEmpty) {
                                if (context.mounted && loadingDialogShown) {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "No variants available for this product right now.",
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                                return;
                              }

                              // Dismiss loading dialog before showing VariantsDialog
                              if (context.mounted && loadingDialogShown) {
                                Navigator.of(context, rootNavigator: true).pop();
                              }

                              // 🪟 Show VariantsDialog
                              if (kDebugMode) {
                                print("🪟 Showing VariantsDialog for $productName...");
                              }
                              // 🪟 Show VariantsDialog
                              if (kDebugMode) {
                                print("🪟 Showing VariantsDialog for $productName...");
                              }
                              await showDialog(
                                context: context,
                                builder: (ctx) => VariantsDialog(
                                  title: productName,
                                  variations: offlineVariations,
                                  onAddVariant: (selectedVariant, qty) async {
                                    final variantId =
                                        int.tryParse(selectedVariant["id"].toString()) ?? -1;
                                    final variantName =
                                        selectedVariant["name"] ?? "Variant";
                                    final variantPrice =
                                        double.tryParse(selectedVariant["price"].toString()) ??
                                            productPrice;
                                    final variantSku =
                                        selectedVariant["sku"] ?? productSku;
                                    final variantImage =
                                        selectedVariant["image"] ?? productImage;

                                    // ✅ CRITICAL: Extract meta_data from selected variant
                                    List<Map<String, dynamic>> variantMetaData = [];
                                    int variantLoyaltyPoints = 0;

                                    // Try to get meta_data from selectedVariant
                                    if (selectedVariant["meta_data"] is List) {
                                      variantMetaData = (selectedVariant["meta_data"] as List)
                                          .whereType<Map>()
                                          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
                                          .toList();

                                      // Extract loyalty from meta_data
                                      final loyaltyEntry = variantMetaData.firstWhere(
                                            (m) => m['key'] == '_product_loyalty_points',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (loyaltyEntry.isNotEmpty) {
                                        variantLoyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                      }
                                    }

                                    // If no loyalty from meta_data, try direct field
                                    if (variantLoyaltyPoints == 0 && selectedVariant["loyalty_points"] != null) {
                                      variantLoyaltyPoints = int.tryParse(selectedVariant["loyalty_points"].toString()) ?? 0;
                                    }

                                    // If still 0, try parent product's loyalty points (fallback)
                                    if (variantLoyaltyPoints == 0) {
                                      final parentMeta = item['meta_data'];
                                      if (parentMeta is List) {
                                        final parentLoyalty = parentMeta.firstWhere(
                                              (m) => m['key'] == '_product_loyalty_points',
                                          orElse: () => <String, dynamic>{},
                                        );
                                        if (parentLoyalty.isNotEmpty) {
                                          variantLoyaltyPoints = int.tryParse(parentLoyalty['value']?.toString() ?? '0') ?? 0;
                                          print('🔄 [NestedGrid] Using parent loyalty points: $variantLoyaltyPoints');
                                        }
                                      }
                                    }

                                    print('🛒 [NestedGrid] Added variant: $variantName');
                                    print('  → Variant ID: $variantId');
                                    print('  → Variant Price: $variantPrice');
                                    print('  → MetaData count: ${variantMetaData.length}');
                                    print('  → Loyalty Points: $variantLoyaltyPoints');

                                    // ✅ Pass variant loyalty points to order
                                    await orderHelper.addItemToOrder(
                                      0,
                                      "$variantName",
                                      variantImage,
                                      variantPrice,
                                      qty,
                                      variantSku,
                                      activeOrderId,
                                      type: 'variant',
                                      productId: productId,
                                      variationId: variantId,
                                      variationName: variantName,
                                      salesPrice: variantPrice,
                                      regularPrice: variantPrice,
                                      unitPrice: variantPrice,
                                      isEbtEligible: isEbtEligible,
                                      metaData: variantMetaData,  // ✅ Pass variant's meta_data
                                      loyaltyPoints: variantLoyaltyPoints,  // ✅ Pass variant's loyalty points
                                      onItemAdded: () async {
                                        print("✅ Variant item added successfully!");
                                        onItemTapped(index, variantAdded: false);
                                      },
                                    );
                                  },
                                ),
                              );
                              print("🪟 VariantsDialog closed for $productName");
                            } else {
                              // 🟩 Simple Product
                              print("🟩 Simple product, adding directly...");


// ✅ Extract loyalty points from item
                              int simpleLoyaltyPoints = 0;
                              if (item['meta_data'] is List) {
                                final loyaltyEntry = (item['meta_data'] as List).firstWhere(
                                      (m) => m['key'] == '_product_loyalty_points',
                                  orElse: () => <String, dynamic>{},
                                );
                                if (loyaltyEntry.isNotEmpty) {
                                  simpleLoyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                }
                              }
                              await orderHelper.addItemToOrder(
                                null,
                                productName,
                                productImage,
                                finalPrice,
                                1,
                                productSku,
                                activeOrderId,
                                type: 'product',
                                productId: productId,
                                variationId: -1,
                                salesPrice: finalPrice,
                                regularPrice: finalPrice,
                                unitPrice: finalPrice,
                                isEbtEligible: isEbtEligible,
                                metaData: item['meta_data'] is List
                                    ? List<Map<String, dynamic>>.from(item['meta_data'])
                                    : null,
                                loyaltyPoints: simpleLoyaltyPoints,
                                onItemAdded: () async {
                                  print(" Simple product added successfully!");
                                  print("print : $loyaltyPoints");
                                  onItemTapped(index, variantAdded: false);
                                },
                              );
                            }

                            print("🎉 Product flow completed for → $productName");
                          } catch (e, s) {
                            print("❌ ERROR in offline onTap: $e");
                            print(s);
                          } finally {
                            _productTapInFlight = false;
                          }
                        },
                        onLongPress: () {
                          if (onLongPress != null) {
                            // Build #1.0.204
                            onLongPress!(
                                itemIndex); // Safe to use ! since we checked for null
                            if (kDebugMode) {
                              print("### TEST onLongPress");
                            }
                          } else {
                            if (kDebugMode) {
                              print("### onLongPress is null, skipping");
                            }
                          }
                        },
                        child: _getCardWidget(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0), // Reduced padding
                            child: Row(
                              children: [
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["fast_key_item_name"],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? ThemeNotifier.textDark
                                              : ThemeNotifier.textLight,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),

                                      // ── Price + badges row ─────────────────────────────
                                      Row(
                                        children: [
                                          Text(
                                            '${TextConstants.currencySymbol}${double.tryParse(item["fast_key_item_price"].toString())?.toStringAsFixed(2) ?? "0.00"}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: themeHelper.themeMode == ThemeMode.dark
                                                  ? ThemeNotifier.textDark
                                                  : ThemeNotifier.textLight,
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // ✅ Variant icon (truthy flags + tag-based variable)
                                          if (showVariantIcon ||
                                              _isVariableProduct(item))
                                            SvgPicture.asset(
                                              SvgUtils.variationIcon,
                                              height: 10,
                                              width: 10,
                                            ),

                                          const SizedBox(width: 4),

                                          // ✅ EBT badge — same style as categories screen
                                          if (showEbtTag)
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade600,
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'EBT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          themeHelper,
                        ),
                      ),
                      if (enableIcons == true &&
                          itemIndex ==
                              selectedItemIndex) // Build #1.0.204: Show icons only for long-pressed item
                        Positioned(
                          top: -5,
                          right: -2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDeleteButton)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () => onDeleteItem(itemIndex),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.grey, size: 20),
                                onPressed: onCancelReorder,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            /// 🔥 PAGINATION LOADER (FLOATING – NO GAP)
            if (isPaginating)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE74C3C),
                      ),
                    ),
                  ),
                ),
              ),

          ],
>>>>>>> origin/Grocery_pch_api_integration
        ),
      ),
    );
  }

  /// Customize products card layout for the grid, here
  // pass widget - contents of the card
  // themeHelper - to support dark and light theme background
  // optional accentColor - to apply changes in shadow and border color
<<<<<<< HEAD
  Widget _getCardWidget(Widget widget, ThemeNotifier themeHelper, {MaterialAccentColor accentColor = Colors.blueAccent}){
    return Card(
      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground :Colors.white,/// card color
      elevation: 3,
      shadowColor: accentColor, /// card shadow color
      clipBehavior: Clip.antiAliasWithSaveLayer ,
      shape: RoundedRectangleBorder( /// Optional: remove if no border required
        side: BorderSide(
          color: accentColor, /// Color of the border
          width: 0.5,         /// Thickness of the border
        ),
        borderRadius: BorderRadius.circular(15.0), // Optional: for rounded corners
=======
  Widget _getCardWidget(Widget widget, ThemeNotifier themeHelper,
      {MaterialAccentColor accentColor = Colors.blueAccent}) {
    return Card(
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Colors.white,

      /// card color
      elevation: 5,
      shadowColor: accentColor,

      /// card shadow color
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        /// Optional: remove if no border required
        side: BorderSide(
          color: accentColor,

          /// Color of the border
          width: 0.5,

          /// Thickness of the border
        ),
        borderRadius:
        BorderRadius.circular(15.0), // Optional: for rounded corners
>>>>>>> origin/Grocery_pch_api_integration
      ),
      child: widget,
    );
  }

<<<<<<< HEAD
  Future<void> updateOrderPanel(int index) async{
=======
  Future<void> updateOrderPanel(int index) async {
>>>>>>> origin/Grocery_pch_api_integration
    // Navigator.pop(context);
    onItemTapped(index, variantAdded: true);
  }

<<<<<<< HEAD
//   Future<bool> _ageRestrictedProduct(BuildContext context, {int minAge = 0}) async {
//     ///@
// //
// // ANSI 636026100102DL00410277ZA03180012DLDAQD05848559 DCSBELE SHRAVAN DDEN DACKUMAR DDFNvDADNONEaDDGNrDCAD DCBNONEtDCDNONEaDBD02052025gDBB07181978gDBA09032030 DBC1=DAU070 in DAYBROpDAG233 W FELLARS DRrDAIPHOENIXoDAJAZdDAK850237501  uDCF003402EB0B124005cDCGUSAtDCK48102972534.DDAFtDDB02282023aDDD1gDAZBLKsDAW196?DDK1
// //     ZAZAAN.ZACN
//
//     var isVerified = false;
//     if (kDebugMode) {
//       print("Fast Key _ageRestrictedProduct hasAgeRestriction = $minAge");
//     }
//     var hasAgeRestriction = minAge != 0;
//     if (hasAgeRestriction) {
//       await AgeVerificationHelper.showAgeVerification(
//         context: context,
//         // productName: product.name,
//         minimumAge: minAge,
//         onManualVerify: () {
//           // Add product to cart - manually verified
//           // _addToCart(product);
//           isVerified = true;
//         },
//         onAgeVerified: () {
//           // Add product to cart - age verified
//           // _addToCart(product);
//           isVerified = true;
//         },
//         onCancel: () {
//           // User cancelled - don't add to cart
//           isVerified = false;
//           Navigator.pop(context);
//         },
//       );
//     } else {
//       isVerified = true;
//     }
//     return isVerified;
//   }
=======
}

// ── Fast Keys: SKU Hive enrich + WooCommerce variations API (category parity) ──

Future<void> _enrichFastKeyItemSkuForNested(Map<String, dynamic> item) async {
  final sku = (item['fast_key_item_sku'] ?? '').toString().trim();
  if (sku.isEmpty || sku == 'N/A') return;

  try {
    final box = StorageProvider.productCache;
    final raw = await box.get('sku_${sku.toLowerCase()}');
    if (raw is! Map) return;

    final products = raw['products'];
    if (products is! List || products.isEmpty) return;

    final first = products.first;
    if (first is! Map) return;

    final p = Map<String, dynamic>.from(first);

    // Core fields
    if (p['type'] != null) item['type'] = p['type'];
    if (p['variations'] is List) item['variations'] = p['variations'];
    if (p['tags'] != null) item['fast_key_item_tags'] = p['tags'];
    if (p['meta_data'] != null) item['meta_data'] = p['meta_data'];

    // EBT
    if (_truthyEbtNested(p['is_ebt_eligible']) || _ebtMetaNested(p['meta_data'])) {
      item['is_ebt_eligible'] = true;
    }

    // Price / Name fallback
    if (p['price'] != null) item['fast_key_item_price'] = p['price'];
    if (p['name'] != null) item['fast_key_item_name'] = p['name'];
  } catch (e) {
    if (kDebugMode) print("⚠️ _enrichFastKeyItemSkuForNested error: $e");
  }
}

bool _truthyEbtNested(dynamic v) {
  if (v == true || v == 1) return true;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

bool _ebtMetaNested(dynamic meta) {
  if (meta is! List) return false;
  for (final m in meta) {
    if (m is! Map) continue;
    final key = (m['key'] ?? '').toString().toLowerCase();
    if (key != '_is_ebt_eligible' &&
        key != 'is_ebt_eligible' &&
        key != '_ebt_eligible') {
      continue;
    }
    if (_truthyEbtNested(m['value'])) return true;
  }
  return false;
}

Future<String> _getAuthTokenForNestedGrid() async {
  final db = await DBHelper.instance.database;
  final result = await db.query(
    AppDBConst.userTable,
    where:
    '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
    orderBy: '${AppDBConst.userId} DESC',
    limit: 1,
  );
  if (result.isEmpty) {
    throw Exception('No active user token found');
  }
  return result.first[AppDBConst.userToken] as String;
}

Future<List<Map<String, dynamic>>> _fetchVariationsFromApiNestedGrid(
    int productId) async {
  try {
    final token = await _getAuthTokenForNestedGrid();
    // Connector: GET /store/{storeId}/products/{productId}/variations
    final urlString =
    await ProductRepository.buildVariationsUrl(productId);
    final url = Uri.parse(urlString);
    final response =
    await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode != 200) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .whereType<Map>()
        .map<Map<String, dynamic>>((v) {
      final map = v.map((key, value) => MapEntry(key.toString(), value));
      final attrs = map["attributes"];
      final String fallbackName = attrs is List
          ? attrs
          .whereType<Map>()
          .map((a) => (a["option"] ?? "").toString())
          .where((x) => x.isNotEmpty)
          .join(" - ")
          : "";

      // ✅ Extract meta_data from variant
      final List<Map<String, dynamic>> metaData = (map["meta_data"] is List)
          ? (map["meta_data"] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList()
          : <Map<String, dynamic>>[];

      // ✅ Extract loyalty points from meta_data
      final loyaltyEntry = metaData.firstWhere(
            (m) => m['key'] == '_product_loyalty_points',
        orElse: () => <String, dynamic>{},
      );
      final int loyaltyPoints = loyaltyEntry.isNotEmpty
          ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
          : 0;

      if (kDebugMode) {
        print("🔹 [NestedGrid Variations API] id=${map['id']} loyalty=$loyaltyPoints metaCount=${metaData.length}");
      }

      return {
        "id": map["id"],
        "name": (map["name"] ?? "").toString().isNotEmpty
            ? map["name"]
            : (fallbackName.isNotEmpty
            ? fallbackName
            : "Unnamed Variant"),
        "price":
        (map["price"] ?? map["regular_price"] ?? "0").toString(),
        "sku": map["sku"] ?? "",
        "image": (map["image"] is Map && map["image"]["src"] != null)
            ? map["image"]["src"]
            : (map["image"] is String ? map["image"] : ""),
        "meta_data": metaData,
        "loyalty_points": loyaltyPoints,
      };
    })
        .where((v) => v["id"] != null)
        .toList();
  } catch (e) {
    if (kDebugMode) {
      print("⚠️ _fetchVariationsFromApiNestedGrid: $e");
    }
    return <Map<String, dynamic>>[];
  }
>>>>>>> origin/Grocery_pch_api_integration
}