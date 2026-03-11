// blocs/category_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../../Repositories/Category/category_repository.dart';

class CategoryBloc { // Build #1.0.21 - Added category screen bloc - naveen
  final CategoryRepository _categoryRepository;


  // Stream Controllers for Categories
  final StreamController<APIResponse<CategoryListResponse>> _categoriesController =
  StreamController<APIResponse<CategoryListResponse>>.broadcast();

  // Stream Controllers for Products
  final StreamController<APIResponse<CategoryProductListResponse>> _productsController =
  StreamController<APIResponse<CategoryProductListResponse>>.broadcast();

  // Getters for Streams
  StreamSink<APIResponse<CategoryListResponse>> get categoriesSink => _categoriesController.sink;
  Stream<APIResponse<CategoryListResponse>> get categoriesStream => _categoriesController.stream;

  StreamSink<APIResponse<CategoryProductListResponse>> get productsSink => _productsController.sink;
  Stream<APIResponse<CategoryProductListResponse>> get productsStream => _productsController.stream;

  CategoryBloc(this._categoryRepository) {
    if (kDebugMode) {
      print("CategoryBloc Initialized");
    }
  }

  // Fetch categories by parent ID (0 for top-level categories)
  Future<void> fetchCategories(int parentId) async {
    if (_categoriesController.isClosed) return;
    if (kDebugMode) {
      print("CategoryBloc - Fetching sub categories with parentId: $parentId");
    }
    categoriesSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _categoryRepository.getCategories(parent: parentId);

      if (kDebugMode) {
        print("CategoryBloc - Fetched ${response.categories.length} categories");
      }

      categoriesSink.add(APIResponse.completed(response));
    } catch (e) {
      //Build #1.0.179
      if (e.toString().contains('UnauthorisedException')) {
        categoriesSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      if (e.toString().contains('SocketException')) {
        categoriesSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        categoriesSink.add(APIResponse.error("Failed to fetch categories: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in fetchCategories: $e");
    }
  }

  // Fetch products by category ID
  Future<void> fetchProductsByCategory(int categoryId) async {
    if (_productsController.isClosed) return;

    if (kDebugMode) {
      print("CategoryBloc - Fetching product with categoryId: $categoryId");
    }
    productsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _categoryRepository.getProductsByCategory(categoryId);

      if (kDebugMode) {
        print("CategoryBloc - Fetched ${response.products.length} products");
      }

      productsSink.add(APIResponse.completed(response));
    } catch (e,s) {
      if (e.toString().contains('SocketException')) {
        productsSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        productsSink.add(APIResponse.error("Failed to fetch products."));
      }
      if (kDebugMode) print("Exception in fetchProductsByCategory: $e Stack: $s");
    }
  }

  void dispose() {
    if (!_categoriesController.isClosed) {
      _categoriesController.close();
    }
    if (!_productsController.isClosed) {
      _productsController.close();
    }
    if (kDebugMode) print("CategoryBloc disposed");
  }
}