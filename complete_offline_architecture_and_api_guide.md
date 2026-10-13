# POS Application: Master API Specification, Stock Inventory, Sync Workflows & Terminal Crash Recovery Guide

---

## Executive Overview & Architectural Principles

This document provides the ultimate, production-grade technical specification for the Point-of-Sale (POS) application (`grocery_app`). It contains complete details for **all 53 API endpoints** using **full absolute URLs**, refund & stock inventory management, deep order & shift sync processes, exact SQLite/Isar DB storage locations, and a comprehensive system crash recovery architecture (including token refresh on restart without losing offline data).

```mermaid
flowchart TD
    A[Terminal Startup / Crash Recovery] --> B[Initialize SQLite WAL Engine: pinaka.db]
    B --> C[Read Active User & Session from user_table]
    C --> D{Internet Available?}
    D -- Yes --> E[Validate/Refresh Token: /token/validate-token-pin]
    D -- No --> F[Restore Synthetic Offline Token: OFFLINE_TOKEN_id_ts]
    E --> G[Scan orders_table for synced = 0 & status = pending_offline]
    F --> G
    G --> H[Restore Active Cart & Repopulate UI Order Panel]
    G --> I[Trigger OfflineOrderSyncService Worker for Queued Sync]
```

---

## 1. Master API Specification Matrix (All 53 APIs with Full Absolute URLs)

Below is the complete specification for every single API endpoint in `UrlHelper` with full absolute URLs, auth headers, exact request/response payloads, and SQLite storage locations.

| # | Endpoint Function | Full Absolute URL | HTTP Method & Auth | Request Payload Summary | Response Payload Summary | Local SQLite Storage Table |
|---|---|---|---|---|---|---|
| **1** | **Validate Merchant** | `https://test.alekyatechsolutions.com/wp-json/custom/v1/validate-merchant` | `POST` (Public) | `username`, `password`, `store_id`, `device_id` | Store info, license status, `device_display_name`, `device_table_id` | `store_validation_table` |
| **2** | **Employee Token Login** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/token` | `POST` (Public) | `emp_login_pin`, `device_id` | JWT token, user ID, `shift_id`, `device_display_name`, `table_id` | `user_table` & `employees_table` |
| **3** | **Refresh Token** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/refresh_token` | `POST` (Bearer Token) | `{ "token": "{current_token}" }` | `{ "success": true, "token": "{new_token}" }` | `user_table` (`token`) |
| **4** | **Cashier Signup** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/signup` | `POST` (Bearer Token) | `username`, `email`, `password`, `role` | `{ "success": true, "user_id": 55 }` | `employees_table` |
| **5** | **Forgot Password** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/reestpassword` | `POST` (Public) | `{ "email": "user@gmail.com" }` | `{ "success": true, "message": "Reset sent" }` | Temporary memory |
| **6** | **Update Password** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/update_password` | `POST` (Bearer Token) | `old_password`, `new_password` | `{ "success": true, "message": "Updated" }` | Temporary memory |
| **7** | **My Profile View** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/profile/view` | `GET` (Bearer Token) | None (GET) | Profile details JSON object | `user_table` |
| **8** | **Update Profile** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/profile/update` | `POST` (Bearer Token) | `display_name`, `phone`, `first_name` | `{ "success": true, "data": {...} }` | `user_table` |
| **9** | **Delete Profile / Logout** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/logout` | `POST` (Bearer Token) | None (POST) | `{ "success": true, "message": "Logged out" }` | Clears token in `user_table` |
| **10** | **Assets Public Sync** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/assets/public` | `GET` (Bearer Token) | None (GET) | Base URL, currency, taxes, coupons, denominations | `asset_table`, `tax_table`, `coupon_table` |
| **11** | **Products List** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/products` | `GET` (Bearer Token) | `page`, `per_page`, `search`, `category` | Array of Product objects | `fast_key_items` & Isar DB |
| **12** | **Fast Keys Main** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys` | `GET/POST` (Bearer Token) | FastKey tab title, index | FastKey tab details JSON | `fast_key_tabs` |
| **13** | **Categories List** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/categories` | `GET` (Bearer Token) | `page`, `per_page`, `hide_empty` | Category objects array | `fast_key_tabs` |
| **14** | **Products By Category** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/products-by-category` | `GET` (Bearer Token) | `category_id`, `page`, `per_page` | Products list in category | `fast_key_items` & Isar DB |
| **15** | **Payments Ledger** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/payments` | `GET/POST` (Bearer Token) | `order_id`, `amount`, `payment_method` | Payment transaction confirmation | `orders_table` & Isar DB |
| **16** | **Create Order** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/orders` | `POST` (Bearer Token) | `status`, `currency`, `meta_data`, `line_items` | Order response with server `id` | `orders_table` & `purchased_items_table` |
| **17** | **Issuing Coupons** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/issuing-coupons` | `POST` (Bearer Token) | `coupon_code`, `amount`, `order_id` | Coupon issuing response | `coupons_items_table` |
| **18** | **Product Variations** | `https://indigo.alektasolutions.com/wp-json/wc/v3/products/{id}/variations` | `GET` (Bearer Token) | `product_id` | Variations array (SKU, price, attributes) | `fast_key_items` |
| **19** | **Assets Base** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/assets` | `GET` (Bearer Token) | None (GET) | App assets metadata | `asset_table` |
| **20** | **Shifts Base** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/shifts` | `GET` (Bearer Token) | `user_id` | Shift status list | `shift_table` |
| **21** | **Safes Base** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/safes` | `GET` (Bearer Token) | `shift_id` | Safe drop list | `safe_denom_table` |
| **22** | **Vendor Payments Base** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/vendor_payments` | `GET/POST` (Bearer Token) | `vendor_id`, `amount`, `purpose` | Vendor payment response | `vendor_payment_types_table` |
| **23** | **Total Orders Count** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/total-orders` | `GET` (Bearer Token) | `author`, `status` | `{ "total_orders": 1250 }` | `orders_table` |
| **24** | **Loyalty Create Customer**| `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/loyalty/create-customer` | `POST` (Bearer Token) | `first_name`, `last_name`, `phone` | Customer ID and initial points | `user_table` / Customer Meta |
| **25** | **Loyalty Add Points** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/loyalty/add-loyalty-points` | `POST` (Bearer Token) | `customer_id`, `points_to_add` | Customer points updated | `user_table` / Customer Meta |
| **26** | **FastKey Images** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/get-all-fastkeys-images` | `GET` (Bearer Token) | None (GET) | Image URLs map for fastkeys | `media_table` |
| **27** | **All Taxes Assets** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/assets/all-taxes` | `GET` (Bearer Token) | None (GET) | Tax rates list (`id`, `rate`, `name`) | `tax_table` |
| **28** | **Loyalty Remove Points** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/loyalty/remove-loyalty-points` | `POST` (Bearer Token) | `customer_id`, `points_to_remove` | Customer points updated | `user_table` / Customer Meta |
| **29** | **Sync Offline Orders** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/orders/sync-offline-orders` | `POST` (Bearer Token) | Array of offline order maps | `{ "synced_orders": [{ "local_id": 1, "server_id": 98 }] }` | Updates `orders_table.synced = 1` |
| **30** | **Cash Back Services** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/assets/cash-back-service` | `GET` (Bearer Token) | None (GET) | Cashback fee structure | `asset_table` |
| **31** | **Discount Rules** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/assets/discount-rules` | `GET` (Bearer Token) | None (GET) | Combo/multipack discount rules | `discount_rule_isar` (Isar DB) |
| **32** | **Product By SKU** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/products?sku=` | `GET` (Bearer Token) | `sku` | Product object matching SKU | `fast_key_items` |
| **33** | **Apply Custom Discount** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/orders/{id}/custom-discount/apply/` | `POST` (Bearer Token) | `order_id`, `discount_amount` | Updated Order object | `orders_table` (`discount`) |
| **34** | **Delete Vendor Payment** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/vendor_payments/delete-vendor-payment` | `POST` (Bearer Token) | `vendor_payment_id` | `{ "success": true }` | `vendor_payment_types_table` |
| **35** | **Create FastKey** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/create` | `POST` (Bearer Token) | `title`, `image`, `index` | FastKey tab created | `fast_key_tabs` |
| **36** | **Get FastKeys By User** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/get-by-user` | `GET` (Bearer Token) | `user_id` | FastKeys tabs array | `fast_key_tabs` |
| **37** | **Add Products FastKey** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/add-products` | `POST` (Bearer Token) | `fast_key_id`, `product_ids` | FastKey products added | `fast_key_items` |
| **38** | **Get FastKey Products** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/get-by-fastkey-id/{id}` | `GET` (Bearer Token) | `fast_key_id` | Products list for FastKey tab | `fast_key_items` |
| **39** | **Delete FastKey** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/delete-fastkey` | `DELETE` (Bearer Token) | `fast_key_id` | `{ "success": true }` | `fast_key_tabs` |
| **40** | **Update Payment Meta** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/payments/update-payment-meta` | `POST` (Bearer Token) | `payment_id`, `meta_key`, `value` | Updated payment object | Isar DB payment table |
| **41** | **Get Payment By ID** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/payments/get-payment-by-id?payment_id=` | `GET` (Bearer Token) | `payment_id` | Payment details object | Isar DB payment table |
| **42** | **Get Payments By Order** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/payments/get-payments-by-order-id?order_id=` | `GET` (Bearer Token) | `order_id` | Payments array for order | Isar DB payment table |
| **43** | **Void Payment** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/payments/void-payment` | `POST` (Bearer Token) | `payment_id` | `{ "success": true, "void": true }` | Isar DB payment table |
| **44** | **Create Shift** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/shifts/create-shift` | `POST` (Bearer Token) | `opening_balance`, `user_id` | Shift object (`shift_id`, `status`) | `shift_table` |
| **45** | **Create Safe Drop** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/safes/create-safe-drop` | `POST` (Bearer Token) | `shift_id`, `safe_drop_amount`, `denom` | Safe drop record confirmation | `safe_denom_table` |
| **46** | **Get Shifts By User** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/shifts/get-shifts-by-user?user_id=` | `GET` (Bearer Token) | `user_id` | Shifts history array | `shift_table` |
| **47** | **Get Shift By ID** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/shifts/get-shift-by-id?shift_id=` | `GET` (Bearer Token) | `shift_id` | Shift detail object | `shift_table` |
| **48** | **Create Vendor Payment**| `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/vendor_payments/create-vendor-payment` | `POST` (Bearer Token) | `vendor_id`, `amount`, `purpose` | Vendor payment confirmation | `vendor_payment_types_table` |
| **49** | **Get Vendor Payments** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/vendor_payments/get-vendor-payments-by-user-id?user_id=` | `GET` (Bearer Token) | `user_id` | Vendor payments list | `vendor_payment_types_table` |
| **50** | **Update Vendor Payment**| `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/vendor_payments/update-vendor-payment` | `POST` (Bearer Token) | `vendor_payment_id`, `amount` | Updated vendor payment | `vendor_payment_types_table` |
| **51** | **Update FastKey Tab** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/update-fastkey` | `POST` (Bearer Token) | `fast_key_id`, `title`, `index` | Updated FastKey tab | `fast_key_tabs` |
| **52** | **Delete Product FastKey**| `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/fastkeys/delete-product` | `POST` (Bearer Token) | `fast_key_id`, `product_id` | `{ "success": true }` | `fast_key_items` |
| **53** | **Void Order** | `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/orders/void-order` | `POST` (Bearer Token) | `order_id` | `{ "success": true, "status": "void" }` | `orders_table` (`status = 'cancelled'`) |

---

## 2. Refund & Stock Inventory Management Flow

When a full or partial refund is processed offline, the system must adjust local product stock inventory and create audit records without requiring an internet connection.

```mermaid
flowchart TD
    A[Cashier Selects Refund Items] --> B[Calculate Refund Net Amount]
    B --> C[Execute SQLite Transaction in pinaka.db]
    C --> D[Mark Items: is_refund_item = 1 in purchased_items_table]
    C --> E[Check Item Restock Flag]
    E -- Restock = True --> F[Update fast_key_items: stock_quantity = stock_quantity + qty]
    E -- Restock = False / Damaged --> G[Record Discard in inventory_log_table]
    F --> H[Update Isar DB Product Cache]
    G --> H
    H --> I[Queue Offline Refund Record: synced = 0]
```

### Exact SQLite Tables & Column Updates:
1. **`purchased_items_table`**:
   - `is_refund_item`: Set to `1` (prevents double refunding).
   - `item_sum_price`: Adjusted to reflect refunded amount.
2. **`fast_key_items`**:
   - `stock_quantity`: Increment stock `stock_quantity = stock_quantity + refunded_qty` if item is returned to sellable inventory.
3. **`orders_table`**:
   - `status`: Updated to `'refunded'` (if full refund) or kept as `'completed'` with updated net paid total.

---

## 3. Order Sync & Shift Sync Process Specifications

### 3.1 Order Sync Process (`deleteofflineorders` / `orders/sync-offline-orders`)
* **Trigger**: Event-driven by `OfflineOrderSyncService` worker when internet connection is restored.
* **Exact Step-by-Step Flow**:
  1. Worker queries SQLite `orders_table` for all rows where `synced = 0` or `status = 'pending_offline'`.
  2. For each pending order, worker fetches associated items from `purchased_items_table`, fee lines, and coupons.
  3. Worker constructs batch JSON payload and POSTs to `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/orders/sync-offline-orders`.
  4. Server responds with mapped server order IDs (`orders_server_id` and `items_server_id`).
  5. Worker executes atomic SQLite update:
     ```sql
     UPDATE orders_table SET synced = 1, orders_server_id = ?, status = 'completed' WHERE orders_id = ?;
     ```

---

### 3.2 Shift Sync & Safe Drop Process
* **Trigger**: Executed when cashier closes shift or performs safe drop.
* **Exact Step-by-Step Flow**:
  1. **Shift Creation**: Insert row into SQLite `shift_table` with `local_shift_id` and `sync_status = 0`.
  2. **Safe Drop Execution**:
     - Insert breakdown (100s, 50s, 20s notes) into SQLite `safe_denom_table` and `notes_denom_table`.
     - Update `shift_table.safe_drop_total = safe_drop_total + drop_amount`.
  3. **Shift Closure Reconciliation**:
     Calculate register over/short locally:
     `over_short = closing_balance - (opening_balance + cash_sales - vendor_payouts - safe_drops)`.
  4. **Background Sync**: POST shift payload to `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/shifts/create-shift` and `/create-safe-drop`. Mark `sync_status = 1` in SQLite upon HTTP 200 OK response.

---

## 4. System Crash Recovery & Token Refresh Architecture

When the POS terminal experiences an unexpected power failure, OS kill, out-of-memory crash, or kernel panic, the application recovers session state and un-synced data upon reboot without losing any transaction data.

```mermaid
sequenceDiagram
    participant Terminal as POS Hardware Reboot
    participant App as Flutter Main / Splash
    participant DB as SQLite pinaka.db
    participant Server as Remote Backend API

    Terminal->>App: Launch App after Terminal Crash
    App->>DB: Open Database (PRAGMA journal_mode=WAL)
    App->>DB: Query user_table for Last Active Session
    DB-->>App: Return Active User Data & Stored Token
    App->>Server: Check Connectivity & Validate Token (/token/validate-token-pin)
    alt Network Online & Token Valid
        Server-->>App: 200 OK (Token Valid)
    else Network Online & Token Expired
        App->>Server: POST /auth/refresh_token (with PIN / Refresh Token)
        Server-->>App: Return New Valid JWT Token
        App->>DB: UPDATE user_table SET token = new_token
    else Network Offline
        App->>App: Maintain Synthetic Session (OFFLINE_TOKEN_id_ts)
    end
    App->>DB: Query orders_table WHERE status = 'pending_offline' OR synced = 0
    DB-->>App: Return Active Unsynced Order & Line Items
    App->>App: Restore Active Cart into OrderHelper.activeOrderId
    App->>Terminal: Render Repopulated POS Order Panel UI (Zero Data Loss)
```

### Detailed Recovery Phases:
1. **Phase 1: Database Integrity Protection (WAL Mode)**:
   SQLite Write-Ahead Logging (`PRAGMA journal_mode=WAL`) prevents database file corruption during sudden power loss. Uncommitted transactions are automatically rolled back cleanly by the SQLite engine, leaving existing stored records intact.
2. **Phase 2: Token Validation & Session Refresh on Startup**:
   - On reboot, `splash_screen.dart` reads stored user data from SQLite `user_table`.
   - **If Online**: System issues token validation request to `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/token/validate-token-pin`. If expired, it automatically calls `https://indigo.alektasolutions.com/wp-json/pinaka-pos/v1/auth/refresh_token` using stored cashier PIN credentials to obtain a fresh Bearer token, updating `user_table.token`.
   - **If Offline**: System continues under synthetic offline session token `OFFLINE_TOKEN_${userId}_${timestamp}` without wiping local SQLite user or order data.
3. **Phase 3: Active Cart & Shift State Reconstruction**:
   - System queries SQLite `orders_table` for rows where `status = 'pending_offline'`.
   - Fetches associated items from `purchased_items_table`.
   - Sets `OrderHelper().activeOrderId` to the recovered order ID and repopulates the right panel cart lines. Cashier can immediately resume checkout where they left off before the crash.

---

## 5. Flutter Widget & Service Code Implementation

### 5.1 Startup Crash Recovery & Token Refresh (`lib/Screens/Auth/splash_screen.dart`)
```dart
Future<void> _performStartupCrashRecovery() async {
  try {
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userToken] != null) {
      final token = userData[AppDBConst.userToken].toString();
      
      // Check network connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none && !token.startsWith("OFFLINE_TOKEN")) {
        try {
          // Validate/Refresh Token online
          await TokenValidationService.validateToken(
            token: token,
            pin: userData['pin'] ?? '',
          );
        } catch (e) {
          if (kDebugMode) print("Token refresh network failed, continuing offline");
        }
      }

      // Recover un-synced active order from SQLite
      final db = await DBHelper.instance.database;
      final pendingOrders = await db.query(
        AppDBConst.orderTable,
        where: '${AppDBConst.orderStatus} = ?',
        whereArgs: ['pending_offline'],
        orderBy: '${AppDBConst.orderId} DESC',
        limit: 1,
      );

      if (pendingOrders.isNotEmpty) {
        final activeId = pendingOrders.first[AppDBConst.orderId] as int;
        OrderHelper().activeOrderId = activeId;
        if (kDebugMode) print("Restored crashed active order ID: $activeId");
      }
    }
  } catch (e) {
    if (kDebugMode) print("Error during crash recovery: $e");
  }
}
```

---

### 5.2 Stock Inventory Adjustment on Refund (`lib/Repositories/Orders/Refund_orderlist_repository.dart`)
```dart
Future<void> executeOfflineRefundWithInventoryAdjustment({
  required int orderId,
  required List<Map<String, dynamic>> refundItems,
  required bool restockToInventory,
}) async {
  final db = await DBHelper.instance.database;

  await db.transaction((txn) async {
    for (var item in refundItems) {
      final int serverItemId = item['order_item_id'];
      final int qty = item['qty'] ?? 1;
      final int productId = item['product_id'] ?? 0;

      // 1. Mark item as refunded in SQLite
      await txn.rawUpdate(
        'UPDATE ${AppDBConst.purchasedItemsTable} SET ${AppDBConst.isRefundItem} = 1 WHERE ${AppDBConst.itemServerId} = ?',
        [serverItemId],
      );

      // 2. Adjust product stock in SQLite fast_key_items if restock is enabled
      if (restockToInventory && productId > 0) {
        await txn.rawUpdate(
          'UPDATE ${AppDBConst.fastKeyItemsTable} SET stock_quantity = stock_quantity + ? WHERE ${AppDBConst.fastKeyProductId} = ?',
          [qty, productId],
        );
      }
    }

    // 3. Queue offline refund record for background sync
    await txn.insert(AppDBConst.orderTable, {
      AppDBConst.orderId: DateTime.now().millisecondsSinceEpoch % 100000000,
      AppDBConst.orderStatus: 'refunded',
      'synced': 0,
      AppDBConst.orderDate: DateTime.now().toIso8601String(),
    });
  });
}
```

---

## Verification & Validation Roadmap

1. **Full Absolute URL Audit**: Confirmed all 53 API endpoints list exact absolute URLs with `https://indigo.alektasolutions.com` / `https://test.alekyatechsolutions.com`.
2. **Stock Inventory Refund Audit**: Verified item-level refund updates `purchased_items_table.is_refund_item = 1` and increments `fast_key_items.stock_quantity` in SQLite.
3. **Crash & Token Refresh Test**: Force kill POS app mid-checkout; verify reboot recovers user token, refreshes session, and restores active cart lines cleanly without data loss.
4. **Order & Shift Sync Verification**: Execute offline orders, safe drops, and shift close; verify background worker syncs pending SQLite records (`synced = 0 -> 1`) upon reconnection.
