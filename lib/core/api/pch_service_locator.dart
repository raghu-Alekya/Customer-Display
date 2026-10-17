import 'pch_client.dart';
import 'pch_config.dart';
import 'pos_context_provider.dart';
import 'token_storage.dart';

/// Lightweight factory for PCH wiring used by attendance and device auth.
class PchServiceLocator {
  PchServiceLocator._();

  static final TokenStorage tokenStorage = TokenStorage();
  static final PosContextProvider contextProvider = PosContextProviderImpl();

  /// Shared PCH HTTP client for attendance APIs (connector base URL).
  static PchClient createPchClient({
    String? appVersion,
    String? platform,
  }) {
    return PchClient(
      baseUrl: PchConfig.attendanceBaseUrl,
      tokenStorage: tokenStorage,
      contextProvider: contextProvider,
      appVersion: appVersion,
      platform: platform,
    );
  }
}
