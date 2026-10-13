import '../inventory_categories_entity.dart';

abstract class InventoryCategoriesState {}

class InventoryCategoriesInitial extends InventoryCategoriesState {}

class InventoryCategoriesLoading extends InventoryCategoriesState {}

class InventoryCategoriesLoaded extends InventoryCategoriesState {
  final List<InventoryCategoriesEntity> categories;

  InventoryCategoriesLoaded({required this.categories});
}

class InventoryCategoriesError extends InventoryCategoriesState {
  final String message;

  InventoryCategoriesError({required this.message});
}
