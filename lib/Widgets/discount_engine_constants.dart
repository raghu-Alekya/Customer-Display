
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Database/discount_rule_isar.dart';

import '../Repositories/Orders/order_repository.dart';

class AppDB {
  static late Isar isar;
}
Future<void> syncDiscountRulesFromApi(
    Isar isar,
    OrderRepository repo,
    ) async {
  print("🔄 SYNC DISCOUNT RULES START");

  final apiRules = await repo.fetchDiscountRules();

  print("📥 API RULE COUNT → ${apiRules.length}");

  await isar.writeTxn(() async {
    print("🧹 Clearing old discount rules from Isar");
    await isar.discountRuleIsars.clear();

    for (final r in apiRules) {
      print("💾 Saving rule to Isar → ${r['ruleId']}");

      await isar.discountRuleIsars.put(
        DiscountRuleIsar()
          ..ruleId = r['ruleId']
          ..productIds =
          (r['productIds'] as List).map((e) => int.parse(e.toString())).toList()
          ..requiredQty = int.parse(r['requiredQty'].toString())
          ..bundlePrice = double.parse(r['bundlePrice'].toString())
          ..bundlePriceType = r['bundlePriceType']
          ..ruleType = r['ruleType']
          ..startDate = r['startDate']
          ..endDate = r['endDate']
          ..active = r['active'] == true,
      );
    }
  });

  final savedRules =
  await isar.discountRuleIsars.where().findAll();

  print("✅ ISAR SAVE COMPLETE → ${savedRules.length} rules stored");

  for (final r in savedRules) {
    print(
      "📦 ISAR RULE → id=${r.ruleId} "
          "| type=${r.ruleType} "
          "| products=${r.productIds} "
          "| qty=${r.requiredQty} "
          "| bundle=${r.bundlePrice} ${r.bundlePriceType}",
    );
  }
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

    // -----------------------------
    // Build units
    // -----------------------------
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

    // -----------------------------
    // Load rules
    // -----------------------------
    final rules = (await isar.discountRuleIsars
        .filter()
        .activeEqualTo(true)
        .findAll())
      ..sort((a, b) => _priority(a.ruleType)
          .compareTo(_priority(b.ruleType)));

    final Map<int, EngineDiscountResult> result = {};

    // -----------------------------
    // Apply rules
    // -----------------------------
    for (final rule in rules) {
      final ruleType = rule.ruleType;
      if (ruleType == null) continue;

      final eligible = units
          .where((u) => !u.used && rule.productIds.contains(u.pid))
          .toList();

      int effectiveQty = rule.requiredQty;

      if (effectiveQty == 0) {
        if (ruleType == 'auto') {
          effectiveQty = eligible.length;
        } else if (ruleType == 'mixmatch') {
          effectiveQty = rule.productIds.length;
        }
      }

      if (effectiveQty <= 0) continue;
      if (eligible.length < effectiveQty) continue;

      List<_Unit> bundle;

      if (ruleType != 'mixmatch') {
        final samePid =
        eligible.where((u) => u.pid == eligible.first.pid).toList();

        if (samePid.length < effectiveQty) continue;
        bundle = samePid.take(effectiveQty).toList();
      } else {
        bundle = eligible.take(effectiveQty).toList();
      }

      final subtotal =
      bundle.fold(0, (s, u) => s + u.priceCents);

      int discountCents;

      if (rule.bundlePriceType == 'percentage') {
        discountCents =
            (subtotal * rule.bundlePrice / 100).round();
      } else {
        discountCents = toCents(rule.bundlePrice);
      }

      discountCents = discountCents.clamp(0, subtotal);

      if (discountCents <= 0) continue;

      for (final u in bundle) {
        u.used = true;
      }

      result[bundle.first.pid] = EngineDiscountResult(
        fromCents(discountCents),
        ruleType,
        rule.ruleId,
      );

      print(
        "🎯 ENGINE APPLY → rule=${rule.ruleId} | "
            "type=$ruleType | discount=${fromCents(discountCents)}",
      );
    }

    // ✅ REQUIRED RETURN
    return result;
  }
}

