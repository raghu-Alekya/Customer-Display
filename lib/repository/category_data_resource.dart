// import 'package:kioski2/features/category/data/datasources/category_remote_data_source.dart';
// import 'package:kioski2/features/category/data/models/category_model.dart';

import '../model/category_model.dart';
import 'category_repository.dart';

import '../model/category_model.dart';
import 'category_repository.dart';

class CategoryRepository {
  final CategoryRemoteDataSource _remoteDataSource;

  CategoryRepository({CategoryRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CategoryRemoteDataSource();

  // Category Cache
  List<CategoryModel>? _cachedCategories;

  // Subcategory Cache
  final Map<int, List<CategoryModel>> _subCategoryCache = {};

  Future<List<CategoryModel>> getCategories() async {
    if (_cachedCategories != null) {
      print("✅ Categories loaded from cache");
      return _cachedCategories!;
    }

    print("🌐 Categories loaded from API");

    final categories = await _remoteDataSource.fetchCategories();

    _cachedCategories = categories;

    return categories;
  }

  Future<List<CategoryModel>> getSubcategories(int parentId) async {
    // Return cache if available
    if (_subCategoryCache.containsKey(parentId)) {
      print("✅ Subcategories loaded from cache: $parentId");
      return _subCategoryCache[parentId]!;
    }

    print("🌐 Subcategories loaded from API: $parentId");

    final result =
    await _remoteDataSource.fetchSubcategories(parentId);

    // Store in cache
    _subCategoryCache[parentId] = result;

    return result;
  }

  void clearCache() {
    _cachedCategories = null;
    _subCategoryCache.clear();
  }
}