import '../add_product_inventory_entity.dart';

abstract class AddProductInventoryTaxState {}

class AddProductInventoryTaxInitial extends AddProductInventoryTaxState {}

class AddProductInventoryTaxLoading extends AddProductInventoryTaxState {}

class AddProductInventoryTaxLoaded extends AddProductInventoryTaxState {
  final AddProductInventoryTaxEntity product;

  AddProductInventoryTaxLoaded({required this.product});
}

class AddProductInventoryTaxError extends AddProductInventoryTaxState {
  final String message;

  AddProductInventoryTaxError({required this.message});
}
