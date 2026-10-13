import 'package:pinaka_pos/Database/storage/isar_box_storage.dart';

/// Central provider for all storage (replaces Hive boxes with Isar-backed storage).
/// All boxes use IsarCacheEntry with prefixed keys.
class StorageProvider {
  StorageProvider._();

  static final offlineOrders = IsarBoxStorage('offlineOrders');
  static final deletedOrders = IsarBoxStorage('deletedOrders');
  static final productCache = IsarBoxStorage('productCache');
  static final orderExtras = IsarBoxStorage('orderExtras');
  static final cashbackConfig = IsarBoxStorage('cashbackConfig');
  static final user = IsarBoxStorage('user');
  static final categoryCache = IsarBoxStorage('categoryCache');
  static final fastKeysBox = IsarBoxStorage('fastKeysBox');
}
