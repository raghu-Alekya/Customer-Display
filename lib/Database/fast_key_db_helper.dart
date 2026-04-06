import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

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
      {String? sku, String? variantId, int? slNumber, int? minAge, bool? hasVariant, String? tagsJson}) async {
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

    if (kDebugMode) {
      print("#### Retrieved ${items.length} FastKey Items for Tab ID: $tabId");
    }
    return items;
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
}