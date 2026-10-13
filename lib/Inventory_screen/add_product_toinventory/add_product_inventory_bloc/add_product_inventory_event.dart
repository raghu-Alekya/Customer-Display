
import '../add_product_inventory_entity.dart';

abstract class AddProductInventoryTaxEvent {}

class AddProductInventoryTaxSubmitEvent extends AddProductInventoryTaxEvent {
  final AddProductInventoryTaxEntity product;

  AddProductInventoryTaxSubmitEvent({required this.product});
}
