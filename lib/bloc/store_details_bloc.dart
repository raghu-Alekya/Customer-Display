import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/store_details_model.dart';
import '../repository/store_details_repository.dart';

// Events

abstract class StoreDetailsEvent extends Equatable {
  const StoreDetailsEvent();

  @override
  List<Object?> get props => [];
}

class FetchStoreDetails extends StoreDetailsEvent {
  final String token;

  const FetchStoreDetails(this.token);

  @override
  List<Object?> get props => [token];
}

// States

abstract class StoreDetailsState extends Equatable {
  const StoreDetailsState();

  @override
  List<Object?> get props => [];
}

class StoreDetailsInitial extends StoreDetailsState {
  const StoreDetailsInitial();
}

class StoreDetailsLoading extends StoreDetailsState {
  const StoreDetailsLoading();
}

class StoreDetailsLoaded extends StoreDetailsState {
  final StoreDetails details;

  const StoreDetailsLoaded(this.details);

  @override
  List<Object?> get props => [details];
}

class StoreDetailsError extends StoreDetailsState {
  final String message;

  const StoreDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc

class StoreDetailsBloc extends Bloc<StoreDetailsEvent, StoreDetailsState> {
  final StoreDetailsRepository _repository;

  StoreDetailsBloc({required StoreDetailsRepository repository})
      : _repository = repository,
        super(const StoreDetailsInitial()) {
    on<FetchStoreDetails>(_onFetchStoreDetails);
  }

  Future<void> _onFetchStoreDetails(
    FetchStoreDetails event,
    Emitter<StoreDetailsState> emit,
  ) async {
    emit(const StoreDetailsLoading());
    try {
      final details = await _repository.getStoreDetails(token: event.token);
      emit(StoreDetailsLoaded(details));
    } catch (e) {
      emit(StoreDetailsError(e.toString()));
    }
  }
}
