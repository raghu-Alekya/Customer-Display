import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

// Model for Denomination
class Denomination extends Equatable {
  //Build #1.0.74: Naveen Added
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

  /// From the PCH get-all-safe-drops API. Accepts snake_case or camelCase
  /// and numbers sent as strings ("30.00").
  factory SafeDrop.fromApi(Map<String, dynamic> json) {
    num? readNum(Map map, List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value;
        final parsed = num.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      return null;
    }

    final rawDenoms = json['safe_denom'] ??
        json['safeDenom'] ??
        json['safe_denominations'] ??
        json['safeDenominations'] ??
        json['denominations'];
    return SafeDrop(
      id: readNum(json, const ['id', 'safe_id', 'safeId', 'safe_drop_id', 'safeDropId'])
          ?.toInt() ??
          0,
      total: readNum(json, const ['total_amount', 'totalAmount', 'total', 'amount'])
          ?.toDouble() ??
          0.0,
      denominations: rawDenoms is List
          ? rawDenoms.whereType<Map>().map((d) {
        final denom = Map<String, dynamic>.from(d);
        return Denomination(
          denom: (denom['denom'] ?? denom['denomination'])?.toString() ?? '',
          denomCount: readNum(denom, const [
            'tube_count',
            'tubeCount',
            'denom_count',
            'denomCount',
            'count',
          ])?.toInt() ??
              0,
          total: readNum(denom, const ['total', 'amount'])?.toDouble() ?? 0.0,
        );
      }).toList()
          : const [],
      note: (json['note'] ?? json['notes'] ?? json['safe_drop_note'] ?? '')
          .toString(),
      time: (json['createdAt'] ??
          json['created_at'] ??
          json['droppedAt'] ??
          json['dropped_at'] ??
          json['time'] ??
          json['date'] ??
          '')
          .toString(),
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
  List<Object?> get props => [
    id,
    amount,
    note,
    paymentMethod,
    time,
    vendorName,
    serviceType,
    vendorId
  ];
}

// Model for Shift
class Shift extends Equatable {
  static double _readAmount(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value != null) {
        final parsed = double.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return '';
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

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
  final double tillAmount;

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
    required this.tillAmount,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing Shift JSON: $json');
    }
    final reportedSalesAmount = _readAmount(
      json,
      ['total_sale_amount', 'totalSaleAmount', 'sales_amount', 'salesAmount'],
    );
    final cashSales = _readAmount(
      json,
      ['total_cash_sales', 'totalCashSales', 'cash_sales', 'cashSales'],
    );
    final cardSales = _readAmount(
      json,
      ['total_card_sales', 'totalCardSales', 'card_sales', 'cardSales'],
    );
    final hasCashOrCardSales = [
      'total_cash_sales',
      'totalCashSales',
      'cash_sales',
      'cashSales',
      'total_card_sales',
      'totalCardSales',
      'card_sales',
      'cardSales',
    ].any(json.containsKey);
    final salesAmount = reportedSalesAmount != 0 || !hasCashOrCardSales
        ? reportedSalesAmount
        : cashSales + cardSales;

    // Old shifts API is snake_case with numeric ids; /pos/shifts/employee
    // returns camelCase with string ids like "SHIFT-...".
    return Shift(
      shiftId: _readInt(json, ['shift_id', 'shiftId', 'id']),
      title: _readString(json, ['title', 'shift_id', 'shiftId', 'id']),
      userId: _readInt(json, ['user_id', 'userId']),
      userName: _readString(
          json, ['user_name', 'userName', 'cashier_name', 'cashierName']),
      assignedStaff: _readInt(json, ['assigned_staff', 'assignedStaff']),
      startTime: _readString(json,
          ['start_time', 'startTime', 'opened_at', 'openedAt', 'createdAt']),
      endTime:
      _readString(json, ['end_time', 'endTime', 'closed_at', 'closedAt']),
      totalSales: _readInt(json, ['total_sales', 'totalSales']),
      totalSaleAmount: salesAmount,
      safeDropTotal: _readAmount(json,
          ['safe_drop_total', 'safeDropTotal', 'total_safe_drops', 'totalSafeDrops']),
      safeDrops: (json['safe_drops'] as List<dynamic>?)
          ?.map((e) => SafeDrop.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      vendorPayouts: (json['vendor_payouts'] as List<dynamic>?)
          ?.map((e) => VendorPayout.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalVendorPayments: _readAmount(json, [
        'total_vendor_payments',
        'totalVendorPayments',
        'total_paid_outs',
        'totalPaidOuts',
      ]),
      openingBalance: _readAmount(json,
          ['opening_balance', 'openingBalance', 'opening_cash', 'openingCash']),
      closingBalance: _readAmount(json, [
        'closing_balance',
        'closingBalance',
        'closing_cash_actual',
        'closingCashActual',
      ]),
      notes: _readString(json, ['notes']),
      shiftClosingNotes:
      _readString(json, ['shift_closing_notes', 'shiftClosingNotes']),
      shiftStatus: _readString(json, ['shift_status', 'shiftStatus', 'status']),
      tillAmount: _readAmount(json, ['till_amount', 'tillAmount']),
      overShort: _readAmount(json,
          ['over_short', 'overShort', 'cash_difference', 'cashDifference', 'discrepancy']),
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
    'till_amount': tillAmount,
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

  factory ShiftsByUserResponse.fromJson(dynamic json) {
    dynamic rawShifts;
    if (json is List) {
      rawShifts = json;
    } else if (json is Map) {
      final data = json['data'];
      rawShifts = json['shifts'] ??
          (data is List ? data : null) ??
          (data is Map ? data['shifts'] : null);
    }
    if (rawShifts is! List) {
      throw const FormatException(
        'Expected shift history to be a list or contain a shifts list.',
      );
    }
    if (kDebugMode) {
      print('Parsing ShiftsByUserResponse with ${rawShifts.length} shifts');
    }
    return ShiftsByUserResponse(
      shifts: rawShifts
          .map((e) => Shift.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
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