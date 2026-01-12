import 'package:equatable/equatable.dart';

abstract class InventoryAttributeItemsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchInventoryAttributeItemsEvent extends InventoryAttributeItemsEvent {
  final int attributeId;

  FetchInventoryAttributeItemsEvent({required this.attributeId});

  @override
  List<Object?> get props => [attributeId];
}
