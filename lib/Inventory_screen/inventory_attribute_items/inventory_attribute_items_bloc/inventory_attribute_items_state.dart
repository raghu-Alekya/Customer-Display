import 'package:equatable/equatable.dart';

import '../inventory_attribute_items_entity.dart';

abstract class InventoryAttributeItemsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class InventoryAttributeItemsInitial extends InventoryAttributeItemsState {}

class InventoryAttributeItemsLoading extends InventoryAttributeItemsState {}

class InventoryAttributeItemsLoaded extends InventoryAttributeItemsState {
  final List<InventoryAttributeItemsEntity> items;

  InventoryAttributeItemsLoaded({required this.items});

  @override
  List<Object?> get props => [items];
}

class InventoryAttributeItemsError extends InventoryAttributeItemsState {
  final String message;

  InventoryAttributeItemsError({required this.message});

  @override
  List<Object?> get props => [message];
}
