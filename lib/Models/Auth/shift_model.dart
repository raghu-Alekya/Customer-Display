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
    return {
      'denomination': denomination.toString(),
      'denom_count': denomCount,
    };
  }

  factory Denomination.fromJson(Map<String, dynamic> json) {
    return Denomination(
      denomination: num.parse(json['denomination'].toString()),
      denomCount: json['denom_count'] as int,
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
  final String userName;
  final num totalAmount;  //Build #1.0.74
  final num overShort;
  final String status;

  ShiftResponse({
    required this.shiftId,
    required this.userName,
    required this.totalAmount,
    required this.overShort,
    required this.status,
  });

  factory ShiftResponse.fromJson(Map<String, dynamic> json) {
    return ShiftResponse(
      shiftId: json['shift_id'] as int,
      userName: json['user'] as String,
      totalAmount: num.parse(json['total_amount'].toString()),
      overShort: num.parse(json['over_short'].toString()),
      status: json['status'] as String,
    );
  }
}