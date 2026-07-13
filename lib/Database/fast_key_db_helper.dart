import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Widgets/widget_topbar.dart';
import 'db_helper.dart';
import '../Helper/url_helper.dart';
import 'isar_service.dart';

class FastKeyDBHelper { // Build #1.0.11 : FastKeyHelper for all fast key related methods
  static final FastKeyDBHelper _instance = FastKeyDBHelper._internal();
  factory FastKeyDBHelper() => _instance;
  static bool isFastkeyLoaded = false;

  FastKeyDBHelper._internal() {
    if (kDebugMode) {
      print("#### FastKeyDBHelper initialized!");
    }
  }

  Future<int> addFastKeyTab(int userId, String title, String image, int count, int? index, int? fastKeyServerId) async {
    final db = await DBHelper.instance.database;
    final tabId = await db.insert(AppDBConst.fastKeyTable, {
      AppDBConst.userIdForeignKey: userId,
      AppDBConst.fastKeyServerId: fastKeyServerId, /// use this fast key to call get fast key product by fast key id
      AppDBConst.fastKeyTabTitle: title,
      AppDBConst.fastKeyTabImage: image,
      AppDBConst.fastKeyTabItemCount: count,
      AppDBConst.fastKeyTabIndex: index ?? 'N/A', // Build #1.0.12: new row added
    });

    if (kDebugMode) {
      print("#### FastKey Tab added with ID: $tabId");
    }
    return tabId;
  }

  Future<List<Map<String, dynamic>>> getFastKeyTabsByUserId(int userId) async {
    final db = await DBHelper.instance.database;
    final tabs = await db.query(
      AppDBConst.fastKeyTable,
      where: '${AppDBConst.userIdForeignKey} = ?',
      whereArgs: [userId],
    );

    if (kDebugMode) {
      print("#### Retrieved ${tabs.length} FastKey Tabs for User ID: $userId");
    }
    return tabs;
  }

  Future<List<Map<String, dynamic>>> getFastKeyTabsByTabId(int tabId) async {///tab id is fastkey id from our db not to confused with fast key server id
    final db = await DBHelper.instance.database;
    final tabs = await db.query(
      AppDBConst.fastKeyTable,
      where: '${AppDBConst.fastKeyId} = ?',
      whereArgs: [tabId],
    );

    if (kDebugMode) {
      print("#### Retrieved ${tabs.length} FastKey Tabs for User ID: $tabId");
    }
    return tabs;
  }

  // Build #1.0.87
  Future<List<Map<String, dynamic>>> getFastKeyByServerTabId(int serverTabId) async {///tab id is fastServerId from server
    final db = await DBHelper.instance.database;
    final tabs = await db.query(
      AppDBConst.fastKeyTable,
      where: '${AppDBConst.fastKeyServerId} = ?',
      whereArgs: [serverTabId],
    );

    if (kDebugMode) {
      print("#### Retrieved ${tabs.length} FastKey Tabs for User ID: $serverTabId");
    }
    return tabs;
  }

  Future<void> updateFastKeyTab(int fastKeyServerId, Map<String, dynamic> updatedData) async { // Build #1.0.89: name changed for understanding
    final db = await DBHelper.instance.database;
    await db.update(
      AppDBConst.fastKeyTable,
      updatedData,
      where: '${AppDBConst.fastKeyServerId} = ?',
      whereArgs: [fastKeyServerId],
    );

    if (kDebugMode) {
      print("#### updateFastKeyTab -> fastKeyServerId: $fastKeyServerId");
    }
  }

  Future<void> updateFastKeyTabOrder(int tabId, Map<String, dynamic> updatedData) async {
    final db = await DBHelper.instance.database;
    await db.update(
      AppDBConst.fastKeyTable,
      {
        ...updatedData,
        AppDBConst.fastKeyTabSynced: 0, // // Build #1.0.19: Updated Mark as unsynced
      },
      where: '${AppDBConst.fastKeyId} = ?',
      whereArgs: [tabId],
    );

    if (kDebugMode) {
      print("#### FastKey Tab updated with ID: $tabId");
    }
  }

  Future<void> updateFastKeyTabCount(int tabId, int newCount) async {
    final db = await DBHelper.instance.database;
    await db.update(
      AppDBConst.fastKeyTable,
      {AppDBConst.fastKeyTabItemCount: newCount},
      where: '${AppDBConst.fastKeyServerId} = ?',
      whereArgs: [tabId],
    );

    if (kDebugMode) {
      print("#### FastKey Tab count updated to $newCount for ID: $tabId");
    }
  }

  Future<void> deleteFastKeyTab(int tabId) async {
    final db = await DBHelper.instance.database;
    //Build #1.0.279: Fixed Issue - Delete all products of the deleted fastKey first then delete fastKey tab!
    await deleteAllFastKeyProductItems(tabId);

    await db.delete(
      AppDBConst.fastKeyTable,
      where: '${AppDBConst.fastKeyServerId} = ?',
      whereArgs: [tabId],
    );

    if (kDebugMode) {
      print("#### FastKey Tab deleted with ID: $tabId");
    }
  }

  Future<void> deleteAllFastKeyTab(int userId) async {
    final db = await DBHelper.instance.database;
    await db.delete(
        AppDBConst.fastKeyTable,
        where: '${AppDBConst.userIdForeignKey} = ?',
        whereArgs: [userId]
    );

    if (kDebugMode) {
      print("#### FastKey all Tabs deleted for current user");
    }
  }

  Future<int> addFastKeyItem(int tabId, String name, String image,  String price, int productId,
      {String? sku, String? variantId, int? slNumber, int? minAge, bool? hasVariant, String? tagsJson, String? metaDataJson, int? loyaltyPoints}) async {
    final db = await DBHelper.instance.database;
    final itemId = await db.insert(AppDBConst.fastKeyItemsTable, {
      AppDBConst.fastKeyIdForeignKey: tabId,
      AppDBConst.fastKeyItemName: name,
      AppDBConst.fastKeyItemImage: image,
      AppDBConst.fastKeyItemPrice: price,
      AppDBConst.fastKeyItemSKU: sku ?? 'N/A',
      AppDBConst.fastKeyItemVariantId: variantId ?? 'N/A',
      AppDBConst.fastKeyProductId: productId, // Build #1.0.19: Updated req elements
      AppDBConst.fastKeySlNumber: slNumber,
      AppDBConst.fastKeyItemMinAge: minAge, // Build #1.0.19: Updated req elements
      AppDBConst.fastKeyItemHasVariant: hasVariant ?? false ? 1 : 0, // Build #1.0.157: save hasVariant into DB
      AppDBConst.fastKeyItemTags: tagsJson ?? '[]',
      // ✅ NEW: Store meta_data and loyalty_points
      'meta_data': metaDataJson ?? '[]',
      'loyalty_points': loyaltyPoints ?? 0,
    },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Build #1.0.80: Ignore duplicates
    );

    if (kDebugMode) {
      print("#### FastKey Item added with ID: $itemId");
    }
    return itemId;
  }

  Future<List<Map<String, dynamic>>> getFastKeyItems(int tabId) async {
    final db = await DBHelper.instance.database;
    final items = await db.query(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = ?',
      whereArgs: [tabId],
    );

    // ✅ FIX: Create a new list with mutable maps
    final List<Map<String, dynamic>> result = [];

    for (final item in items) {
      // Create a mutable copy of the item
      final mutableItem = Map<String, dynamic>.from(item);

      // Parse meta_data
      final metaDataStr = mutableItem['meta_data'] as String?;
      if (metaDataStr != null && metaDataStr.isNotEmpty && metaDataStr != '[]') {
        try {
          mutableItem['meta_data'] = jsonDecode(metaDataStr);
        } catch (_) {
          mutableItem['meta_data'] = [];
        }
      } else {
        mutableItem['meta_data'] = [];
      }

      // Parse tags
      final tagsStr = mutableItem[AppDBConst.fastKeyItemTags] as String?;
      if (tagsStr != null && tagsStr.isNotEmpty && tagsStr != '[]') {
        try {
          mutableItem[AppDBConst.fastKeyItemTags] = jsonDecode(tagsStr);
        } catch (_) {
          mutableItem[AppDBConst.fastKeyItemTags] = [];
        }
      } else {
        mutableItem[AppDBConst.fastKeyItemTags] = [];
      }

      // Ensure loyalty_points is accessible
      if (mutableItem['loyalty_points'] == null) {
        mutableItem['loyalty_points'] = 0;
      }

      result.add(mutableItem);
    }

    if (kDebugMode) {
      print("#### Retrieved ${result.length} FastKey Items for Tab ID: $tabId");
    }
    return result;
  }

  /// Get FastKey items with tags parsed from JSON
  /// Get FastKey items with tags parsed from JSON
  Future<List<Map<String, dynamic>>> getFastKeyItemsWithTags(int tabId) async {
    final db = await DBHelper.instance.database;
    final items = await db.query(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = ?',
      whereArgs: [tabId],
      orderBy: '${AppDBConst.fastKeySlNumber} ASC',
    );

    // ✅ FIX: Create a new list with mutable maps
    final List<Map<String, dynamic>> result = [];

    for (final item in items) {
      final mutableItem = Map<String, dynamic>.from(item);

      // Parse tags
      final tagsStr = mutableItem[AppDBConst.fastKeyItemTags] as String?;
      if (tagsStr != null && tagsStr.isNotEmpty && tagsStr != '[]') {
        try {
          mutableItem[AppDBConst.fastKeyItemTags] = jsonDecode(tagsStr);
        } catch (_) {
          mutableItem[AppDBConst.fastKeyItemTags] = [];
        }
      } else {
        mutableItem[AppDBConst.fastKeyItemTags] = [];
      }

      // Parse meta_data
      final metaDataStr = mutableItem['meta_data'] as String?;
      if (metaDataStr != null && metaDataStr.isNotEmpty && metaDataStr != '[]') {
        try {
          mutableItem['meta_data'] = jsonDecode(metaDataStr);
        } catch (_) {
          mutableItem['meta_data'] = [];
        }
      } else {
        mutableItem['meta_data'] = [];
      }

      // Ensure loyalty_points is accessible
      if (mutableItem['loyalty_points'] == null) {
        mutableItem['loyalty_points'] = 0;
      }

      result.add(mutableItem);
    }

    if (kDebugMode) {
      print("#### Retrieved ${result.length} FastKey Items with tags for Tab ID: $tabId");
    }
    return result;
  }

  Future<void> updateFastKeyProductItem(
      int itemId, Map<String, dynamic> updatedData) async {
    final db = await DBHelper.instance.database;

    await db.update(
      AppDBConst.fastKeyItemsTable,
      updatedData,
      where: '${AppDBConst.fastKeyItemId} = ?',
      whereArgs: [itemId],
    );

    if (kDebugMode) {
      print("#### FastKey Item updated with ID: $itemId");
    }
  }

  ///Build #1.0.112 : Fixed -> Duplicating fast key tab items
  // Using productId & fastKey server id to match API response products with database records, ensuring updates are applied to the correct items.
  // previously we are using above func updateFastKeyProductItem & using fastKeyItemId that is the issue!
  Future<void> updateFastKeyProductItemByProductId(
      int fastKeyId, int productId, Map<String, dynamic> updatedData) async {
    final db = await DBHelper.instance.database;

    if (kDebugMode) {
      print("FastkeyDBHelper: updateFastKeyProductItemByProductId $updatedData");
    }
    final result = await db.update(
      AppDBConst.fastKeyItemsTable,
      updatedData,
      where: '${AppDBConst.fastKeyIdForeignKey} = ? AND ${AppDBConst.fastKeyProductId} = ?',
      whereArgs: [fastKeyId, productId],
    );

    if (kDebugMode) {
      if (result > 0) {
        print("#### FastKey Item updated for fastKeyId: $fastKeyId, productId: $productId");
      } else {
        print("#### FastKey Item not found for fastKeyId: $fastKeyId, productId: $productId");
      }
    }
  }

  Future<void> deleteAllFastKeyProductItems(int tabId) async {
    final db = await DBHelper.instance.database;

    await db.delete(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = ?',
      whereArgs: [tabId],
    );

    if (kDebugMode) {
      print("#### All FastKey Items deleted for Tab ID: $tabId");
    }
  }

  // Build #1.0.89: Added
  Future<void> deleteFastKeyItemByProductId(int fastKeyId, int productId) async {
    final db = await DBHelper.instance.database;
    await db.delete(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = ? AND ${AppDBConst.fastKeyProductId} = ?',
      whereArgs: [fastKeyId, productId],
    );
    if (kDebugMode) {
      print("### FastKeyDBHelper: Deleted item with product ID $productId from fast key ID $fastKeyId");
    }
  }

  Future<void> deleteFastKeyItem(int itemId) async {
    final db = await DBHelper.instance.database;
    await db.delete(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyItemId} = ?',
      whereArgs: [itemId],
    );

    if (kDebugMode) {
      print("#### FastKey Item deleted with ID: $itemId");
    }
  }

  //Build #1.0.68 : Added
  Future<void> updateFastKeyItemOrder(int fastKeyTabId, List<Map<String, dynamic>> items) async {
    final db = await DBHelper.instance.database;
    for (int i = 0; i < items.length; i++) {
      await db.update(
        AppDBConst.fastKeyItemsTable,
        {AppDBConst.fastKeySlNumber: i + 1},
        where: '${AppDBConst.fastKeyItemId} = ?',
        whereArgs: [items[i][AppDBConst.fastKeyItemId]],
      );
    }
  }

  // ============================================================
  // NEW METHODS FOR SYNCING FASTKEYS FROM API
  // ============================================================

  /// Sync FastKey tabs and items from API and update SQLite
  Future<void> syncFastKeysFromApi(String token, int userId) async {
    try {
      if (kDebugMode) print("🔄 Syncing FastKey items from API...");

      // 1. Get all FastKey tabs for the user
      final tabsUrl = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}'
            'fast-keys?user_id=$userId',
      );

      final tabsResponse = await http.get(
        tabsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (tabsResponse.statusCode != 200) {
        if (kDebugMode) print('⚠️ FastKey tabs fetch failed: ${tabsResponse.statusCode}');
        return;
      }

      final tabsData = jsonDecode(tabsResponse.body);
      final List<dynamic> fastKeys = tabsData['fast_keys'] ?? [];

      if (fastKeys.isEmpty) {
        if (kDebugMode) print('ℹ️ No FastKey tabs found');
        return;
      }

      // 2. For each FastKey tab, fetch and update items
      for (final fastKey in fastKeys) {
        final int fastKeyServerId = fastKey['id'];
        await _syncFastKeyItems(token, fastKeyServerId);
      }

      if (kDebugMode) print("✅ FastKey sync completed");

    } catch (e) {
      if (kDebugMode) print('❌ FastKey sync error: $e');
    }
  }

  /// Sync items for a specific FastKey tab
  Future<void> _syncFastKeyItems(String token, int fastKeyServerId) async {
    try {
      final db = await DBHelper.instance.database;

      // Get local tab ID
      final tabResult = await db.query(
        AppDBConst.fastKeyTable,
        where: '${AppDBConst.fastKeyServerId} = ?',
        whereArgs: [fastKeyServerId],
      );

      if (tabResult.isEmpty) {
        if (kDebugMode) print('⚠️ FastKey tab not found: $fastKeyServerId');
        return;
      }

      final int localTabId = tabResult.first[AppDBConst.fastKeyId] as int;

      // Fetch items from API
      final itemsUrl = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}'
            'fast-keys/$fastKeyServerId/items',
      );

      final itemsResponse = await http.get(
        itemsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (itemsResponse.statusCode != 200) {
        if (kDebugMode) {
          print('⚠️ Failed to fetch items for FastKey $fastKeyServerId: ${itemsResponse.statusCode}');
        }
        return;
      }

      final itemsData = jsonDecode(itemsResponse.body);
      final List<dynamic> items = itemsData['items'] ?? [];

      // Update items in SQLite
      await _updateFastKeyItemsInDb(localTabId, fastKeyServerId, items);

      if (kDebugMode) {
        print('✅ Updated ${items.length} items for FastKey $fastKeyServerId');
      }

    } catch (e) {
      if (kDebugMode) print('❌ Error syncing FastKey items: $e');
    }
  }

  /// Update FastKey items in SQLite - ✅ FIXED to store meta_data and loyalty_points
  // Future<void> _updateFastKeyItemsInDb(int localTabId, int fastKeyServerId, List<dynamic> items) async {
  //   final db = await DBHelper.instance.database;
  //
  //   // Delete existing items for this FastKey tab
  //   await db.delete(
  //     AppDBConst.fastKeyItemsTable,
  //     where: '${AppDBConst.fastKeyIdForeignKey} = ?',
  //     whereArgs: [localTabId],
  //   );
  //
  //   // Insert new items
  //   final now = DateTime.now().toIso8601String();
  //
  //   for (int i = 0; i < items.length; i++) {
  //     final item = items[i];
  //
  //     // Parse tags
  //     String tagsJson = '[]';
  //     if (item['tags'] != null) {
  //       try {
  //         tagsJson = jsonEncode(item['tags']);
  //       } catch (_) {
  //         tagsJson = '[]';
  //       }
  //     }
  //
  //     // ✅ NEW: Extract meta_data from API response
  //     String metaDataJson = '[]';
  //     int loyaltyPoints = 0;
  //
  //     if (item['meta_data'] != null) {
  //       try {
  //         metaDataJson = jsonEncode(item['meta_data']);
  //
  //         // Extract loyalty points from meta_data
  //         if (item['meta_data'] is List) {
  //           final metaData = item['meta_data'] as List;
  //           for (final meta in metaData) {
  //             if (meta is Map && meta['key'] == '_product_loyalty_points') {
  //               loyaltyPoints = int.tryParse(meta['value']?.toString() ?? '0') ?? 0;
  //               break;
  //             }
  //           }
  //         }
  //       } catch (_) {
  //         metaDataJson = '[]';
  //       }
  //     }
  //
  //     // Also check if loyalty_points is directly on the product
  //     if (loyaltyPoints == 0 && item['loyalty_points'] != null) {
  //       loyaltyPoints = int.tryParse(item['loyalty_points'].toString()) ?? 0;
  //     }
  //
  //     // Determine if item has variants
  //     bool hasVariant = false;
  //     if (item['has_variant'] != null) {
  //       hasVariant = item['has_variant'] == true || item['has_variant'] == 1;
  //     }
  //     if (!hasVariant && item['has_variants'] != null) {
  //       hasVariant = item['has_variants'] == true || item['has_variants'] == 1;
  //     }
  //
  //     final Map<String, dynamic> values = {
  //       AppDBConst.fastKeyIdForeignKey: localTabId,
  //       AppDBConst.fastKeyProductId: item['product_id']?.toString() ?? '',
  //       AppDBConst.fastKeySlNumber: item['sl_number']?.toString() ?? (i + 1).toString(),
  //       AppDBConst.fastKeyItemName: item['name'] ?? 'Unknown',
  //       AppDBConst.fastKeyItemImage: item['image'] ?? '',
  //       AppDBConst.fastKeyItemPrice: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
  //       AppDBConst.fastKeyItemSKU: item['sku'] ?? '',
  //       AppDBConst.fastKeyItemMinAge: int.tryParse(item['min_age']?.toString() ?? '0') ?? 0,
  //       AppDBConst.fastKeyItemIsVariant: (item['is_variant'] ?? false) ? 1 : 0,
  //       AppDBConst.fastKeyItemHasVariant: hasVariant ? 1 : 0,
  //       AppDBConst.fastKeyItemVariantId: item['variant_id']?.toString() ?? '0',
  //       AppDBConst.fastKeyItemTags: tagsJson,
  //       // ✅ NEW: Store meta_data and loyalty_points
  //       'meta_data': metaDataJson,
  //       'loyalty_points': loyaltyPoints,
  //       'type': item['type'] ?? 'simple',
  //       AppDBConst.updatedAt: now,
  //     };
  //
  //     await db.insert(
  //       AppDBConst.fastKeyItemsTable,
  //       values,
  //       conflictAlgorithm: ConflictAlgorithm.replace,
  //     );
  //
  //     if (kDebugMode && loyaltyPoints > 0) {
  //       print("✅ [FastKey] Stored loyalty points: $loyaltyPoints for product: ${item['name']}");
  //     }
  //   }
  //
  //   // Update item count in FastKey tab
  //   await db.update(
  //     AppDBConst.fastKeyTable,
  //     {
  //       AppDBConst.fastKeyTabItemCount: items.length,
  //       AppDBConst.fastKeyTabSynced: 1,
  //       AppDBConst.updatedAt: now,
  //     },
  //     where: '${AppDBConst.fastKeyId} = ?',
  //     whereArgs: [localTabId],
  //   );
  // }

  /// Ensure all required columns exist in fast_key_items table
  Future<void> _ensureFastKeyColumns() async {
    try {
      final db = await DBHelper.instance.database;

      // Check existing columns
      final columns = await db.rawQuery(
          "PRAGMA table_info(${AppDBConst.fastKeyItemsTable})"
      );

      final columnNames = columns.map((col) => col['name'] as String).toList();

      if (kDebugMode) {
        print("📋 FastKey columns: $columnNames");
      }

      // Add meta_data column if missing
      if (!columnNames.contains('meta_data')) {
        if (kDebugMode) print("🔄 Adding meta_data column to fast_key_items...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN meta_data TEXT'
        );
        if (kDebugMode) print("✅ Added meta_data column");
      }

      // Add loyalty_points column if missing
      if (!columnNames.contains('loyalty_points')) {
        if (kDebugMode) print("🔄 Adding loyalty_points column to fast_key_items...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN loyalty_points INTEGER DEFAULT 0'
        );
        if (kDebugMode) print("✅ Added loyalty_points column");
      }

      // Add type column if missing
      if (!columnNames.contains('type')) {
        if (kDebugMode) print("🔄 Adding type column to fast_key_items...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN type TEXT DEFAULT "simple"'
        );
        if (kDebugMode) print("✅ Added type column");
      }

    } catch (e) {
      if (kDebugMode) print(" Failed to add columns: $e");
    }
  }

  /// Update FastKey items in SQLite - ✅ FIXED to store meta_data and loyalty_points
  Future<void> _updateFastKeyItemsInDb(int localTabId, int fastKeyServerId, List<dynamic> items) async {
    final db = await DBHelper.instance.database;

    // ✅ Ensure columns exist
    await _ensureFastKeyColumns();

    // Delete existing items for this FastKey tab
    await db.delete(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = ?',
      whereArgs: [localTabId],
    );

    // Insert new items
    final now = DateTime.now().toIso8601String();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // Parse tags
      String tagsJson = '[]';
      if (item['tags'] != null) {
        try {
          tagsJson = jsonEncode(item['tags']);
        } catch (_) {
          tagsJson = '[]';
        }
      }

      // ✅ FIX: Extract meta_data from API response
      String metaDataJson = '[]';
      int loyaltyPoints = 0;

      if (item['meta_data'] != null && item['meta_data'] is List) {
        try {
          // Store the entire meta_data as JSON
          metaDataJson = jsonEncode(item['meta_data']);

          // Extract loyalty points from meta_data
          final metaData = item['meta_data'] as List;
          for (final meta in metaData) {
            if (meta is Map) {
              final key = meta['key']?.toString() ?? '';
              if (key == '_product_loyalty_points') {
                final value = meta['value']?.toString() ?? '0';
                loyaltyPoints = int.tryParse(value) ?? 0;
                if (kDebugMode) {
                  print("✅ [FastKey] Found loyalty points: $loyaltyPoints for product: ${item['name']}");
                }
                break;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print("⚠️ Error extracting meta_data: $e");
          metaDataJson = '[]';
        }
      }

      // Also check if loyalty_points is directly on the product
      if (loyaltyPoints == 0 && item['loyalty_points'] != null) {
        loyaltyPoints = int.tryParse(item['loyalty_points'].toString()) ?? 0;
      }

      // Determine if item has variants
      bool hasVariant = false;
      if (item['has_variant'] != null) {
        hasVariant = item['has_variant'] == true || item['has_variant'] == 1;
      }
      if (!hasVariant && item['has_variants'] != null) {
        hasVariant = item['has_variants'] == true || item['has_variants'] == 1;
      }

      final Map<String, dynamic> values = {
        AppDBConst.fastKeyIdForeignKey: localTabId,
        AppDBConst.fastKeyProductId: item['product_id']?.toString() ?? '',
        AppDBConst.fastKeySlNumber: item['sl_number']?.toString() ?? (i + 1).toString(),
        AppDBConst.fastKeyItemName: item['name'] ?? 'Unknown',
        AppDBConst.fastKeyItemImage: item['image'] ?? '',
        AppDBConst.fastKeyItemPrice: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        AppDBConst.fastKeyItemSKU: item['sku'] ?? '',
        AppDBConst.fastKeyItemMinAge: int.tryParse(item['min_age']?.toString() ?? '0') ?? 0,
        AppDBConst.fastKeyItemIsVariant: (item['is_variant'] ?? false) ? 1 : 0,
        AppDBConst.fastKeyItemHasVariant: hasVariant ? 1 : 0,
        AppDBConst.fastKeyItemVariantId: item['variant_id']?.toString() ?? '0',
        AppDBConst.fastKeyItemTags: tagsJson,
        // ✅ Store meta_data and loyalty_points
        'meta_data': metaDataJson,
        'loyalty_points': loyaltyPoints,
        'type': item['type'] ?? 'simple',
        AppDBConst.updatedAt: now,
      };

      await db.insert(
        AppDBConst.fastKeyItemsTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (kDebugMode && loyaltyPoints > 0) {
        print("✅ [FastKey] Stored loyalty points: $loyaltyPoints for product: ${item['name']}");
      }
    }

    // Update item count in FastKey tab
    await db.update(
      AppDBConst.fastKeyTable,
      {
        AppDBConst.fastKeyTabItemCount: items.length,
        AppDBConst.fastKeyTabSynced: 1,
        AppDBConst.updatedAt: now,
      },
      where: '${AppDBConst.fastKeyId} = ?',
      whereArgs: [localTabId],
    );
  }

  /// Get the last updated timestamp for a FastKey tab
  Future<DateTime?> getFastKeyTabLastUpdated(int fastKeyServerId) async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.fastKeyItemsTable,
      where: '${AppDBConst.fastKeyIdForeignKey} = (SELECT ${AppDBConst.fastKeyId} FROM ${AppDBConst.fastKeyTable} WHERE ${AppDBConst.fastKeyServerId} = ?)',
      whereArgs: [fastKeyServerId],
      orderBy: '${AppDBConst.updatedAt} DESC',
      limit: 1,
    );

    if (result.isNotEmpty && result.first[AppDBConst.updatedAt] != null) {
      try {
        return DateTime.parse(result.first[AppDBConst.updatedAt] as String);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Check if FastKey items need refresh (older than threshold)
  Future<bool> needsFastKeyRefresh(int fastKeyServerId, {Duration threshold = const Duration(minutes: 5)}) async {
    final lastUpdated = await getFastKeyTabLastUpdated(fastKeyServerId);
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated) > threshold;
  }

  // ============================================================
  // END NEW METHODS
  // ============================================================

  ///@Naveen: why do we have these function here in db helper instead of pref file, and they have hard coded values as well
  Future<void> saveActiveFastKeyTab(int? tabId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tabId != null) {
      await prefs.setInt('activeFastKeyTabId', tabId);
    } else {
      await prefs.remove('activeFastKeyTabId');
    }
  }

  Future<int?> getActiveFastKeyTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('activeFastKeyTabId');
  }

  Future<void> refreshFastKeyItemMetadata(int fastKeyTabId) async {
    if (fastKeyTabId <= 0) {
      if (kDebugMode) print("⚠️ Invalid fastKeyTabId: $fastKeyTabId");
      return;
    }

    try {
      final items = await getFastKeyItems(fastKeyTabId);
      if (items.isEmpty) {
        if (kDebugMode) print("ℹ️ No items found for tab $fastKeyTabId");
        return;
      }

      // Ensure updated_at column exists
      final db = await DBHelper.instance.database;
      await _ensureUpdatedAtColumn(db);

      // Get product metadata
      final productMeta = await TopBar.mergedCachedProductsForSearch();
      if (productMeta.isEmpty) {
        if (kDebugMode) print("⚠️ No product metadata available");
        return;
      }

      // Build metadata map for fast lookup
      final Map<int, Map<String, dynamic>> metaMap = {};
      for (final p in productMeta) {
        final pid = _productIdFromCacheMap(p);
        if (pid != null) {
          metaMap[pid] = Map<String, dynamic>.from(p as Map);
        }
      }

      if (metaMap.isEmpty) {
        if (kDebugMode) print("⚠️ No valid product IDs found in metadata");
        return;
      }

      int updated = 0;
      int skipped = 0;
      int loyaltyUpdated = 0;

      // Update each item
      for (final item in items) {
        try {
          final productId = int.tryParse(item[AppDBConst.fastKeyProductId]?.toString() ?? '');
          if (productId == null) {
            skipped++;
            continue;
          }

          final latest = metaMap[productId];
          if (latest == null) {
            skipped++;
            continue;
          }

          // ✅ Check if FastKey already has its own loyalty points from API
          int existingLoyalty = int.tryParse(item['loyalty_points']?.toString() ?? '0') ?? 0;

          // Extract loyalty from meta_data (if any)
          int metaLoyalty = 0;
          if (latest['meta_data'] is List) {
            final loyaltyEntry = (latest['meta_data'] as List).firstWhere(
                  (m) => m['key'] == '_product_loyalty_points',
              orElse: () => <String, dynamic>{},
            );
            if (loyaltyEntry.isNotEmpty) {
              metaLoyalty = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
            }
          }

          // ✅ PRESERVE FastKey's own loyalty points (don't override if already has)
          // Only update loyalty if FastKey doesn't have it
          int finalLoyalty = existingLoyalty > 0 ? existingLoyalty : metaLoyalty;

          // Prepare update data with proper type handling
          final updateData = <String, dynamic>{
            AppDBConst.fastKeyItemName: _getStringValue(
                latest,
                ['fast_key_item_name', 'name'],
                item[AppDBConst.fastKeyItemName] ?? 'Unknown'
            ),
            AppDBConst.fastKeyItemPrice: _getDoubleValue(
                latest,
                ['fast_key_item_price', 'price', 'regular_price'],
                double.tryParse(item[AppDBConst.fastKeyItemPrice]?.toString() ?? '0') ?? 0.0
            ),
            AppDBConst.fastKeyItemImage: _resolveImage(latest) ??
                (item[AppDBConst.fastKeyItemImage]?.toString() ?? ''),
            AppDBConst.fastKeyItemSKU: _getStringValue(
                latest,
                ['fast_key_item_sku', 'sku'],
                item[AppDBConst.fastKeyItemSKU]?.toString() ?? ''
            ),
            AppDBConst.fastKeyItemTags: _getTagsJson(latest, item),
            AppDBConst.fastKeyItemMinAge: _getIntValue(
                latest,
                ['fast_key_item_min_age', 'min_age'],
                int.tryParse(item[AppDBConst.fastKeyItemMinAge]?.toString() ?? '0') ?? 0
            ),
            AppDBConst.fastKeyItemHasVariant: _hasVariants(latest) ? 1 : 0,
            // ✅ Preserve loyalty points
            'loyalty_points': finalLoyalty,
            AppDBConst.updatedAt: DateTime.now().toIso8601String(),
          };

          // ✅ Also update meta_data if available
          if (latest['meta_data'] != null) {
            updateData['meta_data'] = jsonEncode(latest['meta_data']);
          }

          // Perform update with error handling
          final result = await db.update(
            AppDBConst.fastKeyItemsTable,
            updateData,
            where: '${AppDBConst.fastKeyItemId} = ?',
            whereArgs: [item[AppDBConst.fastKeyItemId]],
          );

          if (result > 0) {
            updated++;
            if (finalLoyalty > 0) loyaltyUpdated++;
          } else {
            skipped++;
          }
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ Error updating item ${item[AppDBConst.fastKeyItemId]}: $e");
          }
          skipped++;
        }
      }

      if (kDebugMode) {
        print("✅ FastKey metadata refreshed: $updated items updated, $loyaltyUpdated with loyalty points, $skipped items skipped for tab $fastKeyTabId");
      }

      // Update the tab's sync status and timestamp
      await db.update(
        AppDBConst.fastKeyTable,
        {
          AppDBConst.fastKeyTabSynced: 1,
          AppDBConst.updatedAt: DateTime.now().toIso8601String(),
        },
        where: '${AppDBConst.fastKeyId} = ?',
        whereArgs: [fastKeyTabId],
      );

    } catch (e) {
      if (kDebugMode) {
        print("❌ Error in refreshFastKeyItemMetadata: $e");
        print("Stack trace: ${StackTrace.current}");
      }
      rethrow;
    }
  }

// Helper method to ensure updated_at column exists
  Future<void> _ensureUpdatedAtColumn(Database db) async {
    try {
      final columns = await db.rawQuery(
          "PRAGMA table_info(${AppDBConst.fastKeyItemsTable})"
      );
      final hasUpdatedAt = columns.any((col) => col['name'] == AppDBConst.updatedAt);

      if (!hasUpdatedAt) {
        if (kDebugMode) print("🔄 Adding missing updated_at column...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN ${AppDBConst.updatedAt} TEXT'
        );
        if (kDebugMode) print("✅ Added missing updated_at column");
      }

      // ✅ Check and add meta_data column if missing
      final hasMetaData = columns.any((col) => col['name'] == 'meta_data');
      if (!hasMetaData) {
        if (kDebugMode) print("🔄 Adding missing meta_data column...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN meta_data TEXT'
        );
        if (kDebugMode) print("✅ Added missing meta_data column");
      }

      // ✅ Check and add loyalty_points column if missing
      final hasLoyaltyPoints = columns.any((col) => col['name'] == 'loyalty_points');
      if (!hasLoyaltyPoints) {
        if (kDebugMode) print("🔄 Adding missing loyalty_points column...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN loyalty_points INTEGER DEFAULT 0'
        );
        if (kDebugMode) print("✅ Added missing loyalty_points column");
      }

      // ✅ Check and add type column if missing
      final hasType = columns.any((col) => col['name'] == 'type');
      if (!hasType) {
        if (kDebugMode) print("🔄 Adding missing type column...");
        await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN type TEXT DEFAULT "simple"'
        );
        if (kDebugMode) print("✅ Added missing type column");
      }

    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to check/add columns: $e");
    }
  }

// Helper method to safely get string values
  String _getStringValue(Map<String, dynamic> data, List<String> keys, String defaultValue) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key].toString();
      }
    }
    return defaultValue;
  }

// Helper method to safely get double values
  double _getDoubleValue(Map<String, dynamic> data, List<String> keys, double defaultValue) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        final value = double.tryParse(data[key].toString());
        if (value != null) return value;
      }
    }
    return defaultValue;
  }

// Helper method to safely get int values
  int _getIntValue(Map<String, dynamic> data, List<String> keys, int defaultValue) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        final value = int.tryParse(data[key].toString());
        if (value != null) return value;
      }
    }
    return defaultValue;
  }

// Helper method to safely get tags as JSON
  String _getTagsJson(Map<String, dynamic> latest, Map<String, dynamic> item) {
    try {
      final tags = latest['fast_key_item_tags'] ?? latest['tags'] ?? [];
      if (tags is List) {
        return jsonEncode(tags);
      } else if (tags is String) {
        try {
          final parsed = jsonDecode(tags);
          if (parsed is List) {
            return jsonEncode(parsed);
          }
          return jsonEncode([]);
        } catch (_) {
          return jsonEncode([]);
        }
      }
      final existingTags = item[AppDBConst.fastKeyItemTags];
      if (existingTags is String && existingTags.isNotEmpty) {
        return existingTags;
      }
      return '[]';
    } catch (_) {
      return '[]';
    }
  }

// Improved image resolution helper
  String? _resolveImage(dynamic p) {
    try {
      if (p is! Map) return null;

      final image = p['fast_key_item_image'] ?? p['image'] ?? p['src'];
      if (image is String && image.isNotEmpty) return image;

      final images = p['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is String && first.isNotEmpty) return first;
        if (first is Map) {
          return first['src']?.toString() ?? first['url']?.toString();
        }
      }

      final sizes = p['sizes'] ?? p['size'];
      if (sizes is Map) {
        final thumbnail = sizes['thumbnail'] ?? sizes['medium'];
        if (thumbnail is String && thumbnail.isNotEmpty) return thumbnail;
        if (thumbnail is Map) {
          return thumbnail['src']?.toString() ?? thumbnail['url']?.toString();
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

// Improved has variants check
  bool _hasVariants(dynamic p) {
    if (p is! Map) return false;

    try {
      if (p['type'] == 'variable') return true;
      final variations = p['variations'];
      if (variations is List && variations.isNotEmpty) return true;
      if (p['has_variants'] == true || p['has_variant'] == true) return true;
      final variantCount = int.tryParse(p['variant_count']?.toString() ?? '0');
      if (variantCount != null && variantCount > 0) return true;
      final attributes = p['attributes'];
      if (attributes is List && attributes.isNotEmpty) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

// Helper method to get product ID from cache map
  static int? _productIdFromCacheMap(dynamic raw) {
    if (raw is! Map) return null;
    final idRaw = raw["fast_key_product_id"] ?? raw["product_id"] ?? raw["id"];
    if (idRaw is int) return idRaw;
    return int.tryParse(idRaw?.toString() ?? "");
  }

}