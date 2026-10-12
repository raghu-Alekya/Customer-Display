import 'dart:convert';

class SafeDropRequest { // Build #1.0.70 - Added by Naveen
  final List<SafeDropDenomination> safeDenominations;
  final num coinsTotal;
  final num totalAmount;
  final String shiftId;

  SafeDropRequest({
    required this.safeDenominations,
    required this.coinsTotal,
    required this.totalAmount,
    required this.shiftId,
  });

  Map<String, dynamic> toJson() {
    return {
      'safe_denom': safeDenominations.map((e) => e.toJson()).toList(),
      'coins_total': coinsTotal,
      'total_amount': totalAmount,
      'shift_id': shiftId,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SafeDropDenomination {
  final num denom;
  final int tubeCount;
  final int cellCount;
  final num total;

  SafeDropDenomination({
    required this.denom,
    required this.tubeCount,
    required this.cellCount,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'denom': denom,
      'tube_count': tubeCount,
      'cell_count': cellCount,
      'total': total,
    };
  }

  factory SafeDropDenomination.fromJson(Map<String, dynamic> json) {
    return SafeDropDenomination(
      denom: num.parse(json['denom'].toString()),
      tubeCount: json['tube_count'] as int? ?? 0,
      cellCount: json['cell_count'] as int? ?? 0,
      total: num.parse(json['total'].toString()),
    );
  }
}

class SafeDropResponse {
  final String message;
  final int safeDropId;
  final List<SafeDropDenomination> denominations;

  SafeDropResponse({
    required this.message,
    required this.safeDropId,
    required this.denominations,
  });

  factory SafeDropResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final dataList = rawData is List ? rawData : const [];
    List<SafeDropDenomination> denominations = dataList
        .map((item) => SafeDropDenomination.fromJson(item as Map<String, dynamic>))
        .toList();

    return SafeDropResponse(
      message: json['message'] as String? ?? 'Safe Drop created successfully',
      safeDropId: (json['safe_id'] ?? json['safe_drop_id']) as int? ?? 0,
      denominations: denominations,
    );
  }
}