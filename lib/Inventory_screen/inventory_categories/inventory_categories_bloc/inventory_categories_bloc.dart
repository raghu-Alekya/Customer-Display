import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_categories_get_usecase.dart';
import 'inventory_categories_event.dart';
import 'inventory_categories_state.dart';

class InventoryCategoriesBloc extends Bloc<InventoryCategoriesEvent, InventoryCategoriesState> {
  final InventoryCategoriesGetUseCase getCategoriesUseCase;

  InventoryCategoriesBloc({required this.getCategoriesUseCase}) : super(InventoryCategoriesInitial()) {
    on<InventoryCategoriesFetchEvent>((event, emit) async {
      emit(InventoryCategoriesLoading());
      try {
        final categories = await getCategoriesUseCase();
        emit(InventoryCategoriesLoaded(categories: categories));
      } catch (e) {
        emit(InventoryCategoriesError(message: e.toString()));
      }
    });
  }
}
