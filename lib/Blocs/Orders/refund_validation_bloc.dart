import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../Models/Orders/refund_checkin_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/refund_validation_repository.dart';

abstract class RefundValidationEvent extends Equatable {
  const RefundValidationEvent();

  @override
  List<Object?> get props => [];
}

class ValidateEmployeePinEvent extends RefundValidationEvent {
  final String employeePin;

  const ValidateEmployeePinEvent(this.employeePin);

  @override
  List<Object?> get props => [employeePin];
}

abstract class RefundValidationState extends Equatable {
  const RefundValidationState();

  @override
  List<Object?> get props => [];
}

class RefundValidationInitial extends RefundValidationState {}

class RefundValidationLoading extends RefundValidationState {}

class RefundValidationSuccess extends RefundValidationState {
  final Map<String, dynamic> data;

  const RefundValidationSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

class RefundValidationFailure extends RefundValidationState {
  final String error;

  const RefundValidationFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class RefundValidationBloc
    extends Bloc<RefundValidationEvent, RefundValidationState> {
  final RefundValidationRepository repository;

  RefundValidationBloc({required this.repository})
      : super(RefundValidationInitial()) {
    on<ValidateEmployeePinEvent>(_onValidateEmployeePin);
  }

  Future<void> _onValidateEmployeePin(ValidateEmployeePinEvent event,
      Emitter<RefundValidationState> emit,) async {
    emit(RefundValidationLoading());

    try {
      final result = await repository.validateEmployeePin(
        employeePin: event.employeePin,
      );

      emit(RefundValidationSuccess(result));
    } catch (e) {
      emit(RefundValidationFailure(e.toString()));
    }
  }
}