
import 'inventory_tax_entity.dart';

class Inventory_Tax_Model extends Inventory_Tax_Entity {
  const Inventory_Tax_Model({
    required int id,
    required String country,
    required String state,
    required String postcode,
    required String city,
    required String rate,
    required String name,
    required int priority,
    required bool compound,
    required bool shipping,
    required int order,
    required String taxClass,
  }) : super(
    id: id,
    country: country,
    state: state,
    postcode: postcode,
    city: city,
    rate: rate,
    name: name,
    priority: priority,
    compound: compound,
    shipping: shipping,
    order: order,
    taxClass: taxClass,
  );

  factory Inventory_Tax_Model.fromJson(Map<String, dynamic> json) {
    return Inventory_Tax_Model(
      id: json['id'],
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      postcode: json['postcode'] ?? '',
      city: json['city'] ?? '',
      rate: json['rate'] ?? '0',
      name: json['name'] ?? '',
      priority: json['priority'] ?? 0,
      compound: json['compound'] ?? false,
      shipping: json['shipping'] ?? false,
      order: json['order'] ?? 0,
      taxClass: json['class'] ?? '',
    );
  }
}
