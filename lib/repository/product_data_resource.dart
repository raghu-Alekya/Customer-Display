import 'package:keyos_app/repository/product_repository.dart';

import '../model/product model.dart';
// import 'package:kioski2/features/product/data/datasources/product_remote_data_source.dart';
// import 'package:kioski2/features/product/data/models/product_model.dart';

class ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;

  ProductRepository({ProductRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ProductRemoteDataSource();

  Future<List<ProductModel>> getProductsByCategory(int categoryId) {
    return _remoteDataSource.fetchProductsByCategory(categoryId);
  }

  Future<List<ProductModel>> searchProducts(String query) {
    return _remoteDataSource.searchProducts(query);
  }
}