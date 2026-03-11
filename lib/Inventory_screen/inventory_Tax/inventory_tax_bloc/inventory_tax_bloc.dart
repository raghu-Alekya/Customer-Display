import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_tax_get_usecase.dart';
import 'inventory_tax_event.dart';
import 'inventory_tax_state.dart';

class Inventory_Tax_Bloc extends Bloc<Inventory_Tax_Event, Inventory_Tax_State> {
  final Inventory_Tax_Get_UseCase getTaxesUseCase;

  Inventory_Tax_Bloc(this.getTaxesUseCase) : super(Inventory_Tax_Initial()) {
    on<Inventory_Tax_Fetch_Event>((event, emit) async {
      emit(Inventory_Tax_Loading());
      try {
        final taxes = await getTaxesUseCase();
        emit(Inventory_Tax_Loaded(taxes));
      } catch (e) {
        emit(Inventory_Tax_Error(e.toString()));
      }
    });
  }
}
