import 'package:flutter_bloc/flutter_bloc.dart';
import '../inventory_tag_get_tags_usecase.dart';
import 'inventory_tag_event.dart';
import 'inventory_tag_state.dart';

class Inventory_Tag_Bloc
    extends Bloc<Inventory_Tag_Event, Inventory_Tag_State> {
  final Inventory_Tag_Get_Tags_UseCase getTagsUseCase;

  Inventory_Tag_Bloc(this.getTagsUseCase)
      : super(Inventory_Tag_Initial()) {
    on<Inventory_Tag_Fetch_Event>((event, emit) async {
      emit(Inventory_Tag_Loading());
      try {
        final tags = await getTagsUseCase();
        emit(Inventory_Tag_Loaded(tags));
      } catch (e) {
        emit(Inventory_Tag_Error(e.toString()));
      }
    });
  }
}
