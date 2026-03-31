import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/promotion_image_model.dart';
import '../repository/promotion_repository.dart';

enum PromotionType {
  portrait,
  fullScreen,
  banner,
}

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

class FetchFullScreenPromotionImages extends PromotionEvent {
  final String token;

  const FetchFullScreenPromotionImages(this.token);

  @override
  List<Object?> get props => [token];
}

class FetchBannerPromotionImages extends PromotionEvent {
  final String token;

  const FetchBannerPromotionImages(this.token);

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
  final PromotionType type;   // 👈 add this

  const PromotionLoaded({
    required this.images,
    required this.message,
    required this.type,       // 👈 add this
  });

  @override
  List<Object?> get props => [images, message, type];
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
    on<FetchFullScreenPromotionImages>(_onFetchFullScreenPromotionImages);
    on<FetchBannerPromotionImages>(_onFetchBannerPromotionImages);
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
          type: PromotionType.portrait,
        ),
      );
    } catch (e) {
      emit(PromotionError(e.toString()));
    }
  }

  Future<void> _onFetchFullScreenPromotionImages(
    FetchFullScreenPromotionImages event,
    Emitter<PromotionState> emit,
  ) async {
    emit(const PromotionLoading());
    try {
      final response =
          await _repository.getFullScreenPromotionImages(token: event.token);

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
          type: PromotionType.fullScreen,
        ),
      );
    } catch (e) {
      emit(PromotionError(e.toString()));
    }
  }

  Future<void> _onFetchBannerPromotionImages(
    FetchBannerPromotionImages event,
    Emitter<PromotionState> emit,
  ) async {
    emit(const PromotionLoading());
    try {
      final response =
          await _repository.getBannerPromotionImages(token: event.token);

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
          type: PromotionType.banner,
        ),
      );
    } catch (e) {
      emit(PromotionError(e.toString()));
    }
  }
}

