import 'package:isar/isar.dart';

part 'local_payments_model.g.dart';


@collection
class LocalPayment {
  Id id = DateTime.now().microsecondsSinceEpoch;

  // Id id = Isar.autoIncrement;

  @Index()
  late int orderId;

  late String title;
  late double amount;
  late String paymentMethod;
  late int shiftId;
  late int vendorId;
  late int userId;
  late String serviceType;
  late String datetime;
  late String notes;

  // Sync status
  late bool isSynced;
  int? serverPaymentId;
  String? syncError;
  int? syncAttempts;

  // Sunmi card payment fields
  String? sunmiTxnId;
  String? sunmiOrderId;
  String? sunmiDeviceId;

  late DateTime createdAt;
 DateTime? syncedAt;

  LocalPayment({
    required this.title,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.vendorId,
    required this.userId,
    required this.serviceType,
    required this.datetime,
    required this.notes,
    this.isSynced = false,
    this.serverPaymentId,
    this.syncError,
    this.syncAttempts = 0,
    this.sunmiTxnId,
    this.sunmiOrderId,
    this.sunmiDeviceId,
    DateTime? createdAt,
    this.syncedAt,
  }) : createdAt = createdAt ?? DateTime.now()
   ;

  // For console logging
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
  isSynced: $isSynced,
  serverPaymentId: $serverPaymentId,
  syncError: ${syncError != null ? '"$syncError"' : 'null'},
  syncAttempts: $syncAttempts,
  sunmiTxnId: ${sunmiTxnId != null ? '"$sunmiTxnId"' : 'null'},
  sunmiOrderId: ${sunmiOrderId != null ? '"$sunmiOrderId"' : 'null'},
  sunmiDeviceId: ${sunmiDeviceId != null ? '"$sunmiDeviceId"' : 'null'},
  createdAt: $createdAt,
  syncedAt: $syncedAt
}''';
  }
}