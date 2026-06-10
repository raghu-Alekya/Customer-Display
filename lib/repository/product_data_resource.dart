import 'package:kiosk/repository/product_repository.dart';
// import 'package:kiosk_app/repository/product_repository.dart';

import '../model/product model.dart';

class ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;

  ProductRepository({ProductRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ProductRemoteDataSource();

  // Product Cache
  final Map<int, List<ProductModel>> _productCache = {};

  Future<List<ProductModel>> getProductsByCategory(int categoryId) async {

    // Return cached data
    if (_productCache.containsKey(categoryId)) {
      print("✅ Products loaded from cache: $categoryId");
      return _productCache[categoryId]!;
    }

    print("🌐 Products loaded from API: $categoryId");

    final products =
    await _remoteDataSource.fetchProductsByCategory(categoryId);

    // Save in cache
    _productCache[categoryId] = products;

    return products;
  }

  Future<List<ProductModel>> searchProducts(String query) {
    return _remoteDataSource.searchProducts(query);
  }

  void clearCache() {
    _productCache.clear();
  }
}