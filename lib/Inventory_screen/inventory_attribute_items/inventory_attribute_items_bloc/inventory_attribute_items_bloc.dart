import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_attribute_items_get_usecase.dart';
import 'inventory_attribute_items_event.dart';
import 'inventory_attribute_items_state.dart';

class InventoryAttributeItemsBloc
    extends Bloc<InventoryAttributeItemsEvent, InventoryAttributeItemsState> {
  final GetInventoryAttributeItemsUseCase getItemsUseCase;

  InventoryAttributeItemsBloc({required this.getItemsUseCase})
      : super(InventoryAttributeItemsInitial()) {
    on<FetchInventoryAttributeItemsEvent>((event, emit) async {
      emit(InventoryAttributeItemsLoading());
      try {
        final items = await getItemsUseCase(attributeId: event.attributeId);
        emit(InventoryAttributeItemsLoaded(items: items));
      } catch (e) {
        emit(InventoryAttributeItemsError(message: e.toString()));
      }
    });
  }
}
