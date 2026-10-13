import 'dart:convert';

class SafeDropRequest { // Build #1.0.70 - Added by Naveen
<<<<<<< HEAD
  final List<SafeDropDenomination> safeDropDenominations;
  final num totalCash;
  final int totalNotes;
  final int shiftId;

  SafeDropRequest({
    required this.safeDropDenominations,
    required this.totalCash,
    required this.totalNotes,
=======
  final List<SafeDropDenomination> safeDenominations;
  final num coinsTotal;
  final num totalAmount;
  final String shiftId;

  SafeDropRequest({
    required this.safeDenominations,
    required this.coinsTotal,
    required this.totalAmount,
>>>>>>> origin/Grocery_pch_api_integration
    required this.shiftId,
  });

  Map<String, dynamic> toJson() {
    return {
<<<<<<< HEAD
      'safe_drop_denom': safeDropDenominations.map((e) => e.toJson()).toList(),
      'total_cash': totalCash.toString(),
      'total_notes': totalNotes,
=======
      'safe_denom': safeDenominations.map((e) => e.toJson()).toList(),
      'coins_total': coinsTotal,
      'total_amount': totalAmount,
>>>>>>> origin/Grocery_pch_api_integration
      'shift_id': shiftId,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SafeDropDenomination {
<<<<<<< HEAD
  final num denomination;
  final int denominationCount;
  final num total;

  SafeDropDenomination({
    required this.denomination,
    required this.denominationCount,
=======
  final num denom;
  final int tubeCount;
  final int cellCount;
  final num total;

  SafeDropDenomination({
    required this.denom,
    required this.tubeCount,
    required this.cellCount,
>>>>>>> origin/Grocery_pch_api_integration
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
<<<<<<< HEAD
      'denom': denomination.toString(),
      'denom_count': denominationCount,
      'total': total.toString(),
=======
      'denom': denom,
      'tube_count': tubeCount,
      'cell_count': cellCount,
      'total': total,
>>>>>>> origin/Grocery_pch_api_integration
    };
  }

  factory SafeDropDenomination.fromJson(Map<String, dynamic> json) {
    return SafeDropDenomination(
<<<<<<< HEAD
      denomination: num.parse(json['denom'].toString()),
      denominationCount: json['denom_count'] as int,
=======
      denom: num.parse(json['denom'].toString()),
      tubeCount: json['tube_count'] as int? ?? 0,
      cellCount: json['cell_count'] as int? ?? 0,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
    var dataList = json['data'] as List? ?? [];
=======
    final rawData = json['data'];
    final dataList = rawData is List ? rawData : const [];
>>>>>>> origin/Grocery_pch_api_integration
    List<SafeDropDenomination> denominations = dataList
        .map((item) => SafeDropDenomination.fromJson(item as Map<String, dynamic>))
        .toList();

    return SafeDropResponse(
      message: json['message'] as String? ?? 'Safe Drop created successfully',
<<<<<<< HEAD
      safeDropId: json['safe_drop_id'] as int? ?? 0,
=======
      safeDropId: (json['safe_id'] ?? json['safe_drop_id']) as int? ?? 0,
>>>>>>> origin/Grocery_pch_api_integration
      denominations: denominations,
    );
  }
}