import 'package:isar/isar.dart';

part 'discount_rule_isar.g.dart';

@collection
class DiscountRuleIsar {
  Id id = Isar.autoIncrement;

  late String ruleId;
  late List<int> productIds;

  int? requiredProductIds;
  late int requiredQty;

  late double bundlePrice;
  String? bundlePriceType; // price | percentage
  String? ruleType;        // auto | multipack | mixmatch

  String? startDate; // yyyy-MM-dd
  String? endDate;

  bool active = true;
}
