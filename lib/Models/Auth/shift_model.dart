import 'dart:convert';

class ShiftRequest { // Build #1.0.70 - Added by Naveen
  final int? shiftId; // Optional for create shift
  final String? status; // Optional: open, closed
  final List<Denomination> drawerDenominations;
  final num drawerTotalAmount;
  final List<TubeDenomination> tubeDenominations;
  final num tubeTotalAmount;
  final num totalAmount;

  ShiftRequest({
    this.shiftId,
    this.status,
    required this.drawerDenominations,
    required this.drawerTotalAmount,
    required this.tubeDenominations,
    required this.tubeTotalAmount,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    final json = {
      if (shiftId != null) 'shift_id': shiftId,
      if (status != null) 'status': status,
      'drawer_denominations': drawerDenominations.map((e) => e.toJson()).toList(),
      'drawer_total_amount': drawerTotalAmount.toString(),
      'tube_denominations': tubeDenominations.map((e) => e.toJson()).toList(),
      'tube_total_amount': tubeTotalAmount.toString(),
      'total_amount': totalAmount.toString(),
    };
    return json;
  }

  String toJsonString() => jsonEncode(toJson());
}

class Denomination {
  final num denomination;
  final int denomCount;

  Denomination({
    required this.denomination,
    required this.denomCount,
  });

  Map<String, dynamic> toJson() {
    // API requires positive numeric denomination + non-negative int denom_count
    // (string values fail validation: "must contain positive denominations...")
    final denomNum = denomination is int
        ? denomination
        : (denomination == denomination.roundToDouble()
        ? denomination.toInt()
        : denomination.toDouble());
    return {
      'denomination': denomNum,
      'denom_count': denomCount,
    };
  }

  factory Denomination.fromJson(Map<String, dynamic> json) {
    return Denomination(
      denomination: num.parse(json['denomination'].toString()),
      denomCount: int.tryParse(json['denom_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class TubeDenomination {
  final num denomination;
  final int tubeCount;
  final int cellCount;
  final num total;

  TubeDenomination({
    required this.denomination,
    required this.tubeCount,
    required this.cellCount,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'denomination': denomination.toString(),
      'tube_count': tubeCount,
      'cell_count': cellCount,
      'total': total.toString(),
    };
  }

  factory TubeDenomination.fromJson(Map<String, dynamic> json) {
    return TubeDenomination(
      denomination: num.parse(json['denomination'].toString()),
      tubeCount: json['tube_count'] as int,
      cellCount: json['cell_count'] as int,
      total: num.parse(json['total'].toString()),
    );
  }
}

class ShiftResponse {
  final int shiftId;
  final String? externalShiftId;
  final String userName;
  final num totalAmount; //Build #1.0.74
  final num overShort;
  final String status;

  ShiftResponse({
    required this.shiftId,
    this.externalShiftId,
    required this.userName,
    required this.totalAmount,
    required this.overShort,
    required this.status,
  });

  factory ShiftResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : Map<String, dynamic>.from(json);
    final idRaw = data['shift_id'] ?? data['id'] ?? json['shift_id'];
    int shiftId = 0;
    if (idRaw is int) {
      shiftId = idRaw;
    } else if (idRaw != null) {
      shiftId = int.tryParse(idRaw.toString()) ??
          idRaw.toString().hashCode.abs() % 1000000000;
    }
    return ShiftResponse(
      shiftId: shiftId,
      externalShiftId: idRaw?.toString(),
      userName: (data['user'] ?? data['cashier_name'] ?? 'Cashier').toString(),
      totalAmount: num.tryParse(
          (data['total_amount'] ?? data['opening_cash'] ?? 0).toString()) ??
          0,
      overShort: num.tryParse((data['over_short'] ?? 0).toString()) ?? 0,
      status: (data['status'] ?? 'open').toString(),
    );
  }
}