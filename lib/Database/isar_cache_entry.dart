import 'package:isar_community/isar.dart';
part 'isar_cache_entry.g.dart';

@collection
class IsarCacheEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String json;

  late DateTime timestamp;
}

