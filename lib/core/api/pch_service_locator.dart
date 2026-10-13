import 'auth_bloc.dart';
import 'auth_client.dart';
import 'auth_repository.dart';
import 'device_client.dart';
import 'pch_client.dart';
import 'pch_config.dart';
import 'pos_context_provider.dart';
import 'token_storage.dart';

/// Lightweight factory for PCH SDK wiring used by DeviceAuthorizationScreen.
class PchServiceLocator {
  PchServiceLocator._();

  static final TokenStorage tokenStorage = TokenStorage();
  static final PosContextProvider contextProvider = PosContextProviderImpl();

  static AuthBloc createAuthBloc({
    String? appVersion,
    String? platform,
  }) {
    final pchClient = PchClient(
      baseUrl: PchConfig.baseUrl,
      tokenStorage: tokenStorage,
      contextProvider: contextProvider,
      appVersion: appVersion,
      platform: platform,
    );

    final authClient = AuthClient();
    pchClient.attachAuthClient(authClient);

    final deviceClient = DeviceClient(pchClient);

    final repository = AuthRepository(
      authClient: authClient,
      deviceClient: deviceClient,
      tokenStorage: tokenStorage,
      contextProvider: contextProvider,
    );

    return AuthBloc(repository);
  }
}
