// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_payments_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalPaymentCollection on Isar {
  IsarCollection<LocalPayment> get localPayments => this.collection();
}

const LocalPaymentSchema = CollectionSchema(
  name: r'LocalPayment',
  id: 338859264281517535,
  properties: {
    r'amount': PropertySchema(
      id: 0,
      name: r'amount',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'datetime': PropertySchema(
      id: 2,
      name: r'datetime',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 3,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'notes': PropertySchema(
      id: 4,
      name: r'notes',
      type: IsarType.string,
    ),
    r'orderId': PropertySchema(
      id: 5,
      name: r'orderId',
      type: IsarType.long,
    ),
    r'paymentMethod': PropertySchema(
      id: 6,
      name: r'paymentMethod',
      type: IsarType.string,
    ),
    r'remainingBalance': PropertySchema(
      id: 7,
      name: r'remainingBalance',
      type: IsarType.double,
    ),
    r'serverPaymentId': PropertySchema(
      id: 8,
      name: r'serverPaymentId',
      type: IsarType.long,
    ),
    r'serviceType': PropertySchema(
      id: 9,
      name: r'serviceType',
      type: IsarType.string,
    ),
    r'shiftId': PropertySchema(
      id: 10,
      name: r'shiftId',
      type: IsarType.long,
    ),
    r'status': PropertySchema(
      id: 11,
      name: r'status',
      type: IsarType.byte,
      enumMap: _LocalPaymentstatusEnumValueMap,
    ),
    r'sunmiDeviceId': PropertySchema(
      id: 12,
      name: r'sunmiDeviceId',
      type: IsarType.string,
    ),
    r'sunmiOrderId': PropertySchema(
      id: 13,
      name: r'sunmiOrderId',
      type: IsarType.string,
    ),
    r'sunmiTxnId': PropertySchema(
      id: 14,
      name: r'sunmiTxnId',
      type: IsarType.string,
    ),
    r'syncAttempts': PropertySchema(
      id: 15,
      name: r'syncAttempts',
      type: IsarType.long,
    ),
    r'syncError': PropertySchema(
      id: 16,
      name: r'syncError',
      type: IsarType.string,
    ),
    r'syncedAt': PropertySchema(
      id: 17,
      name: r'syncedAt',
      type: IsarType.dateTime,
    ),
    r'title': PropertySchema(
      id: 18,
      name: r'title',
      type: IsarType.string,
    ),
    r'userId': PropertySchema(
      id: 19,
      name: r'userId',
      type: IsarType.long,
    ),
    r'vendorId': PropertySchema(
      id: 20,
      name: r'vendorId',
      type: IsarType.long,
    )
  },
  estimateSize: _localPaymentEstimateSize,
  serialize: _localPaymentSerialize,
  deserialize: _localPaymentDeserialize,
  deserializeProp: _localPaymentDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _localPaymentGetId,
  getLinks: _localPaymentGetLinks,
  attach: _localPaymentAttach,
  version: '3.3.2',
);

int _localPaymentEstimateSize(
  LocalPayment object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.datetime.length * 3;
  bytesCount += 3 + object.notes.length * 3;
  bytesCount += 3 + object.paymentMethod.length * 3;
  bytesCount += 3 + object.serviceType.length * 3;
  {
    final value = object.sunmiDeviceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sunmiOrderId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sunmiTxnId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.syncError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _localPaymentSerialize(
  LocalPayment object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.amount);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.datetime);
  writer.writeBool(offsets[3], object.isSynced);
  writer.writeString(offsets[4], object.notes);
  writer.writeLong(offsets[5], object.orderId);
  writer.writeString(offsets[6], object.paymentMethod);
  writer.writeDouble(offsets[7], object.remainingBalance);
  writer.writeLong(offsets[8], object.serverPaymentId);
  writer.writeString(offsets[9], object.serviceType);
  writer.writeLong(offsets[10], object.shiftId);
  writer.writeByte(offsets[11], object.status.index);
  writer.writeString(offsets[12], object.sunmiDeviceId);
  writer.writeString(offsets[13], object.sunmiOrderId);
  writer.writeString(offsets[14], object.sunmiTxnId);
  writer.writeLong(offsets[15], object.syncAttempts);
  writer.writeString(offsets[16], object.syncError);
  writer.writeDateTime(offsets[17], object.syncedAt);
  writer.writeString(offsets[18], object.title);
  writer.writeLong(offsets[19], object.userId);
  writer.writeLong(offsets[20], object.vendorId);
}

LocalPayment _localPaymentDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalPayment(
    amount: reader.readDouble(offsets[0]),
    createdAt: reader.readDateTime(offsets[1]),
    datetime: reader.readString(offsets[2]),
    isSynced: reader.readBool(offsets[3]),
    notes: reader.readString(offsets[4]),
    orderId: reader.readLong(offsets[5]),
    paymentMethod: reader.readString(offsets[6]),
    remainingBalance: reader.readDouble(offsets[7]),
    serverPaymentId: reader.readLongOrNull(offsets[8]),
    serviceType: reader.readString(offsets[9]),
    shiftId: reader.readLong(offsets[10]),
    status:
        _LocalPaymentstatusValueEnumMap[reader.readByteOrNull(offsets[11])] ??
            PaymentDbStatus.completed,
    sunmiDeviceId: reader.readStringOrNull(offsets[12]),
    sunmiOrderId: reader.readStringOrNull(offsets[13]),
    sunmiTxnId: reader.readStringOrNull(offsets[14]),
    syncAttempts: reader.readLongOrNull(offsets[15]),
    syncError: reader.readStringOrNull(offsets[16]),
    syncedAt: reader.readDateTimeOrNull(offsets[17]),
    title: reader.readString(offsets[18]),
    userId: reader.readLong(offsets[19]),
    vendorId: reader.readLong(offsets[20]),
  );
  object.id = id;
  return object;
}

P _localPaymentDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (_LocalPaymentstatusValueEnumMap[reader.readByteOrNull(offset)] ??
          PaymentDbStatus.completed) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _LocalPaymentstatusEnumValueMap = {
  'completed': 0,
  'pending': 1,
  'receipt': 2,
  'voided': 3,
};
const _LocalPaymentstatusValueEnumMap = {
  0: PaymentDbStatus.completed,
  1: PaymentDbStatus.pending,
  2: PaymentDbStatus.receipt,
  3: PaymentDbStatus.voided,
};

Id _localPaymentGetId(LocalPayment object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localPaymentGetLinks(LocalPayment object) {
  return [];
}

void _localPaymentAttach(
    IsarCollection<dynamic> col, Id id, LocalPayment object) {
  object.id = id;
}

extension LocalPaymentQueryWhereSort
    on QueryBuilder<LocalPayment, LocalPayment, QWhere> {
  QueryBuilder<LocalPayment, LocalPayment, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalPaymentQueryWhere
    on QueryBuilder<LocalPayment, LocalPayment, QWhereClause> {
  QueryBuilder<LocalPayment, LocalPayment, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<LocalPayment, LocalPayment, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterWhereClause> idBetween(
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

extension LocalPaymentQueryFilter
    on QueryBuilder<LocalPayment, LocalPayment, QFilterCondition> {
  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> amountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'amount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      amountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'amount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      amountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'amount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> amountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'amount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'datetime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'datetime',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'datetime',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'datetime',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      datetimeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'datetime',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      notesGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> notesMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      orderIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'orderId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      orderIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'orderId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      orderIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'orderId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      orderIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'orderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paymentMethod',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'paymentMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'paymentMethod',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paymentMethod',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      paymentMethodIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'paymentMethod',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      remainingBalanceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remainingBalance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      remainingBalanceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remainingBalance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      remainingBalanceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remainingBalance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      remainingBalanceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remainingBalance',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serverPaymentId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serverPaymentId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverPaymentId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serverPaymentId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serverPaymentId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serverPaymentIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serverPaymentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serviceType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'serviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'serviceType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceType',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      serviceTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'serviceType',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      shiftIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shiftId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      shiftIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shiftId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      shiftIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shiftId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      shiftIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shiftId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> statusEqualTo(
      PaymentDbStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      statusGreaterThan(
    PaymentDbStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      statusLessThan(
    PaymentDbStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> statusBetween(
    PaymentDbStatus lower,
    PaymentDbStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sunmiDeviceId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sunmiDeviceId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sunmiDeviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sunmiDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sunmiDeviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiDeviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sunmiDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sunmiOrderId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sunmiOrderId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sunmiOrderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sunmiOrderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sunmiOrderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiOrderId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiOrderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sunmiOrderId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sunmiTxnId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sunmiTxnId',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sunmiTxnId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sunmiTxnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sunmiTxnId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sunmiTxnId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      sunmiTxnIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sunmiTxnId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncAttempts',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncAttempts',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncAttemptsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncAttempts',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncError',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncError',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncError',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncError',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncError',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncError',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncedAt',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncedAt',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      syncedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> userIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      userIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      userIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition> userIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      vendorIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vendorId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      vendorIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'vendorId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      vendorIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'vendorId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterFilterCondition>
      vendorIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'vendorId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension LocalPaymentQueryObject
    on QueryBuilder<LocalPayment, LocalPayment, QFilterCondition> {}

extension LocalPaymentQueryLinks
    on QueryBuilder<LocalPayment, LocalPayment, QFilterCondition> {}

extension LocalPaymentQuerySortBy
    on QueryBuilder<LocalPayment, LocalPayment, QSortBy> {
  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByDatetime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'datetime', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByDatetimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'datetime', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByRemainingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remainingBalance', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByRemainingBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remainingBalance', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByServerPaymentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverPaymentId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByServerPaymentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverPaymentId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByServiceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceType', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortByServiceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceType', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByShiftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shiftId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByShiftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shiftId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySunmiDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiDeviceId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortBySunmiDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiDeviceId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySunmiOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiOrderId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortBySunmiOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiOrderId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySunmiTxnId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiTxnId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortBySunmiTxnIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiTxnId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySyncAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncAttempts', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      sortBySyncAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncAttempts', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByVendorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vendorId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> sortByVendorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vendorId', Sort.desc);
    });
  }
}

extension LocalPaymentQuerySortThenBy
    on QueryBuilder<LocalPayment, LocalPayment, QSortThenBy> {
  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByDatetime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'datetime', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByDatetimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'datetime', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'orderId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByRemainingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remainingBalance', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByRemainingBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remainingBalance', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByServerPaymentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverPaymentId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByServerPaymentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverPaymentId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByServiceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceType', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenByServiceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceType', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByShiftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shiftId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByShiftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shiftId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySunmiDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiDeviceId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenBySunmiDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiDeviceId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySunmiOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiOrderId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenBySunmiOrderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiOrderId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySunmiTxnId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiTxnId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenBySunmiTxnIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sunmiTxnId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySyncAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncAttempts', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy>
      thenBySyncAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncAttempts', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncError', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenBySyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByVendorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vendorId', Sort.asc);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QAfterSortBy> thenByVendorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vendorId', Sort.desc);
    });
  }
}

extension LocalPaymentQueryWhereDistinct
    on QueryBuilder<LocalPayment, LocalPayment, QDistinct> {
  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amount');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByDatetime(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'datetime', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByOrderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'orderId');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByPaymentMethod(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paymentMethod',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct>
      distinctByRemainingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remainingBalance');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct>
      distinctByServerPaymentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverPaymentId');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByServiceType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serviceType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByShiftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shiftId');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySunmiDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sunmiDeviceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySunmiOrderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sunmiOrderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySunmiTxnId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sunmiTxnId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySyncAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncAttempts');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySyncError(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctBySyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncedAt');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId');
    });
  }

  QueryBuilder<LocalPayment, LocalPayment, QDistinct> distinctByVendorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'vendorId');
    });
  }
}

extension LocalPaymentQueryProperty
    on QueryBuilder<LocalPayment, LocalPayment, QQueryProperty> {
  QueryBuilder<LocalPayment, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalPayment, double, QQueryOperations> amountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amount');
    });
  }

  QueryBuilder<LocalPayment, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<LocalPayment, String, QQueryOperations> datetimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'datetime');
    });
  }

  QueryBuilder<LocalPayment, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalPayment, String, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<LocalPayment, int, QQueryOperations> orderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'orderId');
    });
  }

  QueryBuilder<LocalPayment, String, QQueryOperations> paymentMethodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentMethod');
    });
  }

  QueryBuilder<LocalPayment, double, QQueryOperations>
      remainingBalanceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remainingBalance');
    });
  }

  QueryBuilder<LocalPayment, int?, QQueryOperations> serverPaymentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverPaymentId');
    });
  }

  QueryBuilder<LocalPayment, String, QQueryOperations> serviceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serviceType');
    });
  }

  QueryBuilder<LocalPayment, int, QQueryOperations> shiftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shiftId');
    });
  }

  QueryBuilder<LocalPayment, PaymentDbStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<LocalPayment, String?, QQueryOperations>
      sunmiDeviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sunmiDeviceId');
    });
  }

  QueryBuilder<LocalPayment, String?, QQueryOperations> sunmiOrderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sunmiOrderId');
    });
  }

  QueryBuilder<LocalPayment, String?, QQueryOperations> sunmiTxnIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sunmiTxnId');
    });
  }

  QueryBuilder<LocalPayment, int?, QQueryOperations> syncAttemptsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncAttempts');
    });
  }

  QueryBuilder<LocalPayment, String?, QQueryOperations> syncErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncError');
    });
  }

  QueryBuilder<LocalPayment, DateTime?, QQueryOperations> syncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncedAt');
    });
  }

  QueryBuilder<LocalPayment, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<LocalPayment, int, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }

  QueryBuilder<LocalPayment, int, QQueryOperations> vendorIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'vendorId');
    });
  }
}
