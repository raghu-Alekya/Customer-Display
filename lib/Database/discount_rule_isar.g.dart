// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discount_rule_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDiscountRuleIsarCollection on Isar {
  IsarCollection<DiscountRuleIsar> get discountRuleIsars => this.collection();
}

const DiscountRuleIsarSchema = CollectionSchema(
  name: r'DiscountRuleIsar',
  id: -1567798893918004266,
  properties: {
    r'active': PropertySchema(
      id: 0,
      name: r'active',
      type: IsarType.bool,
    ),
    r'bundlePrice': PropertySchema(
      id: 1,
      name: r'bundlePrice',
      type: IsarType.double,
    ),
    r'productIds': PropertySchema(
      id: 2,
      name: r'productIds',
      type: IsarType.longList,
    ),
    r'requiredQty': PropertySchema(
      id: 3,
      name: r'requiredQty',
      type: IsarType.long,
    ),
    r'ruleId': PropertySchema(
      id: 4,
      name: r'ruleId',
      type: IsarType.string,
    ),
    r'ruleType': PropertySchema(
      id: 5,
      name: r'ruleType',
      type: IsarType.string,
    )
  },
  estimateSize: _discountRuleIsarEstimateSize,
  serialize: _discountRuleIsarSerialize,
  deserialize: _discountRuleIsarDeserialize,
  deserializeProp: _discountRuleIsarDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _discountRuleIsarGetId,
  getLinks: _discountRuleIsarGetLinks,
  attach: _discountRuleIsarAttach,
  version: '3.1.0+1',
);

int _discountRuleIsarEstimateSize(
  DiscountRuleIsar object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.productIds.length * 8;
  bytesCount += 3 + object.ruleId.length * 3;
  {
    final value = object.ruleType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _discountRuleIsarSerialize(
  DiscountRuleIsar object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.active);
  writer.writeDouble(offsets[1], object.bundlePrice);
  writer.writeLongList(offsets[2], object.productIds);
  writer.writeLong(offsets[3], object.requiredQty);
  writer.writeString(offsets[4], object.ruleId);
  writer.writeString(offsets[5], object.ruleType);
}

DiscountRuleIsar _discountRuleIsarDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DiscountRuleIsar();
  object.active = reader.readBool(offsets[0]);
  object.bundlePrice = reader.readDouble(offsets[1]);
  object.id = id;
  object.productIds = reader.readLongList(offsets[2]) ?? [];
  object.requiredQty = reader.readLong(offsets[3]);
  object.ruleId = reader.readString(offsets[4]);
  object.ruleType = reader.readStringOrNull(offsets[5]);
  return object;
}

P _discountRuleIsarDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readLongList(offset) ?? []) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _discountRuleIsarGetId(DiscountRuleIsar object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _discountRuleIsarGetLinks(DiscountRuleIsar object) {
  return [];
}

void _discountRuleIsarAttach(
    IsarCollection<dynamic> col, Id id, DiscountRuleIsar object) {
  object.id = id;
}

extension DiscountRuleIsarQueryWhereSort
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QWhere> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DiscountRuleIsarQueryWhere
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QWhereClause> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DiscountRuleIsarQueryFilter
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QFilterCondition> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      activeEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'active',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      bundlePriceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bundlePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      bundlePriceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bundlePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      bundlePriceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bundlePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      bundlePriceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bundlePrice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      productIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'productIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      requiredQtyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiredQty',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      requiredQtyGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requiredQty',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      requiredQtyLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requiredQty',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      requiredQtyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requiredQty',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ruleId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ruleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ruleId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ruleId',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ruleId',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ruleType',
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ruleType',
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ruleType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ruleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ruleType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ruleType',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterFilterCondition>
      ruleTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ruleType',
        value: '',
      ));
    });
  }
}

extension DiscountRuleIsarQueryObject
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QFilterCondition> {}

extension DiscountRuleIsarQueryLinks
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QFilterCondition> {}

extension DiscountRuleIsarQuerySortBy
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QSortBy> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByBundlePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bundlePrice', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByBundlePriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bundlePrice', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRequiredQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredQty', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRequiredQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredQty', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRuleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleId', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRuleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleId', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRuleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleType', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      sortByRuleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleType', Sort.desc);
    });
  }
}

extension DiscountRuleIsarQuerySortThenBy
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QSortThenBy> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByBundlePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bundlePrice', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByBundlePriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bundlePrice', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRequiredQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredQty', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRequiredQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredQty', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRuleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleId', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRuleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleId', Sort.desc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRuleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleType', Sort.asc);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QAfterSortBy>
      thenByRuleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ruleType', Sort.desc);
    });
  }
}

extension DiscountRuleIsarQueryWhereDistinct
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct> {
  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct>
      distinctByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'active');
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct>
      distinctByBundlePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bundlePrice');
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct>
      distinctByProductIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productIds');
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct>
      distinctByRequiredQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requiredQty');
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct> distinctByRuleId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ruleId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QDistinct>
      distinctByRuleType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ruleType', caseSensitive: caseSensitive);
    });
  }
}

extension DiscountRuleIsarQueryProperty
    on QueryBuilder<DiscountRuleIsar, DiscountRuleIsar, QQueryProperty> {
  QueryBuilder<DiscountRuleIsar, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DiscountRuleIsar, bool, QQueryOperations> activeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'active');
    });
  }

  QueryBuilder<DiscountRuleIsar, double, QQueryOperations>
      bundlePriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bundlePrice');
    });
  }

  QueryBuilder<DiscountRuleIsar, List<int>, QQueryOperations>
      productIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productIds');
    });
  }

  QueryBuilder<DiscountRuleIsar, int, QQueryOperations> requiredQtyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requiredQty');
    });
  }

  QueryBuilder<DiscountRuleIsar, String, QQueryOperations> ruleIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ruleId');
    });
  }

  QueryBuilder<DiscountRuleIsar, String?, QQueryOperations> ruleTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ruleType');
    });
  }
}
