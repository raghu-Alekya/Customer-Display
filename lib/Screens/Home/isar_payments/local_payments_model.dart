import 'package:isar/isar.dart';

part 'local_payments_model.g.dart';

enum PaymentDbStatus {
  successful,
  partial,
  receipt,
  voided,
}

@collection
class LocalPayment {
  /// Auto-increment primary key
  Id id = Isar.autoIncrement;

  /// Order info
  late int orderId;
  late String title;
  late double amount;
  late String paymentMethod;

  /// Shift / user info
  late int shiftId;
  late int vendorId;
  late int userId;

  /// Service info
  late String serviceType;
  late String datetime;
  late String notes;

  /// Payment tracking
  late double remainingBalance;
  late bool isSynced;

  /// ✅ Enum stored by Isar
  @enumerated
  late PaymentDbStatus status;

  /// Server / sync fields
  int? serverPaymentId;
  String? syncError;
  int? syncAttempts;

  /// Sunmi fields
  String? sunmiTxnId;
  String? sunmiOrderId;
  String? sunmiDeviceId;

  /// Timestamps
  late DateTime createdAt;
  DateTime? syncedAt;

  /// Constructor
  LocalPayment({
    required this.orderId,
    required this.title,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.vendorId,
    required this.userId,
    required this.serviceType,
    required this.datetime,
    required this.notes,
    required this.remainingBalance,
    required this.isSynced,
    required this.status,
    this.serverPaymentId,
    this.syncError,
    this.syncAttempts,
    this.sunmiTxnId,
    this.sunmiOrderId,
    this.sunmiDeviceId,
    required this.createdAt,
    this.syncedAt,
  });

  /// Debug helper
  @override
  String toString() {
    return '''
LocalPayment {
  id: $id,
  orderId: $orderId,
  title: "$title",
  amount: \$${amount.toStringAsFixed(2)},
  paymentMethod: "$paymentMethod",
  shiftId: $shiftId,
  vendorId: $vendorId,
  userId: $userId,
  serviceType: "$serviceType",
  datetime: "$datetime",
  notes: "$notes",
  remainingBalance: \$${remainingBalance.toStringAsFixed(2)},
  isSynced: $isSynced,
  status: ${status.name},
  serverPaymentId: $serverPaymentId,
  syncError: $syncError,
  syncAttempts: $syncAttempts,
  sunmiTxnId: $sunmiTxnId,
  sunmiOrderId: $sunmiOrderId,
  sunmiDeviceId: $sunmiDeviceId,
  createdAt: $createdAt,
  syncedAt: $syncedAt
}''';
  }
}