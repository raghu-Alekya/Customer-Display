import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/login_model.dart';
import '../repository/login_repository.dart';
import '../utils/appconstant.dart';

// EVENTS
abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final String username;
  final String password;
  final String storeId;

  const LoginSubmitted({
    required this.username,
    required this.password,
    required this.storeId,
  });

  @override
  List<Object?> get props => [username, password, storeId];
}

// STATES
abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final LoginResponse response;

  const LoginSuccess(this.response);

  @override
  List<Object?> get props => [response];
}

class LoginFailure extends LoginState {
  final String error;

  const LoginFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// BLOC
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginRepository repository;

  LoginBloc(this.repository) : super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
      LoginSubmitted event,
      Emitter<LoginState> emit,
      ) async {
    emit(LoginLoading());

    try {
      final response = await repository.login(
        username: event.username,
        password: event.password,
        storeId: event.storeId,
      );

      if (response.success) {
        // Set dynamic base domain
        AppConstants.baseDomain = response.storeBaseUrl;

        print("Base Domain: ${AppConstants.baseDomain}");
        print("Base URL: ${AppConstants.baseUrl}");

        emit(LoginSuccess(response));
      } else {
        emit(LoginFailure(response.message));
      }
    } catch (e) {
      emit(const LoginFailure("Something went wrong"));
    }
  }
}