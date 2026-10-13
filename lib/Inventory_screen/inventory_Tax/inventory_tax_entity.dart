import 'package:equatable/equatable.dart';

class Inventory_Tax_Entity extends Equatable {
  final int id;
  final String country;
  final String state;
  final String postcode;
  final String city;
  final String rate;
  final String name;
  final int priority;
  final bool compound;
  final bool shipping;
  final int order;
  final String taxClass;

  const Inventory_Tax_Entity({
    required this.id,
    required this.country,
    required this.state,
    required this.postcode,
    required this.city,
    required this.rate,
    required this.name,
    required this.priority,
    required this.compound,
    required this.shipping,
    required this.order,
    required this.taxClass,
  });

  @override
  List<Object?> get props => [
    id, country, state, postcode, city, rate, name,
    priority, compound, shipping, order, taxClass
  ];
}
