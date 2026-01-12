import 'inventory_get_product_types_entity.dart';

class InventoryGetProductTypesModel extends InventoryGetProductTypesEntity {
  InventoryGetProductTypesModel({required Map<String, String> types})
      : super(types: types);

  factory InventoryGetProductTypesModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return InventoryGetProductTypesModel(
      types: data.map((key, value) => MapEntry(key, value.toString())),
    );
  }
}
