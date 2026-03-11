import 'package:equatable/equatable.dart';

import '../inventory_tag_entity.dart';

abstract class Inventory_Tag_State extends Equatable {
  @override
  List<Object?> get props => [];
}

class Inventory_Tag_Initial extends Inventory_Tag_State {}

class Inventory_Tag_Loading extends Inventory_Tag_State {}

class Inventory_Tag_Loaded extends Inventory_Tag_State {
  final List<Inventory_Tag_Entity> tags;

  Inventory_Tag_Loaded(this.tags);

  @override
  List<Object?> get props => [tags];
}

class Inventory_Tag_Error extends Inventory_Tag_State {
  final String message;

  Inventory_Tag_Error(this.message);

  @override
  List<Object?> get props => [message];
}
