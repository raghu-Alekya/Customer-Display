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
          ..requiredProductIds = r['requiredProductIds'] != null
              ? int.tryParse(r['requiredProductIds'].toString())
              : null
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
      ..sort((a, b) =>
          _priority(a.ruleType).compareTo(_priority(b.ruleType)));

    final Map<int, EngineDiscountResult> result = {};

    // =====================================================
    // 1️⃣ AUTO — per item, price based, NO requiredQty
    // =====================================================
    for (final rule in rules.where((r) => r.ruleType == 'auto')) {
      for (final u in units.where(
              (u) => !u.used && rule.productIds.contains(u.pid))) {
        int discountCents;

        if (rule.bundlePriceType == 'percentage') {
          discountCents =
              (u.priceCents * rule.bundlePrice / 100).round();
        } else {
          discountCents = toCents(rule.bundlePrice);
        }

        discountCents = discountCents.clamp(0, u.priceCents);
        if (discountCents <= 0) continue;

        u.used = true;

        result[u.pid] = EngineDiscountResult(
          (result[u.pid]?.amount ?? 0) + fromCents(discountCents),
          'auto',
          rule.ruleId,
        );

        print(
          "🎯 AUTO → pid=${u.pid} discount=${fromCents(discountCents)}",
        );
      }
    }
// =====================================================
// 2️⃣ MIXMATCH — pair-based (min(parent, child))
// =====================================================
    for (final rule in rules.where((r) => r.ruleType == 'mixmatch')) {

      if (rule.requiredProductIds == null) continue;

      // 🔢 Collect unused parent & child units
      final parentUnits = units.where(
            (u) => !u.used && u.pid == rule.requiredProductIds,
      ).toList();

      final childUnits = units.where(
            (u) => !u.used && rule.productIds.contains(u.pid),
      ).toList();

      final int pairCount =
      parentUnits.length < childUnits.length
          ? parentUnits.length
          : childUnits.length;

      if (pairCount == 0) {
        print("⛔ MIXMATCH skipped → no valid pairs");
        continue;
      }

      for (int i = 0; i < pairCount; i++) {
        final parent = parentUnits[i];
        final child = childUnits[i];

        int discountCents;

        if (rule.bundlePriceType == 'percentage') {
          discountCents =
              (child.priceCents * rule.bundlePrice / 100).round();
        } else {
          discountCents = toCents(rule.bundlePrice);
        }

        discountCents = discountCents.clamp(0, child.priceCents);
        if (discountCents <= 0) continue;

        // 🔒 Lock one parent + one child
        parent.used = true;
        child.used = true;

        result[child.pid] = EngineDiscountResult(
          (result[child.pid]?.amount ?? 0) + fromCents(discountCents),
          'mixmatch',
          rule.ruleId,
        );

        print(
          "🎯 MIXMATCH → pair=${i + 1} "
              "parent=${parent.pid} child=${child.pid} "
              "discount=${fromCents(discountCents)}",
        );
      }
    }


    // =====================================================
    //  MULTIPACK — bundle logic USING requiredQty
    // =====================================================
    // =====================================================
    final Map<int, List<_Unit>> unitsByPid = {};

    for (final u in units.where((u) => !u.used)) {
      unitsByPid.putIfAbsent(u.pid, () => []).add(u);
    }
    final multipackRules =
    rules.where((r) => r.ruleType == 'multipack').toList();

    for (final entry in unitsByPid.entries) {
      final pid = entry.key;
      final productUnits = entry.value;
      final qty = productUnits.length;
      final applicableRules = multipackRules
          .where((r) => r.productIds.contains(pid))
          .where((r) => qty >= r.requiredQty)
          .toList();

      if (applicableRules.isEmpty) continue;
      applicableRules.sort(
            (a, b) => b.requiredQty.compareTo(a.requiredQty),
      );

      final rule = applicableRules.first;

      final subtotal = productUnits.fold(
        0,
            (s, u) => s + u.priceCents,
      );

      int discountCents;
      if (rule.bundlePriceType == 'percentage') {
        discountCents =
            (subtotal * rule.bundlePrice / 100).round();
      } else {
        discountCents = toCents(rule.bundlePrice);
      }

      discountCents = discountCents.clamp(0, subtotal);
      if (discountCents <= 0) continue;
      for (final u in productUnits) {
        u.used = true;
      }

      result[pid] = EngineDiscountResult(
        fromCents(discountCents),
        'multipack',
        rule.ruleId,
      );

      print(
        "🏷️ TIERED MULTIPACK → pid=$pid "
            "qty=$qty "
            "slab=${rule.requiredQty} "
            "discount=${fromCents(discountCents)}",
      );
    }


    //  FINAL RESULT
    return result;
  }
}