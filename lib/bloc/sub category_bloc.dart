import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:kioski2/features/category/data/repositories/category_repository.dart';
// import 'package:kioski2/features/subcategory/presentation/bloc/subcategory_event.dart';
// import 'package:kioski2/features/subcategory/presentation/bloc/subcategory_state.dart';
import 'package:equatable/equatable.dart';

import '../model/category_model.dart';
import '../repository/category_data_resource.dart';

abstract class SubcategoryEvent extends Equatable {
  const SubcategoryEvent();

  @override
  List<Object?> get props => [];
}

class FetchSubcategories extends SubcategoryEvent {
  final int parentId;

  const FetchSubcategories(this.parentId);

  @override
  List<Object?> get props => [parentId];
}


abstract class SubcategoryState extends Equatable {
  const SubcategoryState();

  @override
  List<Object?> get props => [];
}

class SubcategoryInitial extends SubcategoryState {
  const SubcategoryInitial();
}

class SubcategoryLoading extends SubcategoryState {
  const SubcategoryLoading();
}

class SubcategoryLoaded extends SubcategoryState {
  final int parentId;
  final List<CategoryModel> subcategories;

  const SubcategoryLoaded({
    required this.parentId,
    required this.subcategories,
  });

  @override
  List<Object?> get props => [parentId, subcategories];
}

class SubcategoryError extends SubcategoryState {
  final String message;

  const SubcategoryError(this.message);

  @override
  List<Object?> get props => [message];
}


class SubcategoryBloc extends Bloc<SubcategoryEvent, SubcategoryState> {
  final CategoryRepository _repository;

  SubcategoryBloc({required CategoryRepository repository})
      : _repository = repository,
        super(const SubcategoryInitial()) {
    on<FetchSubcategories>(_onFetchSubcategories);
  }

  Future<void> _onFetchSubcategories(
      FetchSubcategories event,
      Emitter<SubcategoryState> emit,
      ) async {
    emit(const SubcategoryLoading());
    try {
      final subcategories = await _repository.getSubcategories(event.parentId);
      emit(SubcategoryLoaded(
        parentId: event.parentId,
        subcategories: subcategories,
      ));
    } catch (e) {
      emit(SubcategoryError(e.toString()));
    }
  }
}