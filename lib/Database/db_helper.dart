import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Constants/misc_features.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDBConst { // Build #1.0.10 - Naveen: Updated DB tables constants
  static const String dbName = 'pinaka.db'; // Database name

  // User Table
  static const String userTable = 'user_table';
  static const String userId = 'user_id';
  static const String userRole = 'role';
  static const String userDisplayName = 'display_name';
  static const String userEmail = 'email';
  static const String userFirstName = 'first_name'; // Build #1.0.13: Updated User Table
  static const String userLastName = 'last_name';
  static const String userNickname = 'nickname';
  static const String userToken = 'token';
  static const String userOrderCount = 'order_count'; // Build #1.0.108: Tracks total orders by the user
  static const String profilePhoto = 'profile_photo'; //Build #1.0.122 : Added new column's
  static const String userShiftId = 'shift_id'; // Build #1.0.149: Added shift_id column
  static const String themeMode = 'theme_mode';
  static const String layoutSelection = 'layout_selection';
  static const String orderCashbackFee = "order_cashback_fee";

  // ── Offline / Sync columns ─────────────────────────────────────────────────
  /// 0 = not yet synced to server, 1 = synced. Used in orders_table, shift_table.
  static const String synced             = 'synced';
  /// Device fingerprint (UUID) written into order meta_data.
  static const String posDeviceId        = 'pos_device_id';
  /// Terminal / table number returned by merchant-validation & login APIs.
  static const String tableId            = 'table_id';
  /// Human-readable terminal label (e.g. "Cashier-1") stored in store_validation_table / user_table.
  static const String deviceDisplayName  = 'device_display_name';
  // ── Employees offline PIN ───────────────────────────────────────────────────
  /// SHA-256 hash of the employee PIN, stored in employees_table for offline login.
  static const String employeePinHash    = 'pin_hash';
  /// Employee email, stored alongside the pin hash.
  static const String employeeEmail      = 'employee_email';
  // ── Loyalty / Customer ─────────────────────────────────────────────────────
  /// Cached loyalty point balance kept in user_table for offline redemption.
  static const String loyaltyPoints      = 'loyalty_points_balance';
  // ── Store validation extra columns ─────────────────────────────────────────
  static const String storeGstin         = 'store_gstin';
  static const String storeLogo          = 'store_logo';
  static const String deviceTableId      = 'device_table_id';  // terminal/table id from validate-merchant

  // Orders Table
  static const String orderTable = 'orders_table';
  static const String orderId = 'orders_id';
  static const String orderServerId = 'orders_server_id';
  static const String orderTotal = 'total';
  static const String orderStatus = 'status'; // e.g., pending, completed, cancelled
  static const String orderType = 'type'; // e.g., online, in-store
  static const String orderDate = 'date'; // Order creation date
  static const String orderTime = 'time'; // Order creation time
  static const String orderPaymentMethod = 'payment_method'; // e.g., cash, card, UPI
  static const String orderDiscount = 'discount'; // Optional: Discount applied to the order
  static const String merchantDiscount = 'merchant_discount'; // Build #1.0.64 //TODO: we have to handle multiple discount for single order merchant discount's
  static const String merchantDiscountIds = 'merchant_discount_ids'; //Build #1.0.94
  static const String orderTax = 'tax'; // Optional: Tax applied to the order
  static const String orderShipping = 'shipping'; // Optional: Shipping charges
  static const String orderAgeRestricted = 'age_restricted';
  static const String isEbtEligible = "is_ebt_eligible";//Build #1.0.234: Added column in order table

  // Add these new constants for order-level fields
  static const multipackDiscountTotal = 'multipack_discount_total';
  static const autoDiscountTotal = 'auto_discount_total';
  static const orderGetTime = 'get_time';

  static const multipackDiscount = 'multipack_discount_total';

  static const String multipack_discount_total = 'multipack_discount_total'; // line_item -> product_data-> regular price
  // Add these for item-level multipack discount (already present)
  static const itemMultipackDiscountTotal = 'multipack_discount_total';
  static const itemAutoDiscountMeta = 'item_auto_discount_meta';

  // Add these new constants for combo discounts
  static const comboDiscountTotal = 'combo_discount_total';
  static const displayAutoDiscount = 'display_auto_discount';


  // static const autoDiscount = 'multipack_discount_total';

  // Purchased Items Table
  static const String purchasedItemsTable = 'purchased_items_table';
  static const String itemId = 'items_id';
  static const String itemServerId = 'items_server_id'; // For delete edit or update this id is required every time so save API response with this id
  static const String itemProductId = 'item_product_id'; // Build #1.0.80: for saving product id
  static const String itemVariationId = 'item_variation_id';
  static const String itemName = 'item_name'; //For Coupons it will be "code": "123456", for payout it will be empty,
  static const String itemSKU = 'item_sku'; // Stock Keeping Unit (unique identifier for the product)
  static const String itemPrice = 'item_price';
  static const String itemImage = 'item_image';
  static const String itemCount = 'items_count'; // Quantity of the item
  static const String itemSumPrice = 'item_sum_price'; // Total price (quantity * price)
  static const String itemType = 'item_type'; // Enum (Product, Coupon, Payout)
  static const String orderIdForeignKey = 'order_id'; // Links to the order this item belongs to
  static const String itemVariationCustomName = 'item_variation_custom_name'; //  line_item -> product_variation_data -> meta_data -> custom_name
  static const String itemVariationCount = 'item_variation_count'; // line_item -> product_data -> variations array
  static const String itemCombo = 'item_combo'; // line_item -> meta_data->value contains (combo)
  static const String itemSalesPrice = 'item_sales_price'; // It is a Discounted price = line_item -> product_data-> sales price * quantity
  static const String itemRegularPrice = 'item_regular_price'; //It is a Regular price = line_item -> product_data-> regular price * quantity
  static const String itemUnitPrice = 'item_unit_price';
  static const String isRefundItem = 'is_refund_item';// line_item -> product_data-> regular price
  // Offline refund / inventory audit
  static const String fastKeyStockQuantity = 'stock_quantity';
  static const String inventoryLogTable = 'inventory_log_table';
  static const String inventoryLogId = 'inventory_log_id';
  static const String inventoryLogOrderId = 'order_id';
  static const String inventoryLogOrderItemId = 'order_item_id';
  static const String inventoryLogProductId = 'product_id';
  static const String inventoryLogQuantity = 'quantity';
  static const String inventoryLogAction = 'action';
  static const String inventoryLogReason = 'reason';
  static const String inventoryLogCreatedAt = 'created_at';
  static const String inventoryLogSynced = 'synced';
  static const String inventoryLogPosDeviceId = 'pos_device_id';



  // For order table (you might want these too)
  static const orderMultipackDiscount = 'multipack_discount_applied';
  static const orderAutoDiscountTotal = 'auto_discount_total';


  // Coupon Items Table: remove if above itemType is not working properly
  static const String couponsItemsTable = 'coupons_items_table';
  static const String couponId = 'coupon_id';
  static const String couponCode = 'coupon_code';
  static const String couponNominalAmount = 'coupon_nominal_amount';

  // Build #1.0.11 : FastKey Tabs Table Updated
  static const String fastKeyTable = 'fast_key_tabs';
  static const String fastKeyId = 'fast_key_id';
  static const String fastKeyServerId = 'fast_key_server_id';
  static const String userIdForeignKey = 'user_id';
  static const String fastKeyTabTitle = 'fast_key_tab_title';
  static const String fastKeyTabImage = 'fast_key_tab_image';
  static const String fastKeyTabItemCount = 'fast_key_tab_item_count';
  static const String fastKeyTabIndex = 'fast_key_tab_index'; // Build #1.0.12
  static const String fastKeyTabSynced = 'synced'; // Build #1.0.15 : Tracks sync status

  // Build #1.0.11 : FastKey Items Table Added
  static const String fastKeyItemsTable = 'fast_key_items';
  static const String fastKeyItemId = 'fast_key_item_id';
  static const String fastKeyProductId = 'fast_key_product_id'; // Build #1.0.19: Updated new colum's
  static const String fastKeySlNumber = 'fast_key_sl_number'; // server id
  static const String fastKeyIdForeignKey = 'fast_key_id';
  static const String fastKeyItemName = 'fast_key_item_name';
  static const String fastKeyItemImage = 'fast_key_item_image';
  static const String fastKeyItemPrice = 'fast_key_item_price';
  static const String fastKeyItemSKU = 'fast_key_item_sku';
  static const String fastKeyItemMinAge = 'fast_key_item_min_age'; // for age restriction
  static const String fastKeyItemVariantId = 'fast_key_item_variant_id';
  static const String fastKeyItemIsVariant = 'fast_key_item_is_variant';
  static const String fastKeyItemHasVariant = 'fast_key_item_has_variant';
  /// JSON array of Woo tags from Fast Keys API (EBT, age restriction, etc.)
  static const String fastKeyItemTags = 'fast_key_item_tags';
  // Add these to AppDBConst class
  static const String fastKeyItemMetaData = 'meta_data';
  static const String fastKeyItemLoyaltyPoints = 'loyalty_points';
  static const String fastKeyItemType = 'type';
// In AppDBConst class, add:
  static const String updatedAt = 'updated_at';
  /// Printer Table Added
  static const String printerTable = 'printer_table';
  static const String printerId = 'printer_id';
  static const String printerDeviceName = 'device_name';
  static const String printerProductId = 'product_id';
  static const String printerVendorId = 'vendor_id';
  static const String printerType = 'type_printer';
  static const String receiptIconPath = 'receipt_icon_path'; //Build #1.0.122 : Added new column's
  static const String receiptHeaderText = 'receipt_header_text';
  static const String receiptFooterText = 'receipt_footer_text';

  //Build #1.0.42: Added Store Validation Table
  static const String storeValidationTable = 'store_validation_table';
  static const String storeValidationId = 'id';
  static const String storeId = 'store_id';
  static const String storeUserId = 'user_id';
  static const String username = 'username';
  static const String email = 'email';
  static const String subscriptionType = 'subscription_type';
  static const String storeName = 'store_name';
  static const String expirationDate = 'expiration_date';
  static const String storeBaseUrl = 'store_base_url';
  static const String storeAddress = 'store_address';
  static const String storePhone = 'store_phone';
  static const String storeInfo = 'store_info';
  static const String licenseKey = 'license_key';
  static const String licenseStatus = 'license_status';

  //Build #1.0.54: added Asset Tables
  static const String assetTable = 'asset_table';
  static const String mediaTable = 'media_table';
  static const String taxTable = 'tax_table';
  static const String couponTable = 'coupon_table';
  static const String orderStatusTable = 'order_status_table';
  static const String roleTable = 'role_table';
  static const String subscriptionPlanTable = 'subscription_plan_table';
  static const String storeDetailsTable = 'store_details_table';
  static const String notesDenomTable = 'notes_denom_table'; // Build #1.0.69 : updated assets table based on api response
  static const String coinDenomTable = 'coin_denom_table';
  static const String safeDenomTable = 'safe_denom_table';
  static const String tubesDenomTable = 'tubes_denom_table';
  static const String maxTubesCount = 'max_tubes_count';
  static const String safeDropAmount = 'safe_drop_amount';
  static const String drawerAmount = 'drawer_amount';
  static const String vendorTable = 'vendor_table';  //Build #1.0.74: Naveen Added
  static const String vendorPaymentTypesTable = 'vendor_payment_types_table';
  static const String vendorPaymentPurposeTable = 'vendor_payment_purpose_table';
  static const String vendorId = 'vendor_id';
  static const String vendorName = 'vendor_name';
  static const String paymentType = 'payment_type';
  static const String paymentPurpose = 'payment_purpose';
  static const String employeesTable = 'employees_table';
  static const String employeeId = 'employees_id';
  static const String employeeDisplayName = 'employees_display_name';
  static const String orderTypeTable = 'order_type_table';

  static const String assetId = 'asset_id';
  static const String baseUrl = 'base_url';
  static const String currency = 'currency';
  static const String currencySymbol = 'currency_symbol';
  // Shift Table
  static const String shiftTable = 'shift_table';

  static const String shiftLocalId = 'local_shift_id';
  static const String shiftServerId = 'shift_id';

  static const String shiftStartTime = 'start_time';
  static const String shiftEndTime = 'end_time';

  static const String shiftOpeningBalance = 'opening_balance';
  static const String shiftClosingBalance = 'closing_balance';
  static const String shiftTotalSalesAmount = 'total_sales_amount';
  static const String shiftSafeDropTotal = 'safe_drop_total';
  static const String shiftVendorPayoutTotal = 'vendor_payout_total';
  static const String shiftOverShort = 'over_short';

  static const String shiftStatus = 'shift_status';
  static const String shiftSyncStatus = 'sync_status';
  static const String shiftCreatedAt = 'created_at';
}

class DBHelper {
  // Singleton instance to ensure only one instance of DBHelper exists
  static final DBHelper instance = DBHelper._init();
  DBHelper._init();
  Database? _database;

  // Getter for the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppDBConst.dbName);
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDB(String filePath) async {
    if(Platform.isWindows){
      // Init ffi loader if needed.
      sqfliteFfiInit();
      var databaseFactory = databaseFactoryFfi;
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, filePath);

      if (kDebugMode) {
        print("#### DB Path: $path ; enableDBDelete: ${Misc.enableDBDelete}");
      }
      ///Todo: Uncomment the line below to delete the database during development/testing
      if(Misc.enableDBDelete) {
        if (kDebugMode) {
          print("DBHelper delete database");
        }
        await databaseFactory.deleteDatabase(path);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // This removes all stored preferences
      }
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6, // Offline refund/inventory recovery schema
          onCreate: _createTables,
          onUpgrade: _upgradeTables,
        ),
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    if (kDebugMode) {
      print("#### DB Path: $path ; enableDBDelete: ${Misc.enableDBDelete}");
    }
    ///Todo: Uncomment the line below to delete the database during development/testing
    if(Misc.enableDBDelete) {
      if (kDebugMode) {
        print("DBHelper delete database");
      }
      await deleteDatabase(path);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // This removes all stored preferences
    }

    return await openDatabase(
      path,
      version: 6, // Offline refund/inventory recovery schema
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  // Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
  //   // Upgrade to version 2
  //   if (oldVersion < 2) {
  //     try {
  //       await db.execute(
  //         'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN ${AppDBConst.fastKeyItemTags} TEXT',
  //       );
  //       if (kDebugMode) print('✅ Upgraded to v2: fast_key_item_tags added');
  //     } catch (e) {
  //       if (kDebugMode) print('v2 upgrade (may already exist): $e');
  //     }
  //   }
  //
  //   // Upgrade to version 3
  //   if (oldVersion < 3) {
  //     try {
  //       // First check if column exists
  //       final columns = await db.rawQuery(
  //           "PRAGMA table_info(${AppDBConst.fastKeyItemsTable})"
  //       );
  //       final hasUpdatedAt = columns.any((col) => col['name'] == AppDBConst.updatedAt);
  //
  //       if (!hasUpdatedAt) {
  //         await db.execute(
  //           'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN ${AppDBConst.updatedAt} TEXT',
  //         );
  //         if (kDebugMode) print('✅ Upgraded to v3: updated_at column added');
  //       } else {
  //         if (kDebugMode) print('✅ v3: updated_at column already exists');
  //       }
  //     } catch (e) {
  //       if (kDebugMode) print('v3 upgrade error: $e');
  //     }
  //   }
  // }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print("🔄 Upgrading database from version $oldVersion to $newVersion");
    }

    // Upgrade to version 2
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN ${AppDBConst.fastKeyItemTags} TEXT',
        );
        if (kDebugMode) print('✅ Upgraded to v2: fast_key_item_tags added');
      } catch (e) {
        if (kDebugMode) print('v2 upgrade (may already exist): $e');
      }
    }

    // Upgrade to version 3 (add updated_at)
    if (oldVersion < 3) {
      try {
        final columns = await db.rawQuery(
            "PRAGMA table_info(${AppDBConst.fastKeyItemsTable})"
        );
        final hasUpdatedAt = columns.any((col) => col['name'] == AppDBConst.updatedAt);

        if (!hasUpdatedAt) {
          await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN ${AppDBConst.updatedAt} TEXT',
          );
          if (kDebugMode) print('✅ Upgraded to v3: updated_at added');
        }
      } catch (e) {
        if (kDebugMode) print('v3 upgrade error: $e');
      }
    }

    // Upgrade to version 4 (add meta_data, loyalty_points, type)
    if (oldVersion < 4) {
      try {
        final columns = await db.rawQuery(
            "PRAGMA table_info(${AppDBConst.fastKeyItemsTable})"
        );
        final columnNames = columns.map((col) => col['name'] as String).toList();

        if (kDebugMode) {
          print("📋 Existing columns: $columnNames");
        }

        // Add meta_data column
        if (!columnNames.contains('meta_data')) {
          await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN meta_data TEXT',
          );
          if (kDebugMode) print('✅ Added meta_data column');
        }

        // Add loyalty_points column
        if (!columnNames.contains('loyalty_points')) {
          await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN loyalty_points INTEGER DEFAULT 0',
          );
          if (kDebugMode) print('✅ Added loyalty_points column');
        }

        // Add type column
        if (!columnNames.contains('type')) {
          await db.execute(
            'ALTER TABLE ${AppDBConst.fastKeyItemsTable} ADD COLUMN type TEXT DEFAULT "simple"',
          );
          if (kDebugMode) print('✅ Added type column');
        }

        if (kDebugMode) print('✅ Upgraded to v4: meta_data, loyalty_points, type added');

      } catch (e) {
        if (kDebugMode) print('❌ v4 upgrade error: $e');
        rethrow;
      }
    }

    // ── v5: Offline / Sync support columns ──────────────────────────────────
    if (oldVersion < 5) {
      Future<void> _safeAlter(String sql) async {
        try { await db.execute(sql); } catch (_) {}
      }

      // orders_table: synced flag, device meta
      await _safeAlter('ALTER TABLE ${AppDBConst.orderTable} ADD COLUMN ${AppDBConst.synced} INTEGER DEFAULT 0');
      await _safeAlter('ALTER TABLE ${AppDBConst.orderTable} ADD COLUMN ${AppDBConst.posDeviceId} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.orderTable} ADD COLUMN ${AppDBConst.tableId} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.orderTable} ADD COLUMN ${AppDBConst.deviceDisplayName} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.orderTable} ADD COLUMN ${AppDBConst.isEbtEligible} INTEGER DEFAULT 0');

      // employees_table: offline PIN hash + email
      await _safeAlter('ALTER TABLE ${AppDBConst.employeesTable} ADD COLUMN ${AppDBConst.employeePinHash} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.employeesTable} ADD COLUMN ${AppDBConst.employeeEmail} TEXT');

      // user_table: loyalty points balance cache
      await _safeAlter('ALTER TABLE ${AppDBConst.userTable} ADD COLUMN ${AppDBConst.loyaltyPoints} INTEGER DEFAULT 0');
      await _safeAlter('ALTER TABLE ${AppDBConst.userTable} ADD COLUMN ${AppDBConst.posDeviceId} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.userTable} ADD COLUMN ${AppDBConst.tableId} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.userTable} ADD COLUMN ${AppDBConst.deviceDisplayName} TEXT');

      // store_validation_table: device info + logo + gstin
      await _safeAlter('ALTER TABLE ${AppDBConst.storeValidationTable} ADD COLUMN ${AppDBConst.deviceDisplayName} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.storeValidationTable} ADD COLUMN ${AppDBConst.deviceTableId} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.storeValidationTable} ADD COLUMN ${AppDBConst.storeLogo} TEXT');
      await _safeAlter('ALTER TABLE ${AppDBConst.storeValidationTable} ADD COLUMN ${AppDBConst.storeGstin} TEXT');

      if (kDebugMode) print('✅ Upgraded to v5: offline columns added');
    }

    // ── v6: Offline refund + inventory audit support ───────────────────────
    if (oldVersion < 6) {
      Future<void> _safeAlterV6(String sql) async {
        try {
          await db.execute(sql);
        } catch (e) {
          if (kDebugMode) print('v6 migration skipped/already applied: $e');
        }
      }

      await _safeAlterV6(
        'ALTER TABLE ${AppDBConst.fastKeyItemsTable} '
        'ADD COLUMN ${AppDBConst.fastKeyStockQuantity} INTEGER DEFAULT 0',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppDBConst.inventoryLogTable} (
          ${AppDBConst.inventoryLogId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${AppDBConst.inventoryLogOrderId} INTEGER,
          ${AppDBConst.inventoryLogOrderItemId} INTEGER,
          ${AppDBConst.inventoryLogProductId} TEXT,
          ${AppDBConst.inventoryLogQuantity} INTEGER NOT NULL,
          ${AppDBConst.inventoryLogAction} TEXT NOT NULL,
          ${AppDBConst.inventoryLogReason} TEXT,
          ${AppDBConst.inventoryLogCreatedAt} TEXT NOT NULL,
          ${AppDBConst.inventoryLogSynced} INTEGER DEFAULT 0,
          ${AppDBConst.inventoryLogPosDeviceId} TEXT
        )
      ''');

      if (kDebugMode) print('✅ Upgraded to v6: refund/inventory support ready');
    }
  }

  // Create all tables in the database
  Future _createTables(Database db, int version) async {
    // User Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.userTable} (
      ${AppDBConst.userId} INTEGER PRIMARY KEY,
      ${AppDBConst.userRole} TEXT,
      ${AppDBConst.userDisplayName} TEXT,
      ${AppDBConst.userEmail} TEXT UNIQUE NOT NULL,
      ${AppDBConst.userFirstName} TEXT,
      ${AppDBConst.userLastName} TEXT,
      ${AppDBConst.userNickname} TEXT,
      ${AppDBConst.userToken} TEXT NOT NULL,
      ${AppDBConst.userOrderCount} INTEGER DEFAULT 0, -- Optional: Tracks total orders by the user
      ${AppDBConst.profilePhoto} TEXT,
      ${AppDBConst.themeMode} TEXT,
      ${AppDBConst.layoutSelection} TEXT,
      ${AppDBConst.userShiftId} INTEGER
    )
    ''');

    //Build #1.0.40:  Updated Orders Table
    await db.execute('''
CREATE TABLE ${AppDBConst.orderTable} (
  ${AppDBConst.orderId} INTEGER PRIMARY KEY, -- Use API id, no AUTOINCREMENT
  ${AppDBConst.orderServerId} INTEGER, -- Updated by REST API, can be NULL initially
  ${AppDBConst.userId} INTEGER NOT NULL,

  ${AppDBConst.orderTotal} REAL NOT NULL,
  ${AppDBConst.orderStatus} TEXT NOT NULL,
  ${AppDBConst.orderType} TEXT NOT NULL,
  ${AppDBConst.orderDate} TEXT NOT NULL,
  ${AppDBConst.orderTime} TEXT NOT NULL,

  ${AppDBConst.orderPaymentMethod} TEXT, -- cash, card, etc.

  ${AppDBConst.orderDiscount} REAL DEFAULT 0, -- Manual order discount
  ${AppDBConst.merchantDiscount} REAL DEFAULT 0, -- Merchant discount
  ${AppDBConst.merchantDiscountIds} TEXT, -- Merchant discount IDs

  ${AppDBConst.orderTax} REAL DEFAULT 0,
  ${AppDBConst.orderShipping} REAL DEFAULT 0,

  ${AppDBConst.orderAgeRestricted} TEXT,

  -- Multipack / automatic discounts
  multipack_discount_applied INTEGER DEFAULT 0, -- 0 = false, 1 = true
  ${AppDBConst.multipack_discount_total} REAL DEFAULT 0,
  auto_discount_total REAL DEFAULT 0,

  ${AppDBConst.comboDiscountTotal} REAL DEFAULT 0,
  ${AppDBConst.displayAutoDiscount} REAL DEFAULT 0,

  -- Build #offline: Sync tracking & terminal identity
  ${AppDBConst.synced} INTEGER DEFAULT 0,
  ${AppDBConst.posDeviceId} TEXT,
  ${AppDBConst.tableId} TEXT,
  ${AppDBConst.deviceDisplayName} TEXT,
  ${AppDBConst.isEbtEligible} INTEGER DEFAULT 0,

  FOREIGN KEY(${AppDBConst.userId})
    REFERENCES ${AppDBConst.userTable}(${AppDBConst.userId})
    ON DELETE CASCADE
)
''');


    // Purchased Items Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.purchasedItemsTable} (
      ${AppDBConst.itemId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppDBConst.itemServerId} INTEGER, -- Required: Updated by REST API, can be NULL initially
      ${AppDBConst.itemProductId} INTEGER,
      ${AppDBConst.itemVariationId} INTEGER,
      ${AppDBConst.itemName} TEXT NOT NULL,
      ${AppDBConst.itemSKU} TEXT NOT NULL,
      ${AppDBConst.itemPrice} REAL NOT NULL,
      ${AppDBConst.itemImage} TEXT NOT NULL,
      ${AppDBConst.itemCount} INTEGER NOT NULL,
      ${AppDBConst.itemSumPrice} REAL NOT NULL,
      ${AppDBConst.itemVariationCustomName} TEXT,
      ${AppDBConst.itemVariationCount} INTEGER,
      ${AppDBConst.itemCombo} TEXT,
      ${AppDBConst.itemSalesPrice} REAL,
      ${AppDBConst.itemRegularPrice} REAL,
      ${AppDBConst.itemUnitPrice} REAL,
      ${AppDBConst.orderIdForeignKey} INTEGER NOT NULL,
      ${AppDBConst.itemType} TEXT NOT NULL,
     ${AppDBConst.multipack_discount_total} REAL DEFAULT 0, -- correct syntax
     ${AppDBConst.autoDiscountTotal} REAL DEFAULT 0, -- correct syntax
     -- ADD THIS COLUMN
     is_ebt_eligible INTEGER DEFAULT 0,

     ${AppDBConst.comboDiscountTotal} REAL DEFAULT 0, -- NEW: For "Discount Applied" combo discounts
     ${AppDBConst.displayAutoDiscount} REAL DEFAULT 0, -- NEW: For "auto_discount_amount" display discounts
      is_refund_item INTEGER DEFAULT 0,

      FOREIGN KEY(${AppDBConst.orderIdForeignKey}) REFERENCES ${AppDBConst.orderTable}(${AppDBConst.orderServerId}) ON DELETE CASCADE
    )
    ''');

    // Build #1.0.11 : FastKey Tabs Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.fastKeyTable} (
      ${AppDBConst.fastKeyId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppDBConst.fastKeyServerId} INTEGER NOT NULL,
      ${AppDBConst.userIdForeignKey} INTEGER NOT NULL,
      ${AppDBConst.fastKeyTabTitle} TEXT NOT NULL,
      ${AppDBConst.fastKeyTabImage} TEXT NOT NULL,
      ${AppDBConst.fastKeyTabItemCount} INTEGER NOT NULL,
      ${AppDBConst.fastKeyTabIndex} TEXT NOT NULL,
      ${AppDBConst.fastKeyTabSynced} INTEGER DEFAULT 0, -- 0 = false, 1 = true
      
      FOREIGN KEY(${AppDBConst.userIdForeignKey}) REFERENCES ${AppDBConst.userTable}(${AppDBConst.userId}) ON DELETE CASCADE
    )
    ''');

    // Build #1.0.11 : FastKey Product Items Table
    // Build #1.0.11 : FastKey Product Items Table
    await db.execute('''
CREATE TABLE ${AppDBConst.fastKeyItemsTable} (
  ${AppDBConst.fastKeyItemId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${AppDBConst.fastKeyIdForeignKey} INTEGER NOT NULL,
  ${AppDBConst.fastKeyItemName} TEXT NOT NULL,
  ${AppDBConst.fastKeyProductId} TEXT NOT NULL,
  ${AppDBConst.fastKeySlNumber} TEXT NOT NULL,
  ${AppDBConst.fastKeyItemImage} TEXT NOT NULL,
  ${AppDBConst.fastKeyItemPrice} REAL NOT NULL,
  ${AppDBConst.fastKeyItemSKU} TEXT NOT NULL,
  ${AppDBConst.fastKeyItemMinAge} INTEGER,
  ${AppDBConst.fastKeyItemIsVariant} INTEGER,
  ${AppDBConst.fastKeyItemHasVariant} INTEGER,
  ${AppDBConst.fastKeyItemVariantId} TEXT NOT NULL,
  ${AppDBConst.fastKeyItemTags} TEXT,
  ${AppDBConst.updatedAt} TEXT,
  ${AppDBConst.fastKeyItemMetaData} TEXT,
  ${AppDBConst.fastKeyItemLoyaltyPoints} INTEGER DEFAULT 0,
  ${AppDBConst.fastKeyItemType} TEXT DEFAULT 'simple',
  ${AppDBConst.fastKeyStockQuantity} INTEGER DEFAULT 0,
  FOREIGN KEY(${AppDBConst.fastKeyIdForeignKey}) REFERENCES ${AppDBConst.fastKeyTable}(${AppDBConst.fastKeyId}) ON DELETE CASCADE
)
''');

    // Offline refund / inventory audit table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppDBConst.inventoryLogTable} (
        ${AppDBConst.inventoryLogId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppDBConst.inventoryLogOrderId} INTEGER,
        ${AppDBConst.inventoryLogOrderItemId} INTEGER,
        ${AppDBConst.inventoryLogProductId} TEXT,
        ${AppDBConst.inventoryLogQuantity} INTEGER NOT NULL,
        ${AppDBConst.inventoryLogAction} TEXT NOT NULL,
        ${AppDBConst.inventoryLogReason} TEXT,
        ${AppDBConst.inventoryLogCreatedAt} TEXT NOT NULL,
        ${AppDBConst.inventoryLogSynced} INTEGER DEFAULT 0,
        ${AppDBConst.inventoryLogPosDeviceId} TEXT
      )
    ''');

    /// Printer Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.printerTable} (
      ${AppDBConst.printerId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppDBConst.printerDeviceName} TEXT NOT NULL,
      ${AppDBConst.printerProductId} TEXT NOT NULL,
      ${AppDBConst.printerVendorId} TEXT NOT NULL,
      ${AppDBConst.printerType} TEXT NOT NULL,
      ${AppDBConst.receiptIconPath} TEXT,
      ${AppDBConst.receiptHeaderText} TEXT,
      ${AppDBConst.receiptFooterText} TEXT
    )
    ''');

    //Build #1.0.42: Store Validation Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.storeValidationTable} (
      ${AppDBConst.storeValidationId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppDBConst.storeId} TEXT NOT NULL,
      ${AppDBConst.storeUserId} INTEGER NOT NULL,
      ${AppDBConst.username} TEXT NOT NULL,
      ${AppDBConst.email} TEXT NOT NULL,
      ${AppDBConst.subscriptionType} TEXT NOT NULL,
      ${AppDBConst.storeName} TEXT NOT NULL,
      ${AppDBConst.expirationDate} TEXT NOT NULL,
      ${AppDBConst.storeBaseUrl} TEXT NOT NULL,
      ${AppDBConst.storeAddress} TEXT NOT NULL,
      ${AppDBConst.storePhone} TEXT NOT NULL,
      ${AppDBConst.storeInfo} TEXT NOT NULL,
      ${AppDBConst.licenseKey} TEXT NOT NULL,
      ${AppDBConst.licenseStatus} TEXT NOT NULL,
      ${AppDBConst.deviceDisplayName} TEXT,
      ${AppDBConst.deviceTableId} TEXT,
      ${AppDBConst.storeLogo} TEXT,
      ${AppDBConst.storeGstin} TEXT
    )
  ''');

    //Build #1.0.54: added Asset Table
    // ${AppDBConst.assetId} INTEGER PRIMARY KEY AUTOINCREMENT,
    await db.execute('''
    CREATE TABLE ${AppDBConst.assetTable} (
      ${AppDBConst.assetId} INTEGER PRIMARY KEY,
      ${AppDBConst.baseUrl} TEXT NOT NULL,
      ${AppDBConst.currency} TEXT NOT NULL,
      ${AppDBConst.currencySymbol} TEXT NOT NULL,
      ${AppDBConst.maxTubesCount} TEXT,
      ${AppDBConst.safeDropAmount} TEXT,
      ${AppDBConst.drawerAmount} TEXT
    )
    ''');

    // Media Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.mediaTable} (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    //Build #1.0.68 : updated Tax Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.taxTable} (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Coupon Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.couponTable} (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL,
      amount TEXT NOT NULL,
      discount_type TEXT NOT NULL,
      usage_limit TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Order Status Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.orderStatusTable} (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Role Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.roleTable} (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Subscription Plan Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.subscriptionPlanTable} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      key TEXT NOT NULL,
      expiration TEXT NOT NULL,
      origin TEXT NOT NULL,
      store_id INTEGER NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Store Details Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.storeDetailsTable} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      city TEXT NOT NULL,
      state TEXT NOT NULL,
      country TEXT NOT NULL,
      zip_code TEXT NOT NULL,
      phone_number INTEGER, -- Removed NOT NULL constraint
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.notesDenomTable} (
      denom TEXT PRIMARY KEY,
      image TEXT,
      tube_limit INTEGER,
      symbol TEXT,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.coinDenomTable} (
      denom TEXT PRIMARY KEY,
      image TEXT,
      tube_limit INTEGER,
      symbol TEXT,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.safeDenomTable} (
      denom TEXT PRIMARY KEY,
      image TEXT,
      tube_limit INTEGER,
      symbol TEXT,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.tubesDenomTable} (
      denom TEXT PRIMARY KEY,
      image TEXT,
      tube_limit INTEGER,
      symbol TEXT,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    //Build #1.0.74: Naveen Added
    await db.execute('''
    CREATE TABLE ${AppDBConst.vendorTable} (
      ${AppDBConst.vendorId} INTEGER PRIMARY KEY,
      ${AppDBConst.vendorName} TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.vendorPaymentTypesTable} (
      ${AppDBConst.paymentType} TEXT PRIMARY KEY,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE ${AppDBConst.vendorPaymentPurposeTable} (
      ${AppDBConst.paymentPurpose} TEXT PRIMARY KEY,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Employees Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.employeesTable} (
      ${AppDBConst.employeeId} TEXT PRIMARY KEY,
      ${AppDBConst.employeeDisplayName} TEXT NOT NULL,
      ${AppDBConst.employeePinHash} TEXT,
      ${AppDBConst.employeeEmail} TEXT,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');

    // Order Types Table
    await db.execute('''
    CREATE TABLE ${AppDBConst.orderTypeTable} (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ${AppDBConst.assetId} INTEGER NOT NULL,
      FOREIGN KEY(${AppDBConst.assetId}) REFERENCES ${AppDBConst.assetTable}(${AppDBConst.assetId}) ON DELETE CASCADE
    )
    ''');
// Shift Table
    await db.execute('''
  CREATE TABLE ${AppDBConst.shiftTable} (
    ${AppDBConst.shiftLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
    ${AppDBConst.shiftServerId} INTEGER,
    ${AppDBConst.userId} INTEGER NOT NULL,

    ${AppDBConst.shiftStartTime} TEXT NOT NULL,
    ${AppDBConst.shiftEndTime} TEXT,

    ${AppDBConst.shiftOpeningBalance} REAL DEFAULT 0,
    ${AppDBConst.shiftClosingBalance} REAL DEFAULT 0,
    ${AppDBConst.shiftTotalSalesAmount} REAL DEFAULT 0,
    ${AppDBConst.shiftSafeDropTotal} REAL DEFAULT 0,
    ${AppDBConst.shiftVendorPayoutTotal} REAL DEFAULT 0,
    ${AppDBConst.shiftOverShort} REAL DEFAULT 0,

    ${AppDBConst.shiftStatus} TEXT NOT NULL,
    ${AppDBConst.shiftSyncStatus} TEXT DEFAULT 'PENDING',
    ${AppDBConst.shiftCreatedAt} TEXT,
    ${AppDBConst.updatedAt} TEXT,

    FOREIGN KEY(${AppDBConst.userId})
      REFERENCES ${AppDBConst.userTable}(${AppDBConst.userId})
      ON DELETE CASCADE
  )
''');
    if (kDebugMode) {
      print("#### All tables created successfully!");
    }
  }

  // Close the database connection
  Future<void> close() async {
    final db = await database;
    db.close();

    if (kDebugMode) {
      print("#### Database connection closed!");
    }
  }


  Future<void> insertPurchasedItem(Map<String, dynamic> item) async {
    final db = await DBHelper.instance.database;

    await db.insert(
      AppDBConst.purchasedItemsTable,
      {
        AppDBConst.itemServerId: item['serverId'],
        AppDBConst.itemProductId: item['productId'],
        AppDBConst.itemVariationId: item['variationId'],
        AppDBConst.itemName: item['name'],
        AppDBConst.itemSKU: item['sku'],
        AppDBConst.itemPrice: item['price'],
        AppDBConst.itemImage: item['image'],
        AppDBConst.itemCount: item['count'],
        AppDBConst.itemSumPrice: item['sumPrice'],
        AppDBConst.itemVariationCustomName: item['variationCustomName'],
        AppDBConst.itemVariationCount: item['variationCount'],
        AppDBConst.itemCombo: item['combo'],
        AppDBConst.itemSalesPrice: item['salesPrice'],
        AppDBConst.itemRegularPrice: item['regularPrice'],
        AppDBConst.itemUnitPrice: item['unitPrice'],
        AppDBConst.orderIdForeignKey: item['orderId'],
        AppDBConst.itemType: item['type'],
        AppDBConst.multipack_discount_total: item['multipack_discount_total'] ?? 0,
        AppDBConst.autoDiscountTotal: item['auto_discount_total'] ?? 0, // fixed
        AppDBConst.comboDiscountTotal: item['combo_discount_total'] ?? 0,
        AppDBConst.displayAutoDiscount: item['display_auto_discount'] ?? 0,
        'is_refund_item': (item['is_refund_item'] ?? false) == true ? 1 : 0,
        /// 🔹 ADD THIS
        'is_ebt_eligible': item['is_ebt_eligible'] ?? 0,

      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

}

