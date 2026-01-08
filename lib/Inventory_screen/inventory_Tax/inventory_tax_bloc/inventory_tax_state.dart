import 'package:equatable/equatable.dart';

import '../inventory_tax_entity.dart';

abstract class Inventory_Tax_State extends Equatable {
  @override
  List<Object?> get props => [];
}

class Inventory_Tax_Initial extends Inventory_Tax_State {}

class Inventory_Tax_Loading extends Inventory_Tax_State {}

class Inventory_Tax_Loaded extends Inventory_Tax_State {
  final List<Inventory_Tax_Entity> taxes;

  Inventory_Tax_Loaded(this.taxes);

  @override
  List<Object?> get props => [taxes];
}

class Inventory_Tax_Error extends Inventory_Tax_State {
  final String message;

  Inventory_Tax_Error(this.message);

  @override
  List<Object?> get props => [message];
}
