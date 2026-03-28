import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/user_login.dart';
import '../repository/user_login_repository.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginWithPinEvent extends AuthEvent {
  final String pin;

  LoginWithPinEvent(this.pin);

  @override
  List<Object?> get props => [pin];
}

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final UserData user;

  AuthSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthFailure extends AuthState {
  final String error;

  AuthFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc(this.repository) : super(AuthInitial()) {
    on<LoginWithPinEvent>((event, emit) async {
      emit(AuthLoading());

      try {
        final response = await repository.loginWithPin(event.pin);
        // AuthSession.token = response.data.token;
        emit(AuthSuccess(response.data));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });
  }
}