
import '../inventory_attributes_entity.dart';

abstract class InventoryAttributesState {}

class InventoryAttributesInitial extends InventoryAttributesState {}

class InventoryAttributesLoading extends InventoryAttributesState {}

class InventoryAttributesLoaded extends InventoryAttributesState {
  final List<InventoryAttributesEntity> attributes;

  InventoryAttributesLoaded({required this.attributes});
}

class InventoryAttributesError extends InventoryAttributesState {
  final String message;

  InventoryAttributesError({required this.message});
}
