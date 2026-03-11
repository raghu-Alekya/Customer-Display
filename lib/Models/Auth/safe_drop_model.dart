import 'dart:convert';

class SafeDropRequest { // Build #1.0.70 - Added by Naveen
  final List<SafeDropDenomination> safeDropDenominations;
  final num totalCash;
  final int totalNotes;
  final int shiftId;

  SafeDropRequest({
    required this.safeDropDenominations,
    required this.totalCash,
    required this.totalNotes,
    required this.shiftId,
  });

  Map<String, dynamic> toJson() {
    return {
      'safe_drop_denom': safeDropDenominations.map((e) => e.toJson()).toList(),
      'total_cash': totalCash.toString(),
      'total_notes': totalNotes,
      'shift_id': shiftId,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SafeDropDenomination {
  final num denomination;
  final int denominationCount;
  final num total;

  SafeDropDenomination({
    required this.denomination,
    required this.denominationCount,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'denom': denomination.toString(),
      'denom_count': denominationCount,
      'total': total.toString(),
    };
  }

  factory SafeDropDenomination.fromJson(Map<String, dynamic> json) {
    return SafeDropDenomination(
      denomination: num.parse(json['denom'].toString()),
      denominationCount: json['denom_count'] as int,
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
    var dataList = json['data'] as List? ?? [];
    List<SafeDropDenomination> denominations = dataList
        .map((item) => SafeDropDenomination.fromJson(item as Map<String, dynamic>))
        .toList();

    return SafeDropResponse(
      message: json['message'] as String? ?? 'Safe Drop created successfully',
      safeDropId: json['safe_drop_id'] as int? ?? 0,
      denominations: denominations,
    );
  }
}