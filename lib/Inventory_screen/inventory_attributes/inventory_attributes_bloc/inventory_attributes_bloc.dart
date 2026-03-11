import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_attributes_get_usecase.dart';
import 'inventory_attributes_event.dart';
import 'inventory_attributes_state.dart';

class InventoryAttributesBloc extends Bloc<InventoryAttributesEvent, InventoryAttributesState> {
  final InventoryAttributesGetUseCase getUseCase;

  InventoryAttributesBloc({required this.getUseCase}) : super(InventoryAttributesInitial()) {
    on<FetchInventoryAttributesEvent>((event, emit) async {
      emit(InventoryAttributesLoading());
      try {
        final attributes = await getUseCase();
        emit(InventoryAttributesLoaded(attributes: attributes));
      } catch (e) {
        emit(InventoryAttributesError(message: e.toString()));
      }
    });
  }
}
