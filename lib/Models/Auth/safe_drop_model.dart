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

  /// Body for POST .../pos/safe-drops/create-safe-drop:
  /// { shift_id, safe_drop_denom: [{denom, denom_count, total}],
  ///   total_cash, total_notes }. Only denominations with a count are sent.
  Map<String, dynamic> toJson() {
    final counted = safeDenominations.where((e) => e.tubeCount > 0).toList();
    return {
      'shift_id': shiftId,
      'safe_drop_denom': counted
          .map((e) => {
        'denom': e.denom,
        'denom_count': e.tubeCount,
        'total': e.total,
      })
          .toList(),
      'total_cash': totalAmount,
      'total_notes': counted.fold<int>(0, (sum, e) => sum + e.tubeCount),
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

    // Ids may come back as numbers or strings; don't fail the drop on that
    final data = rawData is Map ? rawData : const {};
    final rawId = json['safe_drop_id'] ??
        json['safeDropId'] ??
        json['safe_id'] ??
        json['id'] ??
        data['safe_drop_id'] ??
        data['safeDropId'] ??
        data['id'];
    return SafeDropResponse(
      message: json['message']?.toString() ?? 'Safe Drop created successfully',
      safeDropId: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      denominations: denominations,
    );
  }
}