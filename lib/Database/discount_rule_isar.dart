import 'package:isar/isar.dart';

part 'discount_rule_isar.g.dart';

@collection
class DiscountRuleIsar {
  Id id = Isar.autoIncrement;

  late String ruleId;
  late List<int> productIds;
  late int requiredQty;
  late double bundlePrice;
  String? ruleType;

  bool active = true;
}
