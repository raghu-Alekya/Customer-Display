import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../Models/Orders/refund_orderlist_model.dart';
import '../../Repositories/Orders/refund_orderlist_repository.dart';

abstract class CompletedOrdersEvent extends Equatable {
  const CompletedOrdersEvent();
  @override
  List<Object?> get props => [];
}

class FetchCompletedOrders extends CompletedOrdersEvent {
  final int page;
  final int perPage;
  final int? authorId;
  final String? from;
  final String? to;

  const FetchCompletedOrders({
    required this.perPage,
    required this.page,
    this.authorId,
    this.from,
    this.to,
  });

  @override
  List<Object?> get props => [page, authorId, from, to];
}


abstract class CompletedOrdersState extends Equatable {
  const CompletedOrdersState();
  @override
  List<Object?> get props => [];
}

class CompletedOrdersInitial extends CompletedOrdersState {}

class CompletedOrdersLoading extends CompletedOrdersState {}

class CompletedOrdersLoaded extends CompletedOrdersState {
  final List<CompletedOrder> orders;

  const CompletedOrdersLoaded(this.orders);

  @override
  List<Object?> get props => [orders];
}

class CompletedOrdersError extends CompletedOrdersState {
  final String message;
  const CompletedOrdersError(this.message);

  @override
  List<Object?> get props => [message];
}

class CompletedOrdersBloc
    extends Bloc<CompletedOrdersEvent, CompletedOrdersState> {

  final CompletedOrdersRepository repository;

  CompletedOrdersBloc(this.repository)
      : super(CompletedOrdersInitial()) {
    on<FetchCompletedOrders>(_onFetchOrders);
  }

  Future<void> _onFetchOrders(
      FetchCompletedOrders event,
      Emitter<CompletedOrdersState> emit,
      ) async {
    emit(CompletedOrdersLoading());

    try {
      final orders = await repository.fetchCompletedOrders(
        page: event.page,
        perPage: event.perPage,
        // perPage: event.perPage, // ✅ use event value
      );

      emit(CompletedOrdersLoaded(orders));
    } catch (e) {
      emit(CompletedOrdersError(e.toString()));
    }
  }
}