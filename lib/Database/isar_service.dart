import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_cache_entry.dart';

class IsarService {
  IsarService._();

  static Isar? _isar;

  static Future<Isar> get instance async {
    final existing = _isar;
    if (existing != null) return existing;
    return await init();
  }

  static Future<Isar> init() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [IsarCacheEntrySchema],
      directory: dir.path,
      name: 'pinaka_pos',
    );
    return _isar!;
  }
}

