import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

// Model for Denomination
class Denomination extends Equatable {  //Build #1.0.74: Naveen Added
  final String denom;
  final int denomCount;
  final double total;

  const Denomination({
    required this.denom,
    required this.denomCount,
    required this.total,
  });

  factory Denomination.fromJson(Map<String, dynamic> json) {
    return Denomination(
      denom: json['denom']?.toString() ?? '',
      denomCount: (json['denom_count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'denom': denom,
    'denom_count': denomCount,
    'total': total,
  };

  @override
  List<Object?> get props => [denom, denomCount, total];
}

// Model for SafeDrop
class SafeDrop extends Equatable {
  final int id;
  final double total;
  final List<Denomination> denominations;
  final String note;
  final String time;

  const SafeDrop({
    required this.id,
    required this.total,
    required this.denominations,
    required this.note,
    required this.time,
  });

  factory SafeDrop.fromJson(Map<String, dynamic> json) {
    return SafeDrop(
      id: (json['id'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      denominations: (json['denominations'] as List<dynamic>?)
          ?.map((e) => Denomination.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      note: json['note']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'total': total,
    'denominations': denominations.map((e) => e.toJson()).toList(),
    'note': note,
    'time': time,
  };

  @override
  List<Object?> get props => [id, total, denominations, note, time];
}

// Model for VendorPayout
class VendorPayout extends Equatable {
  final int id;
  final double amount;
  final String note;
  final String paymentMethod;
  final String time;
  final String vendorName;
  final String serviceType;
  final String vendorId;

  const VendorPayout({
    required this.id,
    required this.amount,
    required this.note,
    required this.paymentMethod,
    required this.time,
    required this.vendorName,
    required this.serviceType,
    required this.vendorId,
  });

  factory VendorPayout.fromJson(Map<String, dynamic> json) {
    return VendorPayout(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'payment_method': paymentMethod,
    'time': time,
    'vendor_name': vendorName,
    'service_type': serviceType,
    'vendor_id': vendorId,
  };

  @override
  List<Object?> get props =>
      [id, amount, note, paymentMethod, time, vendorName, serviceType, vendorId];
}

// Model for Shift
class Shift extends Equatable {
  final int shiftId;
  final String title;
  final int userId;
  final String userName;
  final int assignedStaff;
  final String startTime;
  final String endTime;
  final int totalSales;
  final double totalSaleAmount;
  final double safeDropTotal;
  final List<SafeDrop> safeDrops;
  final List<VendorPayout> vendorPayouts;
  final double totalVendorPayments;
  final double openingBalance;
  final double closingBalance;
  final String notes;
  final String shiftClosingNotes;
  final String shiftStatus;
  final double overShort;

  const Shift({
    required this.shiftId,
    required this.title,
    required this.userId,
    required this.userName,
    required this.assignedStaff,
    required this.startTime,
    required this.endTime,
    required this.totalSales,
    required this.totalSaleAmount,
    required this.safeDropTotal,
    required this.safeDrops,
    required this.vendorPayouts,
    required this.totalVendorPayments,
    required this.openingBalance,
    required this.closingBalance,
    required this.notes,
    required this.shiftClosingNotes,
    required this.shiftStatus,
    required this.overShort,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing Shift JSON: $json');
    }
    return Shift(
      shiftId: (json['shift_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      userName: json['user_name']?.toString() ?? '',
      assignedStaff: (json['assigned_staff'] as num?)?.toInt() ?? 0,
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      totalSales: (json['total_sales'] as num?)?.toInt() ?? 0,
      totalSaleAmount: (json['total_sale_amount'] as num?)?.toDouble() ?? 0.0,
      safeDropTotal: (json['safe_drop_total'] as num?)?.toDouble() ?? 0.0,
      safeDrops: (json['safe_drops'] as List<dynamic>?)
          ?.map((e) => SafeDrop.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      vendorPayouts: (json['vendor_payouts'] as List<dynamic>?)
          ?.map((e) => VendorPayout.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalVendorPayments:
      (json['total_vendor_payments'] as num?)?.toDouble() ?? 0.0,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      shiftClosingNotes: json['shift_closing_notes']?.toString() ?? '',
      shiftStatus: json['shift_status']?.toString() ?? '',
      overShort: (json['over_short'] is String)
          ? double.tryParse(json['over_short']) ?? 0.0
          : (json['over_short'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'shift_id': shiftId,
    'title': title,
    'user_id': userId,
    'user_name': userName,
    'assigned_staff': assignedStaff,
    'start_time': startTime,
    'end_time': endTime,
    'total_sales': totalSales,
    'total_sale_amount': totalSaleAmount,
    'safe_drop_total': safeDropTotal,
    'safe_drops': safeDrops.map((e) => e.toJson()).toList(),
    'vendor_payouts': vendorPayouts.map((e) => e.toJson()).toList(),
    'total_vendor_payments': totalVendorPayments,
    'opening_balance': openingBalance,
    'closing_balance': closingBalance,
    'notes': notes,
    'shift_closing_notes': shiftClosingNotes,
    'shift_status': shiftStatus,
    'over_short': overShort,
  };

  @override
  List<Object?> get props => [
    shiftId,
    title,
    userId,
    userName,
    assignedStaff,
    startTime,
    endTime,
    totalSales,
    totalSaleAmount,
    safeDropTotal,
    safeDrops,
    vendorPayouts,
    totalVendorPayments,
    openingBalance,
    closingBalance,
    notes,
    shiftClosingNotes,
    shiftStatus,
    overShort,
  ];
}

// Response model for Get Shifts by User ID
class ShiftsByUserResponse extends Equatable {
  final List<Shift> shifts;

  const ShiftsByUserResponse({required this.shifts});

  factory ShiftsByUserResponse.fromJson(List<dynamic> json) {
    if (kDebugMode) {
      print('Parsing ShiftsByUserResponse JSON: $json');
    }
    return ShiftsByUserResponse(
      shifts: json.map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'shifts': shifts.map((e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => [shifts];
}

// Response model for Get Shift by ID
class ShiftByIdResponse extends Equatable {
  final Shift shift;

  const ShiftByIdResponse({required this.shift});

  factory ShiftByIdResponse.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing ShiftByIdResponse JSON: $json');
    }
    return ShiftByIdResponse(
      shift: Shift.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'shift': shift.toJson(),
  };

  @override
  List<Object?> get props => [shift];
}