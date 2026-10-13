import 'auth_models.dart';

sealed class AuthState {
  const AuthState();
}

class DeviceNotActivated extends AuthState {
  const DeviceNotActivated();
}

class DeviceActivated extends AuthState {
  const DeviceActivated();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticating extends AuthState {
  const Authenticating();
}

class Authenticated extends AuthState {
  final EmployeeSession session;
  const Authenticated(this.session);
}

class OfflineAuthenticated extends AuthState {
  const OfflineAuthenticated();
}

class AuthenticationFailed extends AuthState {
  final String message;
  final String code;
  const AuthenticationFailed({required this.message, required this.code});
}
