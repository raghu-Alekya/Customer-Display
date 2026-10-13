import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth_repository.dart';
import 'models/auth_state.dart';
import 'pch_exception.dart';

class AuthBloc {
  final AuthRepository repository;
  final _controller = StreamController<AuthState>.broadcast();
  AuthState _currentState = const DeviceNotActivated();

  AuthBloc(this.repository) {
    _bootstrap();
  }

  Stream<AuthState> get stateStream => _controller.stream;
  AuthState get currentState => _currentState;

  void _emit(AuthState state) {
    _currentState = state;
    _controller.add(state);
  }

  Future<void> _bootstrap() async {
    final activated = await repository.isDeviceActivated();
    _emit(
      activated ? const Unauthenticated() : const DeviceNotActivated(),
    );
  }

  Future<void> activateDevice({
    required String activationCode,
    required String deviceFingerprint,
    required String appVersion,
    required String platform,
  }) async {
    _emit(const Authenticating());
    try {
      await repository.activateDevice(
        activationCode: activationCode,
        deviceFingerprint: deviceFingerprint,
        appVersion: appVersion,
        platform: platform,
      );
      _emit(const DeviceActivated());
    } on PchException catch (e) {
      _emit(AuthenticationFailed(message: e.message, code: e.code));
    } catch (e) {
      _emit(AuthenticationFailed(
        message: e.toString(),
        code: 'UNKNOWN_ERROR',
      ));
    }
  }

  Future<void> login(String pin) async {
    _emit(const Authenticating());

    final hasNet = await _hasInternet();
    if (!hasNet) {
      await _attemptOfflineLogin(pin);
      return;
    }

    try {
      final session = await repository.loginOnline(pin);
      _emit(Authenticated(session));
    } on PchException catch (e) {
      if (e.isNetworkError) {
        await _attemptOfflineLogin(pin);
      } else {
        _emit(AuthenticationFailed(message: e.message, code: e.code));
      }
    } on UnimplementedError {
      _emit(const AuthenticationFailed(
        message: 'PCH employee login is not available yet.',
        code: 'PCH_LOGIN_NOT_WIRED',
      ));
    } catch (_) {
      await _attemptOfflineLogin(pin);
    }
  }

  Future<void> _attemptOfflineLogin(String pin) async {
    try {
      final ok = await repository.loginOffline(pin);
      if (ok) {
        _emit(const OfflineAuthenticated());
      } else {
        _emit(const AuthenticationFailed(
          message: 'Incorrect PIN (offline)',
          code: 'OFFLINE_PIN_MISMATCH',
        ));
      }
    } on PchException catch (e) {
      _emit(AuthenticationFailed(message: e.message, code: e.code));
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result is List) {
        final list = result as List;
        if (list.isEmpty) return false;
        return !list.every((r) => r == ConnectivityResult.none);
      }
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await repository.logout();
    _emit(const Unauthenticated());
  }

  void dispose() {
    _controller.close();
  }
}
