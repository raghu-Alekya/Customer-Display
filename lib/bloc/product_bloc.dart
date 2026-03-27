import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:kioski2/features/product/data/repositories/product_repository.dart';
// import 'package:kioski2/features/product/presentation/bloc/product_event.dart';
// import 'package:kioski2/features/product/presentation/bloc/product_state.dart';

import 'package:equatable/equatable.dart';

import '../model/product model.dart';
import '../repository/product_data_resource.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class FetchProductsForCategory extends ProductEvent {
  final int categoryId;

  const FetchProductsForCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class SearchProducts extends ProductEvent {
  final String query;

  const SearchProducts(this.query);

  @override
  List<Object?> get props => [query];
}


abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductLoaded extends ProductState {
  final List<ProductModel> products;

  const ProductLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _repository;

  ProductBloc({required ProductRepository repository})
      : _repository = repository,
        super(const ProductInitial()) {
    on<FetchProductsForCategory>(_onFetchProductsForCategory);
    on<SearchProducts>(_onSearchProducts);
  }

  Future<void> _onFetchProductsForCategory(
      FetchProductsForCategory event,
      Emitter<ProductState> emit,
      ) async {
    emit(const ProductLoading());
    try {
      final products = await _repository.getProductsByCategory(event.categoryId);
      emit(ProductLoaded(products));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onSearchProducts(
      SearchProducts event,
      Emitter<ProductState> emit,
      ) async {
    emit(const ProductLoading());
    try {
      final products = await _repository.searchProducts(event.query);
      emit(ProductLoaded(products));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }
}