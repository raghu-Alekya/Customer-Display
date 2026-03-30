import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/promotion_image_model.dart';
import '../repository/promotion_repository.dart';

// EVENTS

abstract class PromotionEvent extends Equatable {
  const PromotionEvent();

  @override
  List<Object?> get props => [];
}

class FetchPortraitPromotionImages extends PromotionEvent {
  final String token;

  const FetchPortraitPromotionImages(this.token);

  @override
  List<Object?> get props => [token];
}

// STATES

abstract class PromotionState extends Equatable {
  const PromotionState();

  @override
  List<Object?> get props => [];
}

class PromotionInitial extends PromotionState {
  const PromotionInitial();
}

class PromotionLoading extends PromotionState {
  const PromotionLoading();
}

class PromotionLoaded extends PromotionState {
  final List<String> images;
  final String message;

  const PromotionLoaded({
    required this.images,
    required this.message,
  });

  @override
  List<Object?> get props => [images, message];
}

class PromotionError extends PromotionState {
  final String message;

  const PromotionError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLOC

class PromotionBloc extends Bloc<PromotionEvent, PromotionState> {
  final PromotionRepository _repository;

  PromotionBloc({required PromotionRepository repository})
      : _repository = repository,
        super(const PromotionInitial()) {
    on<FetchPortraitPromotionImages>(_onFetchPortraitPromotionImages);
  }

  Future<void> _onFetchPortraitPromotionImages(
    FetchPortraitPromotionImages event,
    Emitter<PromotionState> emit,
  ) async {
    emit(const PromotionLoading());
    try {
      final response =
          await _repository.getPortraitPromotionImages(token: event.token);

      if (!response.success || response.images.isEmpty) {
        emit(
          PromotionError(
            response.message.isEmpty
                ? 'No promotion images available'
                : response.message,
          ),
        );
        return;
      }

      emit(
        PromotionLoaded(
          images: response.images,
          message: response.message,
        ),
      );
    } catch (e) {
      emit(PromotionError(e.toString()));
    }
  }
}

