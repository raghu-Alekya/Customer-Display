import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../model/addon_model.dart';
import '../repository/addon_repository.dart';

abstract class AddonEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchAddonsEvent extends AddonEvent {
  final int productId;

  FetchAddonsEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}
abstract class AddonState {}

class AddonInitial extends AddonState {}

class AddonLoading extends AddonState {}

class AddonLoaded extends AddonState {
  final List<AddonModel> addons;

  AddonLoaded(this.addons);
}

class AddonError extends AddonState {
  final String message;

  AddonError(this.message);
}

class AddonBloc extends Bloc<AddonEvent, AddonState> {
  final AddonRepository repository;
  final String token;

  AddonBloc(this.repository, this.token) : super(AddonInitial()) {
    on<FetchAddonsEvent>((event, emit) async {
      emit(AddonLoading());

      try {
        final addons = await repository.getAddons(
          productId: event.productId,
          token: token,
        );

        emit(AddonLoaded(addons));
      } catch (e) {
        emit(AddonError(e.toString()));
      }
    });
  }
}