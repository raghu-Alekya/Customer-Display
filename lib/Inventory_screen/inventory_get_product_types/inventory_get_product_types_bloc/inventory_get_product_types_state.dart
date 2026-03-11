
import '../inventory_get_product_types_entity.dart';

abstract class InventoryGetProductTypesState {}

class InventoryGetProductTypesInitial extends InventoryGetProductTypesState {}

class InventoryGetProductTypesLoading extends InventoryGetProductTypesState {}

class InventoryGetProductTypesLoaded extends InventoryGetProductTypesState {
  final InventoryGetProductTypesEntity productTypes;

  InventoryGetProductTypesLoaded(this.productTypes);
}

class InventoryGetProductTypesError extends InventoryGetProductTypesState {
  final String message;

  InventoryGetProductTypesError(this.message);
}
