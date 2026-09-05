// import 'dart:async';
// import 'dart:convert';
//
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:crypto/crypto.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:uuid/uuid.dart';
//
// // ---------------------------------------------------------------------------
// // Models / domain
// // ---------------------------------------------------------------------------
//
// class EmployeeSession {
//   final String userId;
//   final String accessToken;
//   final String refreshToken;
//   // Add any other fields your real session object has
//   const EmployeeSession({
//     required this.userId,
//     required this.accessToken,
//     required this.refreshToken,
//   });
// }
//
// class PosContext {
//   final String merchantId;
//   final String storeId;
//   final String deviceId;
//   final String? userId;
//
//   const PosContext({
//     required this.merchantId,
//     required this.storeId,
//     required this.deviceId,
//     this.userId,
//   });
//
//   PosContext copyWith({String? userId}) => PosContext(
//     merchantId: merchantId,
//     storeId: storeId,
//     deviceId: deviceId,
//     userId: userId ?? this.userId,
//   );
//
//   Map<String, dynamic> toJson() => {
//     'merchantId': merchantId,
//     'storeId': storeId,
//     'deviceId': deviceId,
//     'userId': userId,
//   };
//
//   factory PosContext.fromJson(Map<String, dynamic> json) => PosContext(
//     merchantId: json['merchantId'] as String,
//     storeId: json['storeId'] as String,
//     deviceId: json['deviceId'] as String,
//     userId: json['userId'] as String?,
//   );
// }
//
// class OfflineLoginPolicy {
//   final bool offlineLoginEnabled;
//   final int offlineCredentialTtlHours;
//
//   const OfflineLoginPolicy({
//     this.offlineLoginEnabled = true,
//     this.offlineCredentialTtlHours = 72,
//   });
// }
//
// // ---------------------------------------------------------------------------
// // Exceptions
// // ---------------------------------------------------------------------------
//
// class PchException implements Exception {
//   final String code;
//   final String message;
//   final String? correlationId;
//
//   const PchException({
//     required this.code,
//     required this.message,
//     this.correlationId,
//   });
//
//   factory PchException.fromResponseData(
//       dynamic data, {
//         String? fallbackCorrelationId,
//       }) {
//     if (data is Map<String, dynamic>) {
//       return PchException(
//         code: (data['code'] as String?) ?? 'UNKNOWN_ERROR',
//         message: (data['message'] as String?) ?? 'Something went wrong',
//         correlationId:
//         (data['correlationId'] as String?) ?? fallbackCorrelationId,
//       );
//     }
//     return PchException(
//       code: 'NETWORK_UNAVAILABLE',
//       message: data?.toString() ?? 'Unable to reach the server',
//       correlationId: fallbackCorrelationId,
//     );
//   }
//
//   bool get isTokenExpired => code == 'TOKEN_EXPIRED';
//   bool get isDeviceSuspended => code == 'DEVICE_SUSPENDED';
//   bool get isStoreSuspended => code == 'STORE_SUSPENDED';
//   bool get isNotAuthorized => code == 'EMPLOYEE_NOT_AUTHORIZED';
//   bool get isNetworkError => code == 'NETWORK_UNAVAILABLE';
//
//   @override
//   String toString() =>
//       'PchException($code): $message [correlationId=$correlationId]';
// }
//
// // ---------------------------------------------------------------------------
// // Auth states
// // ---------------------------------------------------------------------------
//
// sealed class AuthState {
//   const AuthState();
// }
//
// class DeviceNotActivated extends AuthState {
//   const DeviceNotActivated();
// }
//
// class DeviceActivated extends AuthState {
//   const DeviceActivated();
// }
//
// class Unauthenticated extends AuthState {
//   const Unauthenticated();
// }
//
// class Authenticating extends AuthState {
//   const Authenticating();
// }
//
// class Authenticated extends AuthState {
//   final EmployeeSession session;
//   const Authenticated(this.session);
// }
//
// class OfflineAuthenticated extends AuthState {
//   const OfflineAuthenticated();
// }
//
// class AuthenticationFailed extends AuthState {
//   final String message;
//   final String code;
//   const AuthenticationFailed({required this.message, required this.code});
// }
//
// // ---------------------------------------------------------------------------
// // Storage
// // ---------------------------------------------------------------------------
//
// class TokenStorage {
//   static const _secureStorage = FlutterSecureStorage(
//     aOptions: AndroidOptions(encryptedSharedPreferences: true),
//     iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
//   );
//
//   static const _kDeviceToken = 'pch_device_token';
//   static const _kAccessToken = 'pch_access_token';
//   static const _kRefreshToken = 'pch_refresh_token';
//   static const _kOfflinePinHash = 'pch_offline_pin_hash';
//   static const _kLastAuthenticatedAt = 'pch_last_authenticated_at';
//
//   Future<void> saveDeviceToken(String token) =>
//       _secureStorage.write(key: _kDeviceToken, value: token);
//
//   Future<String?> getDeviceToken() => _secureStorage.read(key: _kDeviceToken);
//
//   Future<void> saveTokens({
//     required String accessToken,
//     required String refreshToken,
//   }) async {
//     await _secureStorage.write(key: _kAccessToken, value: accessToken);
//     await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
//   }
//
//   Future<String?> getAccessToken() => _secureStorage.read(key: _kAccessToken);
//
//   Future<String?> getRefreshToken() => _secureStorage.read(key: _kRefreshToken);
//
//   /// Store a HASH of the PIN only — never the plaintext PIN.
//   Future<void> saveOfflinePinHash(String hash) =>
//       _secureStorage.write(key: _kOfflinePinHash, value: hash);
//
//   Future<String?> getOfflinePinHash() =>
//       _secureStorage.read(key: _kOfflinePinHash);
//
//   Future<void> saveLastAuthenticatedAt(DateTime time) => _secureStorage.write(
//     key: _kLastAuthenticatedAt,
//     value: time.toIso8601String(),
//   );
//
//   Future<DateTime?> getLastAuthenticatedAt() async {
//     final value = await _secureStorage.read(key: _kLastAuthenticatedAt);
//     if (value == null) return null;
//     return DateTime.tryParse(value);
//   }
//
//   Future<void> clearSessionTokens() async {
//     await _secureStorage.delete(key: _kAccessToken);
//     await _secureStorage.delete(key: _kRefreshToken);
//   }
//
//   Future<void> clearAll() async {
//     await _secureStorage.deleteAll();
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Context provider
// // ---------------------------------------------------------------------------
//
// abstract class PosContextProvider {
//   Future<PosContext?> getContext();
//   Future<void> saveContext(PosContext context);
//   Future<void> updateUserId(String? userId);
//   Future<void> clearUserSession();
//   Future<void> clearAll();
// }
//
// class PosContextProviderImpl implements PosContextProvider {
//   static const _kMerchantId = 'pch_merchant_id';
//   static const _kStoreId = 'pch_store_id';
//   static const _kDeviceId = 'pch_device_id';
//   static const _kUserId = 'pch_user_id';
//
//   @override
//   Future<PosContext?> getContext() async {
//     final prefs = await SharedPreferences.getInstance();
//     final merchantId = prefs.getString(_kMerchantId);
//     final storeId = prefs.getString(_kStoreId);
//     final deviceId = prefs.getString(_kDeviceId);
//
//     if (merchantId == null || storeId == null || deviceId == null) {
//       return null;
//     }
//
//     return PosContext(
//       merchantId: merchantId,
//       storeId: storeId,
//       deviceId: deviceId,
//       userId: prefs.getString(_kUserId),
//     );
//   }
//
//   @override
//   Future<void> saveContext(PosContext context) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_kMerchantId, context.merchantId);
//     await prefs.setString(_kStoreId, context.storeId);
//     await prefs.setString(_kDeviceId, context.deviceId);
//     if (context.userId != null) {
//       await prefs.setString(_kUserId, context.userId!);
//     }
//   }
//
//   @override
//   Future<void> updateUserId(String? userId) async {
//     final prefs = await SharedPreferences.getInstance();
//     if (userId == null) {
//       await prefs.remove(_kUserId);
//     } else {
//       await prefs.setString(_kUserId, userId);
//     }
//   }
//
//   @override
//   Future<void> clearUserSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_kUserId);
//   }
//
//   @override
//   Future<void> clearAll() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_kMerchantId);
//     await prefs.remove(_kStoreId);
//     await prefs.remove(_kDeviceId);
//     await prefs.remove(_kUserId);
//   }
// }
//
// // ---------------------------------------------------------------------------
// // HTTP clients (stubs – replace with real implementations)
// // ---------------------------------------------------------------------------
//
// class DeviceActivationRequest {
//   final String activationCode;
//   final String deviceFingerprint;
//   const DeviceActivationRequest({
//     required this.activationCode,
//     required this.deviceFingerprint,
//   });
// }
//
// class DeviceActivationResult {
//   final String deviceToken;
//   final String merchantId;
//   final String storeId;
//   final String deviceId;
//   const DeviceActivationResult({
//     required this.deviceToken,
//     required this.merchantId,
//     required this.storeId,
//     required this.deviceId,
//   });
// }
//
// class PosLoginRequest {
//   final String employeePin;
//   final String deviceId;
//   final String storeId;
//   const PosLoginRequest({
//     required this.employeePin,
//     required this.deviceId,
//     required this.storeId,
//   });
// }
//
// class PosLoginResult {
//   final EmployeeSession session;
//   const PosLoginResult({required this.session});
// }
//
// /// Replace these with your real clients that talk to PCH.
// class DeviceClient {
//   Future<DeviceActivationResult> activate(DeviceActivationRequest request) async {
//     // TODO: real implementation
//     throw UnimplementedError('DeviceClient.activate');
//   }
// }
//
// class AuthClient {
//   Future<PosLoginResult> login(PosLoginRequest request) async {
//     // TODO: real implementation
//     throw UnimplementedError('AuthClient.login');
//   }
//
//   Future<bool> refreshToken() async {
//     // TODO: real implementation
//     throw UnimplementedError('AuthClient.refreshToken');
//   }
//
//   Future<void> logout() async {
//     // TODO: real implementation
//   }
// }
//
// // ---------------------------------------------------------------------------
// // PchClient (Dio wrapper)
// // ---------------------------------------------------------------------------
//
// class PchClient {
//   final Dio dio;
//   final TokenStorage tokenStorage;
//   final PosContextProvider contextProvider;
//
//   AuthClient? _authClient;
//   bool _isRefreshing = false;
//   final List<Completer<void>> _refreshWaiters = [];
//
//   PchClient({
//     required String baseUrl,
//     required this.tokenStorage,
//     required this.contextProvider,
//   }) : dio = Dio(
//     BaseOptions(
//       baseUrl: baseUrl,
//       connectTimeout: const Duration(seconds: 10),
//       receiveTimeout: const Duration(seconds: 20),
//       contentType: 'application/json',
//     ),
//   ) {
//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           final token = await tokenStorage.getAccessToken();
//           final context = await contextProvider.getContext();
//
//           if (token != null) {
//             options.headers['Authorization'] = 'Bearer $token';
//           }
//           if (context != null) {
//             options.headers['X-Merchant-Id'] = context.merchantId;
//             options.headers['X-Store-Id'] = context.storeId;
//             options.headers['X-Device-Id'] = context.deviceId;
//             if (context.userId != null) {
//               options.headers['X-User-Id'] = context.userId;
//             }
//           }
//
//           options.headers['X-Correlation-Id'] =
//               options.extra['correlationId'] ?? const Uuid().v4();
//           options.headers['X-App-Version'] = '2.5.0';
//           options.headers['X-Platform'] = 'android';
//
//           handler.next(options);
//         },
//         onError: (error, handler) async {
//           final data = error.response?.data;
//           final code = data is Map ? data['code'] as String? : null;
//           final isExpired = error.response?.statusCode == 401 ||
//               code == 'TOKEN_EXPIRED';
//
//           if (isExpired && _authClient != null) {
//             final refreshed = await _refreshTokenSingleFlight();
//             if (refreshed) {
//               final request = error.requestOptions;
//               final newToken = await tokenStorage.getAccessToken();
//               request.headers['Authorization'] = 'Bearer $newToken';
//               try {
//                 final response = await dio.fetch(request);
//                 return handler.resolve(response);
//               } catch (_) {
//                 // fall through
//               }
//             }
//           }
//           handler.next(error);
//         },
//       ),
//     );
//   }
//
//   void attachAuthClient(AuthClient authClient) {
//     _authClient = authClient;
//   }
//
//   Future<bool> _refreshTokenSingleFlight() async {
//     if (_authClient == null) return false;
//
//     if (_isRefreshing) {
//       final completer = Completer<void>();
//       _refreshWaiters.add(completer);
//       await completer.future;
//       return (await tokenStorage.getAccessToken()) != null;
//     }
//
//     _isRefreshing = true;
//     try {
//       final refreshed = await _authClient!.refreshToken();
//       for (final waiter in _refreshWaiters) {
//         waiter.complete();
//       }
//       _refreshWaiters.clear();
//       return refreshed;
//     } finally {
//       _isRefreshing = false;
//     }
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Repository
// // ---------------------------------------------------------------------------
//
// class AuthRepository {
//   final AuthClient authClient;
//   final DeviceClient deviceClient;
//   final TokenStorage tokenStorage;
//   final PosContextProvider contextProvider;
//   final OfflineLoginPolicy offlinePolicy;
//
//   AuthRepository({
//     required this.authClient,
//     required this.deviceClient,
//     required this.tokenStorage,
//     required this.contextProvider,
//     this.offlinePolicy = const OfflineLoginPolicy(),
//   });
//
//   String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();
//
//   Future<PosContext?> getDeviceContext() => contextProvider.getContext();
//
//   Future<PosContext> activateDevice({
//     required String activationCode,
//     required String deviceFingerprint,
//   }) async {
//     final result = await deviceClient.activate(
//       DeviceActivationRequest(
//         activationCode: activationCode,
//         deviceFingerprint: deviceFingerprint,
//       ),
//     );
//
//     await tokenStorage.saveDeviceToken(result.deviceToken);
//
//     final context = PosContext(
//       merchantId: result.merchantId,
//       storeId: result.storeId,
//       deviceId: result.deviceId,
//     );
//     await contextProvider.saveContext(context);
//     return context;
//   }
//
//   Future<EmployeeSession> loginOnline(String pin) async {
//     final context = await contextProvider.getContext();
//     if (context == null) {
//       throw const PchException(
//         code: 'DEVICE_NOT_ACTIVATED',
//         message: 'This device has not been activated yet.',
//       );
//     }
//
//     final result = await authClient.login(
//       PosLoginRequest(
//         employeePin: pin,
//         deviceId: context.deviceId,
//         storeId: context.storeId,
//       ),
//     );
//
//     // Cache PIN hash + timestamp so offline login works later
//     await tokenStorage.saveOfflinePinHash(_hashPin(pin));
//     await tokenStorage.saveLastAuthenticatedAt(DateTime.now());
//     await contextProvider.updateUserId(result.session.userId);
//
//     return result.session;
//   }
//
//   Future<bool> canAttemptOfflineLogin() async {
//     if (!offlinePolicy.offlineLoginEnabled) return false;
//
//     final savedHash = await tokenStorage.getOfflinePinHash();
//     final lastAuth = await tokenStorage.getLastAuthenticatedAt();
//     if (savedHash == null || lastAuth == null) return false;
//
//     final age = DateTime.now().difference(lastAuth);
//     return age.inHours <= offlinePolicy.offlineCredentialTtlHours;
//   }
//
//   Future<bool> loginOffline(String pin) async {
//     final savedHash = await tokenStorage.getOfflinePinHash();
//     if (savedHash == null) {
//       throw const PchException(
//         code: 'OFFLINE_LOGIN_UNAVAILABLE',
//         message: 'No offline credentials saved. Please log in online first.',
//       );
//     }
//
//     final canOffline = await canAttemptOfflineLogin();
//     if (!canOffline) {
//       throw const PchException(
//         code: 'OFFLINE_CREDENTIALS_EXPIRED',
//         message: 'Offline login has expired. Please connect and log in online.',
//       );
//     }
//
//     return savedHash == _hashPin(pin);
//   }
//
//   Future<void> logout() async {
//     await authClient.logout();
//     await contextProvider.clearUserSession();
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Bloc
// // ---------------------------------------------------------------------------
//
// class AuthBloc {
//   final AuthRepository repository;
//   final _controller = StreamController<AuthState>.broadcast();
//
//   AuthBloc(this.repository) {
//     _bootstrap();
//   }
//
//   Stream<AuthState> get stateStream => _controller.stream;
//
//   Future<void> _bootstrap() async {
//     final context = await repository.getDeviceContext();
//     _controller.add(
//       context == null ? const DeviceNotActivated() : const Unauthenticated(),
//     );
//   }
//
//   Future<void> activateDevice({
//     required String activationCode,
//     required String deviceFingerprint,
//   }) async {
//     _controller.add(const Authenticating());
//     try {
//       await repository.activateDevice(
//         activationCode: activationCode,
//         deviceFingerprint: deviceFingerprint,
//       );
//       _controller.add(const DeviceActivated());
//     } on PchException catch (e) {
//       _controller.add(AuthenticationFailed(message: e.message, code: e.code));
//     }
//   }
//
//   Future<void> login(String pin) async {
//     _controller.add(const Authenticating());
//
//     final hasNet = await _hasInternet();
//     if (!hasNet) {
//       await _attemptOfflineLogin(pin);
//       return;
//     }
//
//     try {
//       final session = await repository.loginOnline(pin);
//       _controller.add(Authenticated(session));
//     } on PchException catch (e) {
//       if (e.isNetworkError) {
//         await _attemptOfflineLogin(pin);
//       } else {
//         _controller
//             .add(AuthenticationFailed(message: e.message, code: e.code));
//       }
//     } catch (_) {
//       await _attemptOfflineLogin(pin);
//     }
//   }
//
//   Future<void> _attemptOfflineLogin(String pin) async {
//     try {
//       final ok = await repository.loginOffline(pin);
//       if (ok) {
//         _controller.add(const OfflineAuthenticated());
//       } else {
//         _controller.add(const AuthenticationFailed(
//           message: 'Incorrect PIN (offline)',
//           code: 'OFFLINE_PIN_MISMATCH',
//         ));
//       }
//     } on PchException catch (e) {
//       _controller.add(AuthenticationFailed(message: e.message, code: e.code));
//     }
//   }
//
//   Future<bool> _hasInternet() async {
//     try {
//       final result = await Connectivity().checkConnectivity();
//       // if (result is List<ConnectivityResult>) {
//       //   if (result.isEmpty) return false;
//       //   return !result.every((r) => r == ConnectivityResult.none);
//       // }
//       return result != ConnectivityResult.none;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   Future<void> logout() async {
//     await repository.logout();
//     _controller.add(const Unauthenticated());
//   }
//
//   void dispose() {
//     _controller.close();
//   }
// }
//
//
//
// // ---------------------------------------------------------------------------
// // Mock config
// // ---------------------------------------------------------------------------
//
// class MockConfig {
//   static const bool useMockApi = true; // set to false when PCH is ready
//   static const Duration simulatedLatency = Duration(milliseconds: 900);
//
//   static const String mockInvalidActivationCode = '000000';
//   static const String mockInvalidPin = '000000';
// }
//
// // ---------------------------------------------------------------------------
// // UI – Device Activation
// // ---------------------------------------------------------------------------
//
// class DeviceActivationScreen extends StatefulWidget {
//   final AuthBloc authBloc;
//
//   const DeviceActivationScreen({super.key, required this.authBloc});
//
//   @override
//   State<DeviceActivationScreen> createState() => _DeviceActivationScreenState();
// }
//
// class _DeviceActivationScreenState extends State<DeviceActivationScreen> {
//   final List<String> _code = List.filled(6, '');
//   // TODO: replace with real device fingerprint (Sunmi serial, etc.)
//   static const String _deviceFingerprint = 'SUNMI-D3-A92F83';
//   bool _navigated = false;
//
//   void _onDigit(String value) {
//     for (int i = 0; i < _code.length; i++) {
//       if (_code[i].isEmpty) {
//         setState(() => _code[i] = value);
//         break;
//       }
//     }
//   }
//
//   void _onDelete() {
//     for (int i = _code.length - 1; i >= 0; i--) {
//       if (_code[i].isNotEmpty) {
//         setState(() => _code[i] = '');
//         break;
//       }
//     }
//   }
//
//   Future<void> _activate(String? currentError) async {
//     if (_code.any((d) => d.isEmpty)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Enter the 6-digit activation code',
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       return;
//     }
//
//     await widget.authBloc.activateDevice(
//       activationCode: _code.join(),
//       deviceFingerprint: _deviceFingerprint,
//     );
//   }
//
//   void _goToLogin() {
//     if (_navigated) return;
//     _navigated = true;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => LoginScreenV2(authBloc: widget.authBloc),
//         ),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isPortrait =
//         MediaQuery.of(context).orientation == Orientation.portrait;
//
//     return Scaffold(
//       body: StreamBuilder<AuthState>(
//         stream: widget.authBloc.stateStream,
//         builder: (context, snapshot) {
//           final state = snapshot.data;
//           final isLoading = state is Authenticating;
//
//           if (state is DeviceActivated) {
//             _goToLogin();
//           }
//
//           final errorText =
//           state is AuthenticationFailed ? state.message : null;
//
//           return Row(
//             children: [
//               // Left panel – brand
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   color: const Color(0xFF1E2745),
//                   child: Center(
//                     child: SvgPicture.asset(
//                       'assets/svg/app_logo.svg',
//                       height: 150,
//                     ),
//                   ),
//                 ),
//               ),
//               // Right panel – form
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   color: const Color(0xFFE0E0E0),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 16,
//                     ),
//                     child: SingleChildScrollView(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text(
//                             'Activate this device',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFF1E2745),
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             'Device ID: $_deviceFingerprint',
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: Colors.grey.shade700,
//                             ),
//                           ),
//                           const SizedBox(height: 24),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: List.generate(6, (index) {
//                               final paddingValue = isPortrait ? 8.5 : 12.5;
//                               return Padding(
//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: paddingValue,
//                                 ),
//                                 child: Container(
//                                   width: isPortrait ? 50.0 : 70.0,
//                                   height: isPortrait ? 50.0 : 70.0,
//                                   decoration: BoxDecoration(
//                                     color: Colors.white,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: Colors.grey.shade300,
//                                     ),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       _code[index].isEmpty ? '' : _code[index],
//                                       style: const TextStyle(
//                                         fontSize: 22,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }),
//                           ),
//                           if (errorText != null) ...[
//                             const SizedBox(height: 16),
//                             Text(
//                               errorText,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(color: Colors.red),
//                             ),
//                           ],
//                           const SizedBox(height: 32),
//                           _buildNumPad(),
//                           const SizedBox(height: 32),
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width /
//                                 (isPortrait ? 2.2 : 3.2),
//                             height: 52,
//                             child: ElevatedButton(
//                               onPressed:
//                               isLoading ? null : () => _activate(errorText),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFF1E2745),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               child: isLoading
//                                   ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: Colors.white,
//                                 ),
//                               )
//                                   : const Text(
//                                 'ACTIVATE',
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.w600),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildNumPad() {
//     return Wrap(
//       alignment: WrapAlignment.center,
//       spacing: 12,
//       runSpacing: 12,
//       children: [
//         for (var i = 1; i <= 9; i++) _numKey('$i'),
//         const SizedBox(width: 64, height: 48),
//         _numKey('0'),
//         _deleteKey(),
//       ],
//     );
//   }
//
//   Widget _numKey(String digit) {
//     return SizedBox(
//       width: 64,
//       height: 48,
//       child: OutlinedButton(
//         onPressed: () => _onDigit(digit),
//         style: OutlinedButton.styleFrom(
//           backgroundColor: Colors.white,
//           shape:
//           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//         child: Text(
//           digit,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }
//
//   Widget _deleteKey() {
//     return SizedBox(
//       width: 64,
//       height: 48,
//       child: OutlinedButton(
//         onPressed: _onDelete,
//         style: OutlinedButton.styleFrom(
//           backgroundColor: Colors.white,
//           shape:
//           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//         child: const Icon(Icons.backspace_outlined, size: 18),
//       ),
//     );
//   }
// }
//
// // ---------------------------------------------------------------------------
// // UI – Login
// // ---------------------------------------------------------------------------
//
// class LoginScreenV2 extends StatefulWidget {
//   final AuthBloc authBloc;
//
//   const LoginScreenV2({super.key, required this.authBloc});
//
//   @override
//   State<LoginScreenV2> createState() => _LoginScreenV2State();
// }
//
// class _LoginScreenV2State extends State<LoginScreenV2> {
//   final List<String> _pin = List.filled(6, '');
//   bool _navigated = false;
//
//   void _onDigit(String value) {
//     for (int i = 0; i < _pin.length; i++) {
//       if (_pin[i].isEmpty) {
//         setState(() => _pin[i] = value);
//         break;
//       }
//     }
//   }
//
//   void _onDelete() {
//     for (int i = _pin.length - 1; i >= 0; i--) {
//       if (_pin[i].isNotEmpty) {
//         setState(() => _pin[i] = '');
//         break;
//       }
//     }
//   }
//
//   void _clear() => setState(() => _pin.setAll(0, List.filled(6, '')));
//
//   Future<void> _submit() async {
//     if (_pin.any((d) => d.isEmpty)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Please enter 6-digit PIN',
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       return;
//     }
//     await widget.authBloc.login(_pin.join());
//   }
//
//   void _goHome() {
//     if (_navigated) return;
//     _navigated = true;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const POSHomePlaceholder()),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isPortrait =
//         MediaQuery.of(context).orientation == Orientation.portrait;
//
//     return Scaffold(
//       body: StreamBuilder<AuthState>(
//         stream: widget.authBloc.stateStream,
//         builder: (context, snapshot) {
//           final state = snapshot.data;
//           final isLoading = state is Authenticating;
//           final isOffline = state is OfflineAuthenticated;
//
//           if (state is Authenticated || state is OfflineAuthenticated) {
//             _goHome();
//           }
//
//           final errorText =
//           state is AuthenticationFailed ? state.message : null;
//
//           return Row(
//             children: [
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   color: const Color(0xFF1E2745),
//                   child: Center(
//                     child: SvgPicture.asset(
//                       'assets/svg/app_logo.svg',
//                       height: 150,
//                     ),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   color: const Color(0xFFE0E0E0),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 16,
//                     ),
//                     child: SingleChildScrollView(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           if (isOffline)
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: 12),
//                               child: Text(
//                                 'Offline mode — logged in with saved PIN',
//                                 style: TextStyle(
//                                   color: Colors.orange.shade800,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 13,
//                                 ),
//                               ),
//                             ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: List.generate(6, (index) {
//                               final paddingValue = isPortrait ? 8.5 : 12.5;
//                               return Padding(
//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: paddingValue,
//                                 ),
//                                 child: Container(
//                                   width: isPortrait ? 50.0 : 70.0,
//                                   height: isPortrait ? 50.0 : 70.0,
//                                   decoration: BoxDecoration(
//                                     color: Colors.white,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: Colors.grey.shade300,
//                                     ),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       _pin[index].isEmpty ? '' : '•',
//                                       style: const TextStyle(
//                                         fontSize: 24,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }),
//                           ),
//                           if (errorText != null) ...[
//                             const SizedBox(height: 16),
//                             Text(
//                               errorText,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(color: Colors.red),
//                             ),
//                           ],
//                           const SizedBox(height: 32),
//                           _buildNumPad(),
//                           const SizedBox(height: 32),
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width /
//                                 (isPortrait ? 2.2 : 3.2),
//                             height: 52,
//                             child: ElevatedButton(
//                               onPressed: isLoading ? null : _submit,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFF1E2745),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               child: isLoading
//                                   ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: Colors.white,
//                                 ),
//                               )
//                                   : const Text(
//                                 'LOGIN',
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.w600),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildNumPad() {
//     return Wrap(
//       alignment: WrapAlignment.center,
//       spacing: 12,
//       runSpacing: 12,
//       children: [
//         for (var i = 1; i <= 9; i++) _numKey('$i'),
//         SizedBox(
//           width: 64,
//           height: 48,
//           child: OutlinedButton(
//             onPressed: _clear,
//             style: OutlinedButton.styleFrom(
//               backgroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child: const Text('C',
//                 style: TextStyle(fontWeight: FontWeight.w600)),
//           ),
//         ),
//         _numKey('0'),
//         SizedBox(
//           width: 64,
//           height: 48,
//           child: OutlinedButton(
//             onPressed: _onDelete,
//             style: OutlinedButton.styleFrom(
//               backgroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child: const Icon(Icons.backspace_outlined, size: 18),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _numKey(String digit) {
//     return SizedBox(
//       width: 64,
//       height: 48,
//       child: OutlinedButton(
//         onPressed: () => _onDigit(digit),
//         style: OutlinedButton.styleFrom(
//           backgroundColor: Colors.white,
//           shape:
//           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//         child: Text(
//           digit,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Placeholder home screen
// // ---------------------------------------------------------------------------
//
// class POSHomePlaceholder extends StatelessWidget {
//   const POSHomePlaceholder({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFE0E0E0),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.check_circle,
//                 color: Color(0xFF1E2745), size: 64),
//             const SizedBox(height: 16),
//             const Text(
//               'Login successful',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF1E2745),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Wire this up to your real POSHomeScreen',
//               style: TextStyle(color: Colors.grey.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


//////////==========


import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pinaka_pos/Screens/Auth/store_id_screen.dart';
import '../../Widgets/widget_custom_num_pad.dart';

class DeviceAuthorizationScreen extends StatefulWidget {
  const DeviceAuthorizationScreen({super.key});

  @override
  State<DeviceAuthorizationScreen> createState() =>
      _DeviceAuthorizationScreenState();
}

class _DeviceAuthorizationScreenState extends State<DeviceAuthorizationScreen> {
  final List<String> _pin = List.filled(6, "");
  final TextEditingController _pinController = TextEditingController();

  // ---------------------------------------------------------------------------
  // PIN HELPERS
  // ---------------------------------------------------------------------------
  void _updatePin(String value) {
    for (int i = 0; i < _pin.length; i++) {
      if (_pin[i].isEmpty) {
        setState(() => _pin[i] = value);
        break;
      }
    }
  }

  void _deletePin() {
    for (int i = _pin.length - 1; i >= 0; i--) {
      if (_pin[i].isNotEmpty) {
        setState(() => _pin[i] = "");
        break;
      }
    }
  }

  void _clearPin() {
    setState(() {
      for (int i = 0; i < _pin.length; i++) {
        _pin[i] = "";
      }
      _pinController.clear();
    });
  }

  bool _validatePin() {
    if (_pin.any((digit) => digit.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter 6-digit Activation Code',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // DEVICE INFO + SUBMIT
  // ---------------------------------------------------------------------------
  Future<String> _getDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.userAgent ?? 'WEB-UNKNOWN';
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return '${android.model}-${android.id}'.replaceAll(' ', '-');
      } else if (Platform.isWindows) {
        final windows = await deviceInfo.windowsInfo;
        return windows.deviceId ?? windows.computerName;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return ios.identifierForVendor ?? ios.model;
      } else if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        return mac.systemGUID ?? mac.model;
      } else if (Platform.isLinux) {
        final linux = await deviceInfo.linuxInfo;
        return linux.machineId ?? linux.name;
      }
    } catch (e) {
      if (kDebugMode) print('Device fingerprint error: $e');
    }
    return 'UNKNOWN-DEVICE';
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '2.5.0';
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isWindows) return 'WINDOWS';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isMacOS) return 'MACOS';
    if (Platform.isLinux) return 'LINUX';
    return 'UNKNOWN';
  }

  Future<void> _handleSubmit() async {
    if (!_validatePin()) return;

    final activationCode = _pin.join();
    final deviceFingerprint = await _getDeviceFingerprint();
    final appVersion = await _getAppVersion();
    final platform = _getPlatform();

    final payload = {
      "activationCode": activationCode,
      "deviceFingerprint": deviceFingerprint,
      "appVersion": appVersion,
      "platform": platform,
    };

    if (kDebugMode) {
      print('📱 Device Authorization Payload:');
      print(payload);
      print('''
{
  "activationCode": "$activationCode",
  "deviceFingerprint": "$deviceFingerprint",
  "appVersion": "$appVersion",
  "platform": "$platform"
}
''');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StoreIdScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      body: Row(
        children: [
          // Left Side - Logo
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF1E2745),
              child: Center(
                child: SvgPicture.asset(
                  'assets/svg/app_logo.svg',
                  height: 150,
                ),
              ),
            ),
          ),

          // Right Side - Authorization Form
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFE0E0E0),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Device Authorization',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2745),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter 6-digit Activation Code',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ========== SINGLE TEXT FIELD (changed part) ==========
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 12,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              letterSpacing: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF1E2745),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            final digits = value.padRight(6, '').split('');
                            setState(() {
                              for (int i = 0; i < 6; i++) {
                                _pin[i] =
                                i < digits.length ? digits[i] : '';
                              }
                            });
                          },
                        ),
                      ),
                      // ======================================================

                      const SizedBox(height: 32),

                      // NumPad (still works with the TextField)
                      CustomNumPad(
                        numPadType: NumPadType.login,
                        onDigitPressed: (digit) {
                          if (_pinController.text.length < 6) {
                            _pinController.text += digit;
                            _updatePin(digit);
                          }
                        },
                        onClearPressed: _clearPin,
                        onDeletePressed: () {
                          if (_pinController.text.isNotEmpty) {
                            _pinController.text = _pinController.text
                                .substring(0, _pinController.text.length - 1);
                            _deletePin();
                          }
                        },
                        actionButtonType: ActionButtonType.delete,
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: MediaQuery.of(context).size.width /
                            (isPortrait ? 7.3 : 7.2),
                        height: MediaQuery.of(context).size.height /
                            (isPortrait ? 20.0 : 10.0),
                        child: ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2745),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Authorize Device',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Back to Login
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '← Back to Login',
                          style: TextStyle(
                            color: Color(0xFF1E2745),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}