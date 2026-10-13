import 'package:flutter_bloc/flutter_bloc.dart';

import '../inventory_attribute_items_remote_data_source.dart';
import 'inventory_attribute_items_event.dart';
import 'inventory_attribute_items_state.dart';

class InventoryAttributeItemsBloc extends Bloc<
    InventoryAttributeItemsEvent, InventoryAttributeItemsState> {
  final InventoryAttributeItemsApi api;

  InventoryAttributeItemsBloc(this.api)
      : super(InventoryAttributeItemsInitial()) {
    on<FetchInventoryAttributeItems>((event, emit) async {
      emit(InventoryAttributeItemsLoading());

      try {
        final items = await api.fetchItems(event.attributeId);

        // Debug
        for (final i in items) {
          print('Item: ${i.id} | ${i.name}');
        }

        emit(InventoryAttributeItemsLoaded(items));
      } catch (e) {
        emit(InventoryAttributeItemsError(e.toString()));
      }
    });
  }
}
