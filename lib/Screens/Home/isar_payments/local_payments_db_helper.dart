import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../../../Constants/text.dart';
import 'local_payments_model.dart';

class LocalPaymentDBHelper {
  static LocalPaymentDBHelper? _instance;
  static Isar? _isar;

  LocalPaymentDBHelper._();

  static LocalPaymentDBHelper get instance {
    _instance ??= LocalPaymentDBHelper._();
    return _instance!;
  }


  // ✅ Get all payments in database
  Future<List<LocalPayment>> getAllPayments() async {
    final db = await isar;
    final allPayments = await db.collection<LocalPayment>().where().findAll();

    if (kDebugMode) {
      print("\n📊 ALL PAYMENTS FETCHED: ${allPayments.length}");
    }

    return allPayments;
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
      print(" Isar initialized at: ${dir.path}");
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

  // ✅ Get payment status summary for an order
  Future<Map<String, dynamic>> getPaymentStatusSummary(int orderId) async {
    if (orderId == 0) {
      return {
        'hasPayments': false,
        'isFullyPaid': false,
        'status': TextConstants.processing,
        'remainingBalance': 0.0,
      };
    }

    try {
      final payments = await getPaymentsByOrderId(orderId);

      if (payments.isEmpty) {
        return {
          'hasPayments': false,
          'isFullyPaid': false,
          'status': TextConstants.processing,
          'remainingBalance': 0.0,
        };
      }

      // Sort by createdAt descending (newest first)
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final lastPayment = payments.first;

      final bool isFullyPaid = lastPayment.remainingBalance <= 0;
      final String status = isFullyPaid ? TextConstants.processing : TextConstants.pending;

      if (kDebugMode) {
        print("\n" + "📋" * 30);
        print("PAYMENT STATUS SUMMARY FOR ORDER #$orderId");
        print("📋" * 30);
        print("   Has Payments: true");
        print("   Total Payments: ${payments.length}");
        print("   Fully Paid: $isFullyPaid");
        print("   Order Status: $status");
        print("   Last Payment Status: ${lastPayment.status?.name ?? 'null'}");
        print("   Remaining Balance: \$${lastPayment.remainingBalance.toStringAsFixed(2)}");
        print("📋" * 30 + "\n");
      }

      return {
        'hasPayments': true,
        'isFullyPaid': isFullyPaid,
        'status': status,
        'lastPaymentStatus': lastPayment.status?.name ?? 'pending',
        'remainingBalance': lastPayment.remainingBalance,
        'totalPayments': payments.length,
      };

    } catch (e) {
      if (kDebugMode) print("❌ Error getting payment status: $e");
      return {
        'hasPayments': false,
        'isFullyPaid': false,
        'status': TextConstants.processing,
        'remainingBalance': 0.0,
      };
    }
  }

  // ✅ Get payments by order ID
  // Future<List<LocalPayment>> getPaymentsByOrderId(int orderId) async {
  //   final db = await isar;
  //   final payments = await db.collection<LocalPayment>()
  //       .filter()
  //       .orderIdEqualTo(orderId)
  //       .findAll();
  //
  //   if (kDebugMode) {
  //     print("\n📊 PAYMENTS FOR ORDER #$orderId: ${payments.length}");
  //     for (var p in payments) {
  //       print("  → ID: ${p.id} | Order ID: ${p.orderId} | ${p.paymentMethod}: \$${p.amount.toStringAsFixed(2)} | Synced: ${p.isSynced} | Status: ${p.status?.name ?? 'null'}");
  //     }
  //     print("");
  //   }
  //
  //   return payments;
  // }

// In LocalPaymentDBHelper class:
  Future<List<LocalPayment>> getPaymentsByOrderId(int orderId) async {
    try {
      final isar = await this.isar;

      // Get ALL payments
      final allPayments = await isar.collection<LocalPayment>().where().findAll();

      // Filter manually by orderId
      final filtered = allPayments.where((p) => p.orderId == orderId).toList();

      return filtered;
    } catch (e) {
      print("❌ Error getting payments by order ID: $e");
      return [];
    }
  }

  // ✅ Get current balance for order
  Future<double?> getCurrentBalanceForOrder(int orderId) async {
    final db = await isar;
    final payments = await db.collection<LocalPayment>()
        .filter()
        .orderIdEqualTo(orderId)
        .findAll();

    if (payments.isEmpty) return null;

    // Sort by createdAt and get last
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lastPayment = payments.first;

    if (kDebugMode) {
      print("\n💰 CURRENT BALANCE FOR ORDER #$orderId:");
      print("   Last Payment: \$${lastPayment.amount.toStringAsFixed(2)}");
      print("   Remaining: \$${lastPayment.remainingBalance.toStringAsFixed(2)}");
      print("   Status: ${lastPayment.status?.name ?? 'null'}");
      print("");
    }

    return lastPayment.remainingBalance;
  }

  // ✅ Get payment summary for order
  Future<Map<String, double>> getPaymentSummaryForOrder(int orderId) async {
    final payments = await getPaymentsByOrderId(orderId);

    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    // Sort by createdAt descending (newest first) so we get the current remaining balance
    // from the most recent payment, not an arbitrary payment
    if (payments.isNotEmpty) {
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final remainingBalance =
        payments.isEmpty ? null : payments.first.remainingBalance;

    return {
      'totalPaid': totalPaid,
      'remainingBalance': remainingBalance ?? 0.0,
      'paymentCount': payments.length.toDouble(),
    };
  }

  // Get unsynced payments
  Future<List<LocalPayment>> getUnsyncedPayments() async {
    final db = await isar;
    final payments = await db.collection<LocalPayment>()
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (kDebugMode) {
      print("\n⏳ UNSYNCED PAYMENTS: ${payments.length}");
      for (var p in payments) {
        print("  → ID: ${p.id} | Order: #${p.orderId} | ${p.paymentMethod}: \$${p.amount.toStringAsFixed(2)} | Attempts: ${p.syncAttempts}");
      }
      print("");
    }

    return payments;
  }

  // Mark as synced
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
        print("   Remaining Balance: \$${p.remainingBalance.toStringAsFixed(2)}");
        print("   Status: ${p.status?.name ?? 'null'}");
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

  // ✅ Clear all payments for an order (useful for testing/debugging)
  Future<void> clearPaymentsForOrder(int orderId) async {
    final db = await isar;

    await db.writeTxn(() async {
      final payments = await db.collection<LocalPayment>()
          .filter()
          .orderIdEqualTo(orderId)
          .findAll();

      for (var payment in payments) {
        await db.collection<LocalPayment>().delete(payment.id);
      }

      if (kDebugMode) {
        print("🗑️ Cleared ${payments.length} payments for order #$orderId");
      }
    });
  }

  ///

// ✅ Get single payment by order ID (returns first/only one)
  Future<LocalPayment?> getPaymentByOrderId(int orderId) async {
    final db = await isar;
    final payment = await db.collection<LocalPayment>()
        .filter()
        .orderIdEqualTo(orderId)
        .findFirst();  // ← Get only ONE

    if (kDebugMode && payment != null) {
      print("\n🔍 FOUND EXISTING PAYMENT FOR ORDER #$orderId:");
      print("   Payment ID: ${payment.id}");
      print("   Amount: \$${payment.amount.toStringAsFixed(2)}");
      print("   Status: ${payment.status?.name}");
      print("");
    }

    return payment;
  }

// ✅ Update existing payment
  Future<LocalPayment> updatePayment(LocalPayment payment) async {
    final db = await isar;

    await db.writeTxn(() async {
      await db.collection<LocalPayment>().put(payment);
    });

    if (kDebugMode) {
      print("\n" + "=" * 60);
      print("🔄 PAYMENT UPDATED IN ISAR");
      print("=" * 60);
      print(payment.toString());
      print("=" * 60 + "\n");
    }

    return payment;
  }

}