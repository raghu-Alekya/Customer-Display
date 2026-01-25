
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Database/discount_rule_isar.dart';

class AppDB {
  static late Isar isar;
}
Future<void> seedDiscountRules(Isar isar) async {
  await isar.writeTxn(() async {

    // 🔥 CLEAR OLD RULES (IMPORTANT)
    await isar.discountRuleIsars.clear();

    // =================================================
    // 🔹 AUTO DISCOUNT – single product
    // Buy 3 of 9402 for $8
    // =================================================
    await isar.discountRuleIsars.put(
      DiscountRuleIsar()
        ..ruleId = 'AUTO_9402'
        ..productIds = [8545]
        ..requiredQty = 1
        ..bundlePrice = 2.0
        ..ruleType = 'auto'
        ..active = true,
    );

    // =================================================
    // 🔹 MULTIPACK – single product
    // Buy 2 of 9120 for $7.50
    // =================================================
    await isar.discountRuleIsars.put(
      DiscountRuleIsar()
        ..ruleId = 'MP_9120'
        ..productIds = [8339]
        ..requiredQty = 2
        ..bundlePrice = 15.0
        ..ruleType = 'multipack'
        ..active = true,
    );

    // =================================================
    // 🔹 OPTIONAL: LARGE MIXMATCH (3 items)
    // Any 3 of (9402, 9120, 9435) for $10
    // =================================================
    await isar.discountRuleIsars.put(
      DiscountRuleIsar()
        ..ruleId = 'MM_STATIC_01'
        ..productIds = [9402, 9120, 9435]
        ..requiredQty = 3
        ..bundlePrice = 10.0
        ..ruleType = 'mixmatch'
        ..active = true,
    );
  });
}



class EngineDiscountResult {
  final double amount;
  final String ruleType;
  final String ruleId;

  EngineDiscountResult(this.amount, this.ruleType, this.ruleId);
}

int toCents(double v) => (v * 100).round();
double fromCents(int c) => c / 100.0;

class _Unit {
  final int pid;
  final int priceCents;
  bool used = false;

  _Unit(this.pid, this.priceCents);
}

class DiscountEngine {


  static Future<Map<int, EngineDiscountResult>> applyAll(
      Isar isar,
      List<Map<String, dynamic>> cart,
      ) async {

    final List<_Unit> units = [];

    int _priority(String? type) {
      switch (type) {
        case 'auto':
          return 1;
        case 'multipack':
          return 2;
        case 'mixmatch':
          return 3;
        default:
          return 99;
      }
    }


    for (final item in cart) {
      final pid = int.parse(item['product_id'].toString());
      final qty = int.parse(item['qty'].toString());
      final price = toCents(
        double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
      );

      for (int i = 0; i < qty; i++) {
        units.add(_Unit(pid, price));
      }
    }

    units.sort((a, b) => b.priceCents.compareTo(a.priceCents));

    final rules = (await isar.discountRuleIsars
        .filter()
        .activeEqualTo(true)
        .findAll())
      ..sort((a, b) => _priority(a.ruleType)
          .compareTo(_priority(b.ruleType)));

    final Map<int, EngineDiscountResult> result = {};

    for (final rule in rules) {
      final String? ruleType = rule.ruleType;

      final eligible = units
          .where((u) => !u.used && rule.productIds.contains(u.pid))
          .toList();

      if (eligible.length < rule.requiredQty) continue;

      List<_Unit> bundle;

      // AUTO & MULTIPACK → same product only
      if (ruleType != 'mixmatch') {
        final samePid =
        eligible.where((u) => u.pid == eligible.first.pid).toList();

        if (samePid.length < rule.requiredQty) continue;
        bundle = samePid.take(rule.requiredQty).toList();
      } else {
        // MIXMATCH
        bundle = eligible.take(rule.requiredQty).toList();
      }

      final subtotal =
      bundle.fold(0, (s, u) => s + u.priceCents);
      final discount =
          subtotal - toCents(rule.bundlePrice);

      if (discount <= 0) continue;

      for (final u in bundle) {
        u.used = true;
      }

      final pid = bundle.first.pid;

      if (ruleType == null) {
        print("⚠️ SKIPPING RULE WITH NULL TYPE → ${rule.ruleId}");
        continue;
      }

      result[pid] = EngineDiscountResult(
        fromCents(discount),
        ruleType, // ✅ now String
        rule.ruleId,
      );


      print(
        "🎯 ENGINE APPLY → rule=${rule.ruleId} | "
            "type=$ruleType | discount=${fromCents(discount)}",
      );
    }

    return result;
  }



}
