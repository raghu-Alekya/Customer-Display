import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Repositories/FastKey/fastkey_product_repository.dart';
import '../../Database/fast_key_db_helper.dart';
import '../../Database/db_helper.dart';

String _encodeFastKeyTagsJsonProductBloc(List<Tags>? tags) {
  if (tags == null || tags.isEmpty) return '[]';
  return jsonEncode(tags.map((t) => t.toJson()).toList());
}

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

  FastKeyProductBloc(this._repository) {
    if (kDebugMode) {
      print("FastKeyProductBloc Initialized");
    }
  }

  // POST: Add products to FastKey
  Future<void> addProducts({required int fastKeyId, required List<FastKeyProductItem> products}) async {
    if (_addProductsController.isClosed) return;

    addProductsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final request = FastKeyProductRequest(
        fastKeyId: fastKeyId,
        products: products,
      );

      final response = await _repository.addProductsToFastKey(request);

      if (kDebugMode) {
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
          }
          // Check for existing item with the same productId
          final db = await DBHelper.instance.database;
          final isDuplicate = await db.query(
            AppDBConst.fastKeyItemsTable,
            where: '${AppDBConst.fastKeyIdForeignKey} = ? AND ${AppDBConst.fastKeyProductId} = ?',
            whereArgs: [serverTabId, product.productId],
          );
          final int minAge = int.tryParse(tagg?.slug ?? '') ?? 0;
          if (isDuplicate.isEmpty) {
            await fastKeyDBHelper.addFastKeyItem(
              serverTabId,
              product.name,
              product.image,
              product.price,
              product.productId,
              slNumber: product.slNumber,
              minAge: minAge,//updated in build #1.0.90
              sku: product.sku,
              tagsJson: _encodeFastKeyTagsJsonProductBloc(product.tags),
            );
            if (kDebugMode) {
              print("### FastKeyProductBloc: Added item ${product.name} to DB for tab ID: $serverTabId");
            }
          } else {
            if (kDebugMode) {
              print("### FastKeyProductBloc: Skipped duplicate item ${product.name} with product_id ${product.productId}");
            }
          }
        }

        final updatedItems = await fastKeyDBHelper.getFastKeyItems(serverTabId);
        await fastKeyDBHelper.updateFastKeyTabCount(fastKeyId, updatedItems.length);
        if (kDebugMode) {
          print("### FastKeyProductBloc: Updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
        }
      }
      addProductsSink.add(APIResponse.completed(response));
    } catch (e, s) {
      if (e.toString().contains('Unauthorised')) {
        addProductsSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        addProductsSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        addProductsSink.add(APIResponse.error("Failed to add products: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in addProducts: $e, Stack: $s");
    }
  }

  // GET: Fetch products by FastKey ID
  Future<void> fetchProductsByFastKeyId(int fastKeyId, int fastKeyServerId) async {
    if (_getProductsController.isClosed) return;

    getProductsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _repository.getProductsByFastKeyId(fastKeyServerId);

      if (kDebugMode) {
        print("FastKeyProductBloc - Fetched ${response.products.length} products for FastKey $fastKeyId, FastKeyServer $fastKeyServerId");
      }

      ///insert into DB

      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final fastKeyItems = await fastKeyDBHelper.getFastKeyItems(fastKeyId);
      if (kDebugMode) {
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
          final int minAge = int.tryParse(tagg?.slug ?? '') ?? 0;
          fastKeyDBHelper.addFastKeyItem( // Build #1.0.19: Updated parameters
            fastKeyId,
            product.name,
            product.image,
            product.price, // Now stored as string
            product.productId,
            minAge: minAge,
            slNumber: product.slNumber,
            hasVariant: product.hasVariant, // Build #1.0.157: save hasVariant into DB
            sku: product.sku,
            tagsJson: _encodeFastKeyTagsJsonProductBloc(product.tags),
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
          final int minAge = int.tryParse(tagg?.slug ?? '') ?? 0;
          final updatedTab = { ///Naveen : please update the db with product id and category, sl_number
            AppDBConst.fastKeyItemName: product.name,
            AppDBConst.fastKeyItemPrice: product.price,
            AppDBConst.fastKeySlNumber: product.slNumber,
            AppDBConst.fastKeyItemImage: product.image,
            AppDBConst.fastKeyProductId: product.productId,  // Build #1.0.19: Updated parameters
            AppDBConst.fastKeyItemMinAge: minAge,
            AppDBConst.fastKeyItemHasVariant: product.hasVariant ?? false ? 1 : 0, // Build #1.0.157: save hasVariant into DB
            AppDBConst.fastKeyItemTags:
            _encodeFastKeyTagsJsonProductBloc(product.tags),
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
    }
  }

  // Build #1.0.89: Added deleteProduct API method
  Future<void> deleteProduct(int fastKeyId, int productId) async {
    if (_deleteProductController.isClosed) return;

    deleteProductSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _repository.deleteProductFromFastKey(fastKeyId, productId);

      if (kDebugMode) {
        print("FastKeyProductBloc - Deleted product from FastKey: ${response.fastkeyId}, Product: $productId");
      }

      // Update DB after successful API response
      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      await fastKeyDBHelper.deleteFastKeyItemByProductId(fastKeyId, productId);

      final updatedItems = await fastKeyDBHelper.getFastKeyItems(fastKeyId);
      await fastKeyDBHelper.updateFastKeyTabCount(fastKeyId, updatedItems.length);

      if (kDebugMode) {
        print("### FastKeyProductBloc: Deleted item from DB and updated tab count to ${updatedItems.length} for server ID: $fastKeyId");
      }

      deleteProductSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        deleteProductSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        deleteProductSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        deleteProductSink.add(APIResponse.error("Failed to delete product: ${e.toString()}"));
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
    if (!_deleteProductController.isClosed) { // Build #1.0.89
      _deleteProductController.close();
    }
    if (kDebugMode) print("FastKeyProductBloc disposed");
  }
}