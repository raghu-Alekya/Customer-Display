import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Search/product_custom_item_model.dart';
import '../../Models/Search/product_by_sku_model.dart';
import '../../Models/Search/product_search_model.dart';
import '../../Models/Search/product_variation_model.dart';
import '../../Repositories/Search/product_search_repository.dart';

class ProductBloc { // Build #1.0.13: Added Product Search Bloc
  final ProductRepository _productRepository;
  late StreamController<APIResponse<List<ProductResponse>>> _productController;
  late StreamController<APIResponse<List<ProductVariation>>> _variationController;
  late StreamController<APIResponse<List<ProductBySkuResponse>>> _productBySkuController;

  // Streams and sinks for products
  StreamController<APIResponse<List<ProductResponse>>> get productController => _productController;

  StreamSink<APIResponse<List<ProductResponse>>> get productSink => _productController.sink;
  Stream<APIResponse<List<ProductResponse>>> get productStream => _productController.stream;

  // Streams and sinks for variations
  StreamController<APIResponse<List<ProductVariation>>> get variationController => _variationController;
  StreamSink<APIResponse<List<ProductVariation>>> get variationSink => _variationController.sink;
  Stream<APIResponse<List<ProductVariation>>> get variationStream => _variationController.stream;

  StreamController<APIResponse<List<ProductBySkuResponse>>> get productBySkuController => _productBySkuController;
  StreamSink<APIResponse<List<ProductBySkuResponse>>> get productBySkuSink => _productBySkuController.sink;
  Stream<APIResponse<List<ProductBySkuResponse>>> get productBySkuStream => _productBySkuController.stream;

  late StreamController<APIResponse<AddCustomItemModel>> _addCustomItemController;

  StreamController<APIResponse<AddCustomItemModel>> get addCustomItemController => _addCustomItemController;
  StreamSink<APIResponse<AddCustomItemModel>> get addCustomItemSink => _addCustomItemController.sink;
  Stream<APIResponse<AddCustomItemModel>> get addCustomItemStream => _addCustomItemController.stream;

  ProductBloc(this._productRepository) {
    if (kDebugMode) {
      print("ProductBloc Initialized");
    }
    _productController = StreamController<APIResponse<List<ProductResponse>>>.broadcast();
    _variationController = StreamController<APIResponse<List<ProductVariation>>>.broadcast();
    _productBySkuController = StreamController<APIResponse<List<ProductBySkuResponse>>>.broadcast();
    _addCustomItemController = StreamController<APIResponse<AddCustomItemModel>>.broadcast();
  }

  Future<void> fetchProducts({String? searchQuery}) async {
    if (_productController.isClosed) return;

    productSink.add(APIResponse.loading(TextConstants.loading));
    try {
      List<ProductResponse> products = await _productRepository.fetchProducts(searchQuery: searchQuery);
      if (kDebugMode) {
        print("ProductBloc - Fetched ${products.length} products");
        print("products: $products"); // Build #1.0.256: no need to print first product from response, if we get empty at that time getting issue!
      }
      productSink.add(APIResponse.completed(products));

    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        productSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        productSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        productSink.add(APIResponse.error("No products found"));
      }
      if (kDebugMode) print("ProductBloc - Exception in fetchProducts: $e");
    }
  }

  //Build 1.1.36: Added Fetches product variations Api call
  Future<void> fetchProductVariations(int productId) async {
    if (_variationController.isClosed) {
      _variationController = StreamController<APIResponse<List<ProductVariation>>>.broadcast();
      if (kDebugMode) {
        print("ProductBloc - Reinitialized variationController");
      }
    }

    variationSink.add(APIResponse.loading("Loading variations..."));
    try {
      List<ProductVariation> variations = await _productRepository.fetchProductVariations(productId);

      if (kDebugMode) {
        print("ProductBloc - Fetched ${variations.length} variations for product $productId");
        print("variations: $variations"); // Build #1.0.256
      }
      variationSink.add(APIResponse.completed(variations));

    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        variationSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        variationSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        variationSink.add(APIResponse.error("Failed to fetch variations"));
      }
      if (kDebugMode) print("ProductBloc - Exception in fetchProductVariations: $e");
    }
  }

  // Build #1.0.43: added this function for ProductBySku api call
  Future<String> fetchProductBySku(String sku) async {
    String logString = "";
    if (_productBySkuController.isClosed) {
      _productBySkuController = StreamController<APIResponse<List<ProductBySkuResponse>>>.broadcast();
      if (kDebugMode) {
        print("ProductBloc - Reinitialized _productBySkuController");
      }
      logString += "ProductBloc - Reinitialized _productBySkuController \n ";
    }

    productBySkuSink.add(APIResponse.loading(TextConstants.loading));
    try {
      List<ProductBySkuResponse> products = await _productRepository.fetchProductBySku(sku);

      if (products.isNotEmpty) {
        if (kDebugMode) {
          print("ProductBloc - Fetched ${products.length} products by SKU: $sku");
          print("products: $products"); // Build #1.0.256
        }
        logString += "ProductBloc - Fetched ${products.length} products by SKU: $sku \n ";
        logString += "products: $products \n ";
        productBySkuSink.add(APIResponse.completed(products));
      } else {
        productBySkuSink.add(APIResponse.error("No products found for SKU: $sku"));
        logString += "ProductBloc - No products found for SKU: $sku  \n ";
      }
      return logString;
    } catch (e,s) {
      if (e.toString().contains('Unauthorised')) {
        productBySkuSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        productBySkuSink.add(APIResponse.error("Network error. Please check your connection."));
        logString += "ProductBloc - Network error. Please check your connection. \n ";
      } else {
        productBySkuSink.add(APIResponse.error("Failed to fetch product by SKU"));
        logString += "ProductBloc - Failed to fetch product by SKU \n ";
      }
      if (kDebugMode) print("ProductBloc - Exception in fetchProductBySku: $e, *** Stack: $s ***");
      logString += "ProductBloc - Exception in fetchProductBySku: $e, *** Stack: $s *** \n ";
      return logString;
    }
  }

  Future<void> addCustomItem(AddCustomItemRequest request) async {
    if (_addCustomItemController.isClosed) return;

    addCustomItemSink.add(APIResponse.loading(TextConstants.loading));
    try {
      AddCustomItemModel product = await _productRepository.addCustomItem(request);
      if (kDebugMode) {
        print("ProductBloc - Created product: ${product.id}");
      }
      addCustomItemSink.add(APIResponse.completed(product));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        addCustomItemSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        addCustomItemSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        addCustomItemSink.add(APIResponse.error("Failed to create product"));
      }
      if (kDebugMode) print("ProductBloc - Exception in createProduct: $e");
    }
  }

  void dispose() {
    if (!_productController.isClosed) {
      _productController.close();
      if (kDebugMode) print("ProductBloc - ProductController disposed");
    }
    if (!_variationController.isClosed) { //Build 1.1.36
      _variationController.close();
      if (kDebugMode) print("ProductBloc - VariationController disposed");
    }
    if (!_productBySkuController.isClosed) {
      _productBySkuController.close();
      if (kDebugMode) print("ProductBloc - ProductBySkuController disposed");
    }
    if (!_addCustomItemController.isClosed) {
      _addCustomItemController.close();
      if (kDebugMode) print("ProductBloc - CreateProductController disposed");
    }
  }
}