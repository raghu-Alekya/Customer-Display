import 'dart:async';
<<<<<<< HEAD
=======
import 'dart:convert';
>>>>>>> origin/Grocery_pch_api_integration
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Repositories/FastKey/fastkey_product_repository.dart';
import '../../Database/fast_key_db_helper.dart';
import '../../Database/db_helper.dart';

<<<<<<< HEAD
class FastKeyProductBloc {  // Build #1.0.15
  final FastKeyProductRepository _repository;

  // Stream Controllers
  final StreamController<APIResponse<FastKeyProductResponse>> _addProductsController =
  StreamController<APIResponse<FastKeyProductResponse>>.broadcast();

  final StreamController<APIResponse<FastKeyProductsResponse>> _getProductsController =
  StreamController<APIResponse<FastKeyProductsResponse>>.broadcast();

  // Getters for Streams
  StreamSink<APIResponse<FastKeyProductResponse>> get addProductsSink => _addProductsController.sink;
  Stream<APIResponse<FastKeyProductResponse>> get addProductsStream => _addProductsController.stream;

  StreamSink<APIResponse<FastKeyProductsResponse>> get getProductsSink => _getProductsController.sink;
  Stream<APIResponse<FastKeyProductsResponse>> get getProductsStream => _getProductsController.stream;

  // Build #1.0.89: Added StreamController for deleteProduct
  final StreamController<APIResponse<FastKeyProductResponse>> _deleteProductController =
  StreamController<APIResponse<FastKeyProductResponse>>.broadcast();

  StreamSink<APIResponse<FastKeyProductResponse>> get deleteProductSink => _deleteProductController.sink;
  Stream<APIResponse<FastKeyProductResponse>> get deleteProductStream => _deleteProductController.stream;
=======
class FastKeyProductBloc {
  // Build #1.0.15
  final FastKeyProductRepository _repository;

  // Stream Controllers
  final StreamController<APIResponse<FastKeyProductResponse>>
  _addProductsController =
  StreamController<APIResponse<FastKeyProductResponse>>.broadcast();

  final StreamController<APIResponse<FastKeyProductsResponse>>
  _getProductsController =
  StreamController<APIResponse<FastKeyProductsResponse>>.broadcast();

  // Getters for Streams
  StreamSink<APIResponse<FastKeyProductResponse>> get addProductsSink =>
      _addProductsController.sink;
  Stream<APIResponse<FastKeyProductResponse>> get addProductsStream =>
      _addProductsController.stream;

  StreamSink<APIResponse<FastKeyProductsResponse>> get getProductsSink =>
      _getProductsController.sink;
  Stream<APIResponse<FastKeyProductsResponse>> get getProductsStream =>
      _getProductsController.stream;

  // Build #1.0.89: Added StreamController for deleteProduct
  final StreamController<APIResponse<FastKeyProductResponse>>
  _deleteProductController =
  StreamController<APIResponse<FastKeyProductResponse>>.broadcast();

  StreamSink<APIResponse<FastKeyProductResponse>> get deleteProductSink =>
      _deleteProductController.sink;
  Stream<APIResponse<FastKeyProductResponse>> get deleteProductStream =>
      _deleteProductController.stream;
>>>>>>> origin/Grocery_pch_api_integration

  FastKeyProductBloc(this._repository) {
    if (kDebugMode) {
      print("FastKeyProductBloc Initialized");
    }
  }

  // POST: Add products to FastKey
<<<<<<< HEAD
  Future<void> addProducts({required int fastKeyId, required List<FastKeyProductItem> products}) async {
=======
  Future<void> addProducts(
      {required dynamic fastKeyId,
        required List<FastKeyProductItem> products}) async {
>>>>>>> origin/Grocery_pch_api_integration
    if (_addProductsController.isClosed) return;

    addProductsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final request = FastKeyProductRequest(
        fastKeyId: fastKeyId,
        products: products,
      );

      final response = await _repository.addProductsToFastKey(request);

      if (kDebugMode) {
<<<<<<< HEAD
        print("FastKeyProductBloc - Added products to FastKey: ${response.fastkeyId}");
      }
      // Build #1.0.87: Insert into DB after successful API response
      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final fastKeyTabs = await fastKeyDBHelper.getFastKeyByServerTabId(fastKeyId);

      if (fastKeyTabs.isNotEmpty) {
        final serverTabId = fastKeyTabs.first[AppDBConst.fastKeyServerId];
        final existingItems = await fastKeyDBHelper.getFastKeyItems(serverTabId);

        if (kDebugMode) {
          print("#### LENGTH 1 : ${existingItems.length}, #### LENGTH 2 : ${response.products?.length}");
        }

        for (FastKeyProduct product in response.products ?? []) {
          var tagg = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => Tags());
          var hasAgeRestriction = tagg?.name?.contains(TextConstants.age_restricted);
          if (kDebugMode) {
            print("FastkeyBloc: fetchProductsByFastKeyId New Product added, hasAgeRestriction $hasAgeRestriction, minAge: ${tagg?.slug ?? "0"}");
=======
        print(
            "FastKeyProductBloc - Added products to FastKey: ${response.fastkeyId}");
      }
      // Build #1.0.87: Insert into DB after successful API response
      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final fastKeyTabs =
      await fastKeyDBHelper.getFastKeyByServerTabId(fastKeyId);

      if (fastKeyTabs.isNotEmpty) {
        final serverTabId = fastKeyTabs.first[AppDBConst.fastKeyServerId];
        final existingItems =
        await fastKeyDBHelper.getFastKeyItems(serverTabId);

        if (kDebugMode) {
          print(
              "#### LENGTH 1 : ${existingItems.length}, #### LENGTH 2 : ${response.products?.length}");
        }

        for (FastKeyProduct product in response.products ?? []) {
          var tagg = product.tags?.firstWhere(
                  (element) => element.name == TextConstants.age_restricted,
              orElse: () => Tags());
          var hasAgeRestriction =
          tagg?.name?.contains(TextConstants.age_restricted);
          if (kDebugMode) {
            print(
                "FastkeyBloc: fetchProductsByFastKeyId New Product added, hasAgeRestriction $hasAgeRestriction, minAge: ${tagg?.slug ?? "0"}");
>>>>>>> origin/Grocery_pch_api_integration
          }
          // Check for existing item with the same productId
          final db = await DBHelper.instance.database;
          final isDuplicate = await db.query(
            AppDBConst.fastKeyItemsTable,
<<<<<<< HEAD
            where: '${AppDBConst.fastKeyIdForeignKey} = ? AND ${AppDBConst.fastKeyProductId} = ?',
=======
            where:
            '${AppDBConst.fastKeyIdForeignKey} = ? AND ${AppDBConst.fastKeyProductId} = ?',
>>>>>>> origin/Grocery_pch_api_integration
            whereArgs: [serverTabId, product.productId],
          );
          if (isDuplicate.isEmpty) {
            await fastKeyDBHelper.addFastKeyItem(
              serverTabId,
              product.name,
              product.image,
              product.price,
              product.productId,
              slNumber: product.slNumber,
<<<<<<< HEAD
              minAge: int.parse(tagg?.slug ?? "0"),//updated in build #1.0.90
              sku: product.sku,
            );
            if (kDebugMode) {
              print("### FastKeyProductBloc: Added item ${product.name} to DB for tab ID: $serverTabId");
            }
          } else {
            if (kDebugMode) {
              print("### FastKeyProductBloc: Skipped duplicate item ${product.name} with product_id ${product.productId}");
=======
              minAge: int.tryParse(tagg?.slug ?? "0") ?? 0, //updated in build #1.0.90
              sku: product.sku,
            );
            if (kDebugMode) {
              print(
                  "### FastKeyProductBloc: Added item ${product.name} to DB for tab ID: $serverTabId");
            }
          } else {
            if (kDebugMode) {
              print(
                  "### FastKeyProductBloc: Skipped duplicate item ${product.name} with product_id ${product.productId}");
>>>>>>> origin/Grocery_pch_api_integration
            }
          }
        }

        final updatedItems = await fastKeyDBHelper.getFastKeyItems(serverTabId);
<<<<<<< HEAD
        await fastKeyDBHelper.updateFastKeyTabCount(fastKeyId, updatedItems.length);
        if (kDebugMode) {
          print("### FastKeyProductBloc: Updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
=======
        await fastKeyDBHelper.updateFastKeyTabCount(
            fastKeyId, updatedItems.length);
        if (kDebugMode) {
          print(
              "### FastKeyProductBloc: Updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
>>>>>>> origin/Grocery_pch_api_integration
        }
      }
      addProductsSink.add(APIResponse.completed(response));
    } catch (e, s) {
      if (e.toString().contains('Unauthorised')) {
<<<<<<< HEAD
        addProductsSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        addProductsSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        addProductsSink.add(APIResponse.error("Failed to add products: ${e.toString()}"));
=======
        addProductsSink
            .add(APIResponse.error("Unauthorised. Session is expired."));
      } else if (e.toString().contains('SocketException')) {
        addProductsSink.add(
            APIResponse.error("Network error. Please check your connection."));
      } else {
        addProductsSink
            .add(APIResponse.error("Failed to add products: ${e.toString()}"));
>>>>>>> origin/Grocery_pch_api_integration
      }
      if (kDebugMode) print("Exception in addProducts: $e, Stack: $s");
    }
  }

<<<<<<< HEAD
  // GET: Fetch products by FastKey ID
  Future<void> fetchProductsByFastKeyId(int fastKeyId, int fastKeyServerId) async {
=======
  Future<void> updateFastKeyProducts({
    required dynamic fastKeyId,
    required List<FastKeyProductItem> products,
  }) async {
    if (_addProductsController.isClosed) return;

    addProductsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _repository.updateFastKeyProducts(
        FastKeyProductRequest(fastKeyId: fastKeyId, products: products),
      );
      addProductsSink.add(APIResponse.completed(response));
    } catch (e, s) {
      final message = e.toString().contains('Unauthorised')
          ? 'Unauthorised. Session is expired.'
          : e.toString().contains('SocketException')
              ? 'Network error. Please check your connection.'
              : 'Failed to update FastKey products: ${e.toString()}';
      addProductsSink.add(APIResponse.error(message));
      if (kDebugMode) {
        print("Exception in updateFastKeyProducts: $e, Stack: $s");
      }
    }
  }

  // GET: Fetch products by FastKey ID
  // GET: Fetch products by FastKey ID
  Future<void> fetchProductsByFastKeyId(
      dynamic fastKeyId, dynamic fastKeyServerId) async {
>>>>>>> origin/Grocery_pch_api_integration
    if (_getProductsController.isClosed) return;

    getProductsSink.add(APIResponse.loading(TextConstants.loading));
    try {
<<<<<<< HEAD
      final response = await _repository.getProductsByFastKeyId(fastKeyServerId);

      if (kDebugMode) {
        print("FastKeyProductBloc - Fetched ${response.products.length} products for FastKey $fastKeyId, FastKeyServer $fastKeyServerId");
=======
      final response =
      await _repository.getProductsByFastKeyId(fastKeyServerId);

      if (kDebugMode) {
        print(
            "FastKeyProductBloc - Fetched ${response.products.length} products for FastKey $fastKeyId, FastKeyServer $fastKeyServerId");
>>>>>>> origin/Grocery_pch_api_integration
      }

      ///insert into DB

      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final fastKeyItems = await fastKeyDBHelper.getFastKeyItems(fastKeyId);
      if (kDebugMode) {
<<<<<<< HEAD
        print("#### fastKeyDBHelper.getFastKeyItems($fastKeyId) : $fastKeyItems ");
      }
      if(fastKeyItems.length != response.products.length){
        if (kDebugMode) {
          print("#### fastKeyDBHelper deleteAllFastKeyProductItems called... ${fastKeyItems.length != response.products.length}");
        }
        ///if all the data mismatches then delete all db contents and replace with API response
        fastKeyDBHelper.deleteAllFastKeyProductItems(fastKeyId);
        for(var product in response.products){ ///Naveen: add few paramter as product_id, sl_number, and make price as string only
          var tagg = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => Tags());
          var hasAgeRestriction = tagg?.name?.contains(TextConstants.age_restricted);
          if (kDebugMode) {
            print("FastkeyBloc: fetchProductsByFastKeyId New Product added, hasAgeRestriction $hasAgeRestriction for product ${product.name} ${product.productId}, minAge: ${tagg?.slug ?? "0"}");
          }
          fastKeyDBHelper.addFastKeyItem( // Build #1.0.19: Updated parameters
            fastKeyId,
            product.name,
            product.image,
            product.price, // Now stored as string
            product.productId,
            minAge: int.parse(tagg?.slug ?? "0"),
            slNumber: product.slNumber,
            hasVariant: product.hasVariant, // Build #1.0.157: save hasVariant into DB
          );
        }
      } else {
        ///else just update the data for each fast key
        ///Build #1.0.112 : Fixed -> Duplicating fast key tab items
        // Avoid relying on index-based updates (i++).
        // Using productId & fastKey server id to match API response products with database records, ensuring updates are applied to the correct items.
       // var i=0;
        for(var product in response.products){
          var tagg = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => Tags());
          var hasAgeRestriction = tagg?.name?.contains(TextConstants.age_restricted);
          if (kDebugMode) {
            print("FastkeyBloc: fetchProductsByFastKeyId product already present and updating, hasAgeRestriction $hasAgeRestriction, minAge: ${tagg?.slug ?? "0"}");
          }
          final updatedTab = { ///Naveen : please update the db with product id and category, sl_number
            AppDBConst.fastKeyItemName: product.name,
            AppDBConst.fastKeyItemPrice: product.price,
            AppDBConst.fastKeySlNumber: product.slNumber,
            AppDBConst.fastKeyItemImage: product.image,
            AppDBConst.fastKeyProductId: product.productId,  // Build #1.0.19: Updated parameters
            AppDBConst.fastKeyItemMinAge: int.parse(tagg?.slug ?? "0"),
            AppDBConst.fastKeyItemHasVariant: product.hasVariant ?? false ? 1 : 0, // Build #1.0.157: save hasVariant into DB
          };
          await fastKeyDBHelper.updateFastKeyProductItemByProductId(
            fastKeyId,
            product.productId,
            updatedTab,
          );
        }
      }

      getProductsSink.add(APIResponse.completed(response));
    } catch (e,s) {
      if (e.toString().contains('Unauthorised')) {
        getProductsSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        getProductsSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        getProductsSink.add(APIResponse.error("Failed to fetch products in fast key."));
      }
      if (kDebugMode) print("Exception in fetchProductsByFastKeyId: $e , Stack: $s");
=======
        print(
            "#### fastKeyDBHelper.getFastKeyItems($fastKeyId) : $fastKeyItems ");
      }
      // Every successful response, including an empty product list, is authoritative.
      await fastKeyDBHelper.deleteAllFastKeyProductItems(fastKeyId);
      for (final product in response.products) {
        final ageTag = product.tags?.firstWhere(
          (tag) => tag.name == TextConstants.age_restricted,
          orElse: () => Tags(),
        );
        await fastKeyDBHelper.addFastKeyItem(
          fastKeyId,
          product.name,
          product.image,
          product.price,
          product.productId,
          minAge: int.tryParse(ageTag?.slug ?? "0") ?? 0,
          slNumber: product.slNumber,
          hasVariant: product.hasVariant,
          tagsJson:
              jsonEncode(product.tags?.map((tag) => tag.toJson()).toList() ?? []),
          metaDataJson: jsonEncode(product.metaData ?? []),
        );
      }
      await fastKeyDBHelper.updateFastKeyTabCount(
        fastKeyServerId,
        response.products.length,
      );

      getProductsSink.add(APIResponse.completed(response));
    } catch (e, s) {
      if (e.toString().contains('Unauthorised')) {
        getProductsSink
            .add(APIResponse.error("Unauthorised. Session is expired."));
      } else if (e.toString().contains('SocketException')) {
        getProductsSink.add(
            APIResponse.error("Network error. Please check your connection."));
      } else {
        getProductsSink.add(
            APIResponse.error("Failed to fetch products in FastKey: $e"));
      }
      if (kDebugMode)
        print("Exception in fetchProductsByFastKeyId: $e , Stack: $s");
>>>>>>> origin/Grocery_pch_api_integration
    }
  }

  // Build #1.0.89: Added deleteProduct API method
<<<<<<< HEAD
  Future<void> deleteProduct(int fastKeyId, int productId) async {
=======
  Future<void> deleteProduct(dynamic fastKeyId, dynamic productId) async {
>>>>>>> origin/Grocery_pch_api_integration
    if (_deleteProductController.isClosed) return;

    deleteProductSink.add(APIResponse.loading(TextConstants.loading));
    try {
<<<<<<< HEAD
      final response = await _repository.deleteProductFromFastKey(fastKeyId, productId);

      if (kDebugMode) {
        print("FastKeyProductBloc - Deleted product from FastKey: ${response.fastkeyId}, Product: $productId");
=======
      final response =
      await _repository.deleteProductFromFastKey(fastKeyId, productId);

      if (kDebugMode) {
        print(
            "FastKeyProductBloc - Deleted product from FastKey: ${response.fastkeyId}, Product: $productId");
>>>>>>> origin/Grocery_pch_api_integration
      }

      // Update DB after successful API response
      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      await fastKeyDBHelper.deleteFastKeyItemByProductId(fastKeyId, productId);

      final updatedItems = await fastKeyDBHelper.getFastKeyItems(fastKeyId);
<<<<<<< HEAD
      await fastKeyDBHelper.updateFastKeyTabCount(fastKeyId, updatedItems.length);

      if (kDebugMode) {
        print("### FastKeyProductBloc: Deleted item from DB and updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
=======
      await fastKeyDBHelper.updateFastKeyTabCount(
          fastKeyId, updatedItems.length);

      if (kDebugMode) {
        print(
            "### FastKeyProductBloc: Deleted item from DB and updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
>>>>>>> origin/Grocery_pch_api_integration
      }

      deleteProductSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
<<<<<<< HEAD
        deleteProductSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        deleteProductSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        deleteProductSink.add(APIResponse.error("Failed to delete product: ${e.toString()}"));
=======
        deleteProductSink
            .add(APIResponse.error("Unauthorised. Session is expired."));
      } else if (e.toString().contains('SocketException')) {
        deleteProductSink.add(
            APIResponse.error("Network error. Please check your connection."));
      } else {
        deleteProductSink.add(
            APIResponse.error("Failed to delete product: ${e.toString()}"));
>>>>>>> origin/Grocery_pch_api_integration
      }
      if (kDebugMode) print("Exception in deleteProduct: $e");
    }
  }

  // Dispose all controllers
  void dispose() {
    if (!_addProductsController.isClosed) {
      _addProductsController.close();
    }
    if (!_getProductsController.isClosed) {
      _getProductsController.close();
    }
<<<<<<< HEAD
    if (!_deleteProductController.isClosed) { // Build #1.0.89
=======
    if (!_deleteProductController.isClosed) {
      // Build #1.0.89
>>>>>>> origin/Grocery_pch_api_integration
      _deleteProductController.close();
    }
    if (kDebugMode) print("FastKeyProductBloc disposed");
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/Grocery_pch_api_integration
