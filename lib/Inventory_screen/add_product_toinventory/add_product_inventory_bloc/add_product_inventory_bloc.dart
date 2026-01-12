import 'package:flutter_bloc/flutter_bloc.dart';

import 'add_product_inventory_event.dart';
import '../add_product_inventory_get_usecase.dart';
import 'add_product_inventory_state.dart';


class AddProductInventoryTaxBloc extends Bloc<AddProductInventoryTaxEvent, AddProductInventoryTaxState> {
  final AddProductInventoryTaxGetUseCase addProductUseCase;

  AddProductInventoryTaxBloc({required this.addProductUseCase}) : super(AddProductInventoryTaxInitial()) {
    on<AddProductInventoryTaxSubmitEvent>((event, emit) async {
      emit(AddProductInventoryTaxLoading());
      try {
        final product = await addProductUseCase(event.product);
        emit(AddProductInventoryTaxLoaded(product: product));
      } catch (e) {
        emit(AddProductInventoryTaxError(message: e.toString()));
      }
    });
  }
}
