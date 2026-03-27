// import 'package:kioski2/features/category/data/datasources/category_remote_data_source.dart';
// import 'package:kioski2/features/category/data/models/category_model.dart';

import '../model/category_model.dart';
import 'category_repository.dart';

class CategoryRepository {
  final CategoryRemoteDataSource _remoteDataSource;

  CategoryRepository({CategoryRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CategoryRemoteDataSource();

  Future<List<CategoryModel>> getCategories() {
    return _remoteDataSource.fetchCategories();
  }

  Future<List<CategoryModel>> getSubcategories(int parentId) {
    return _remoteDataSource.fetchSubcategories(parentId);
  }
}