import 'models/auth_models.dart';

/// PCH employee auth client. POS login wiring is deferred until PCH endpoint is live.
class AuthClient {
  Future<PosLoginResult> login(PosLoginRequest request) async {
    throw UnimplementedError(
      'AuthClient.login — PCH /v1/auth/pos-login not wired yet.',
    );
  }

  Future<bool> refreshToken() async {
    throw UnimplementedError(
      'AuthClient.refreshToken — PCH refresh not wired yet.',
    );
  }

  Future<void> logout() async {

  }
}
