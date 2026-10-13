import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_get_product_types_get_usecase.dart';
import 'inventory_get_product_types_event.dart';
import 'inventory_get_product_types_state.dart';

class InventoryGetProductTypesBloc
    extends Bloc<InventoryGetProductTypesEvent, InventoryGetProductTypesState> {
  final InventoryGetProductTypesGetUseCase useCase;

  InventoryGetProductTypesBloc({required this.useCase})
      : super(InventoryGetProductTypesInitial()) {
    on<InventoryGetProductTypesLoadEvent>((event, emit) async {
      emit(InventoryGetProductTypesLoading());
      try {
        final result = await useCase();
        emit(InventoryGetProductTypesLoaded(result));
      } catch (e) {
        emit(InventoryGetProductTypesError(e.toString()));
      }
    });
  }
}
