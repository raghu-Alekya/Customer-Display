import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'local_payments_model.dart';

class LocalPaymentDBHelper {
  static LocalPaymentDBHelper? _instance;
  static Isar? _isar;

  LocalPaymentDBHelper._();

  static LocalPaymentDBHelper get instance {
    _instance ??= LocalPaymentDBHelper._();
    return _instance!;
  }

  Future<Isar> get isar async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [LocalPaymentSchema],
      directory: dir.path,
      name: 'local_payments',
    );

    if (kDebugMode) {
      print("✅ Isar initialized at: ${dir.path}");
    }

    return _isar!;
  }

  // ✅ Save payment with logging
  Future<LocalPayment> savePayment(LocalPayment payment) async {
    final db = await isar;

    await db.writeTxn(() async {
      payment.id = await db.collection<LocalPayment>().put(payment);
    });

    if (kDebugMode) {
      print("\n" + "=" * 60);
      print("💾 PAYMENT SAVED TO ISAR");
      print("=" * 60);
      print(payment.toString());
      print("=" * 60 + "\n");
    }

    return payment;
  }

  // ✅ Get payments by order ID
  Future<List<LocalPayment>> getPaymentsByOrderId(int orderId) async {
    final db = await isar;
    final payments = await db.collection<LocalPayment>()
        .filter()
        .orderIdEqualTo(orderId)
        .findAll();

    if (kDebugMode) {
      print("\n📊 PAYMENTS FOR ORDER #$orderId: ${payments.length}");
      for (var p in payments) {
        print("  → ID: ${p.id} | ${p.paymentMethod}: \$${p.amount.toStringAsFixed(2)} | Synced: ${p.isSynced}");
      }
      print("");
    }

    return payments;
  }

  // ✅ Get unsynced payments
  Future<List<LocalPayment>> getUnsyncedPayments() async {
    final db = await isar;
    final payments = await db.collection<LocalPayment>()
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (kDebugMode) {
      print("\n🔄 UNSYNCED PAYMENTS: ${payments.length}");
      for (var p in payments) {
        print("  → ID: ${p.id} | Order: #${p.orderId} | ${p.paymentMethod}: \$${p.amount.toStringAsFixed(2)} | Attempts: ${p.syncAttempts}");
      }
      print("");
    }

    return payments;
  }

  // ✅ Mark as synced
  Future<void> markAsSynced(int paymentId, int serverPaymentId) async {
    final db = await isar;

    await db.writeTxn(() async {
      final payment = await db.collection<LocalPayment>().get(paymentId);
      if (payment != null) {
        payment.isSynced = true;
        payment.serverPaymentId = serverPaymentId;
        payment.syncedAt = DateTime.now();
        payment.syncError = null;
        await db.collection<LocalPayment>().put(payment);

        if (kDebugMode) {
          print("\n✅ PAYMENT SYNCED");
          print("   Local ID: $paymentId → Server ID: $serverPaymentId");
          print("   Synced At: ${payment.syncedAt}\n");
        }
      }
    });
  }

  // ✅ Update sync error
  Future<void> updateSyncError(int paymentId, String error) async {
    final db = await isar;

    await db.writeTxn(() async {
      final payment = await db.collection<LocalPayment>().get(paymentId);
      if (payment != null) {
        payment.syncError = error;
        payment.syncAttempts = (payment.syncAttempts ?? 0) + 1;
        await db.collection<LocalPayment>().put(payment);

        if (kDebugMode) {
          print("\n⚠️ SYNC ERROR RECORDED");
          print("   Payment ID: $paymentId");
          print("   Error: $error");
          print("   Attempts: ${payment.syncAttempts}\n");
        }
      }
    });
  }

  // ✅ Delete payment
  Future<bool> deletePayment(int paymentId) async {
    final db = await isar;
    bool deleted = false;

    await db.writeTxn(() async {
      deleted = await db.collection<LocalPayment>().delete(paymentId);
    });

    if (kDebugMode) {
      print(deleted ? "✅ Payment $paymentId deleted" : "⚠️ Payment $paymentId not found");
    }

    return deleted;
  }

  // ✅ Get last payment for order
  Future<LocalPayment?> getLastPaymentForOrder(int orderId) async {
    final db = await isar;
    final payments = await db.collection<LocalPayment>()
        .filter()
        .orderIdEqualTo(orderId)
        .findAll();

    if (payments.isEmpty) return null;

    // Sort by createdAt and get last
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final payment = payments.first;

    if (kDebugMode) {
      print("\n🔍 LAST PAYMENT FOR ORDER #$orderId:");
      print(payment.toString());
      print("");
    }

    return payment;
  }

  // ✅ Calculate total paid
  Future<double> getTotalPaidForOrder(int orderId) async {
    final payments = await getPaymentsByOrderId(orderId);
    final total = payments.fold(0.0, (sum, p) => sum + p.amount);

    if (kDebugMode) {
      print("💰 Total Paid for Order #$orderId: \$${total.toStringAsFixed(2)}");
    }

    return total;
  }

  // ✅ Print all payments in database
  Future<void> printAllPayments() async {
    final db = await isar;
    final allPayments = await db.collection<LocalPayment>().where().findAll();

    if (!kDebugMode) return;

    print("\n" + "=" * 60);
    print("📊 ALL PAYMENTS IN DATABASE: ${allPayments.length}");
    print("=" * 60);

    if (allPayments.isEmpty) {
      print("(Database is empty)");
    } else {
      for (var p in allPayments) {
        print("\n${p.isSynced ? '✅' : '⏳'} Payment ID: ${p.id}");
        print("   Order: #${p.orderId}");
        print("   Method: ${p.paymentMethod}");
        print("   Amount: \$${p.amount.toStringAsFixed(2)}");
        print("   Created: ${p.createdAt}");

        if (p.isSynced) {
          print("   Server ID: ${p.serverPaymentId}");
          print("   Synced: ${p.syncedAt}");
        } else {
          print("   Attempts: ${p.syncAttempts}");
          if (p.syncError != null) {
            print("   Error: ${p.syncError}");
          }
        }
      }
    }

    print("=" * 60 + "\n");
  }
}