import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Blocs/Auth/logout_bloc.dart';
import '../../Blocs/Auth/shift_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/shift_db_helper.dart'; // ✅ Added for offline shift storage
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/text_extensions.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Models/Assets/asset_model.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/logout_repository.dart';
import '../../Repositories/Auth/shift_repository.dart';
import '../../Widgets/SafeStorageHelper.dart';
import '../../Widgets/widget_alert_popup_dialogs.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../Auth/login_screen.dart';
import 'pos_home_screen.dart';
import 'safe_open_screen.dart';

class ShiftOpenCloseBalanceScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  const ShiftOpenCloseBalanceScreen({super.key, this.lastSelectedIndex});

  @override
  State<ShiftOpenCloseBalanceScreen> createState() =>
      _ShiftOpenCloseBalanceScreenState();
}

class _ShiftOpenCloseBalanceScreenState
    extends State<ShiftOpenCloseBalanceScreen> with LayoutSelectionMixin {
  bool isLoading = true;
  int _selectedSidebarIndex = 4;

  List<Denom> _notesDenominations = [];
  List<Denom> _coinsDenominations = [];
  String? _shiftId;
  String screenTitle = TextConstants.shiftOpen;
  String? _originScreen;
  final PinakaPreferences _preferences = PinakaPreferences();
  late ShiftBloc _shiftBloc;
  double totalAmount = 0.0;
  double cashTubes = 0.0;
  double cashNotesCoin = 0.0;
  final List<Map<String, dynamic>> denominations = [];
  StreamSubscription? _shiftSubscription;
  bool _isSubmitting = false;
  final logoutBloc = LogoutBloc(LogoutRepository());
  bool _isSafeEnabled = false;

  // ========== OFFLINE SHIFT SUPPORT (Pattern from LoginScreen) ==========
  bool _isOfflineMode = false;
  bool _hasErrorShown = false;
  // =====================================================================

  @override
  void initState() {
    super.initState();
    _loadSafeEnable();
    _shiftBloc = ShiftBloc(ShiftRepository());
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    _checkShiftId();
    _checkConnectivityOnOpen(); // ✅ Check network on startup

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPreviousScreen();
    });

    _fetchDenominations();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });

    _controllers.forEach((denom, controller) {
      controller.addListener(() => _updateTotal(denom, controller));
    });

    _coinControllers.forEach((denom, controller) {
      controller.addListener(() => _updateCoinTotal(denom, controller));
    });
  }

  // ---------------------------------------------------------------------------
  // CONNECTIVITY HELPERS (Identical to LoginScreen)
  // ---------------------------------------------------------------------------

  Future<void> _checkConnectivityOnOpen() async {
    final hasNet = await _hasInternet();
    if (!mounted) return;
    setState(() {
      _isOfflineMode = !hasNet;
    });
    if (kDebugMode) {
      print('🌐 ShiftScreen open → internet: $hasNet | offlineMode: $_isOfflineMode');
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
    } catch (e) {
      if (kDebugMode) print('🌐 connectivity check error: $e');
      return false;
    }
  }

  bool _isServerOrNetworkError(String? message) {
    if (message == null) return true;
    final m = message.toLowerCase();
    // Authentication/business rejections must stay visible; treating a 403 as
    // offline would mark a server shift closed even though the API rejected it.
    return m.contains('404') ||
        m.contains('500') ||
        m.contains('502') ||
        m.contains('503') ||
        m.contains('504') ||
        m.contains('timeout') ||
        m.contains('socket') ||
        m.contains('connection') ||
        m.contains('network') ||
        m.contains('failed host') ||
        m.contains('unreachable') ||
        m.contains('http') ||
        m.contains('an error occurred');
  }

  // ---------------------------------------------------------------------------
  // OFFLINE SHIFT EXECUTION HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _tryOfflineOpenShift(ShiftRequest request) async {
    try {
      final userDbHelper = UserDbHelper();
      // final userId = await userDbHelper.getUserId() ?? 1;
// ❌ Replace this:
// final userId = await userDbHelper.getUserId() ?? 1;

// ✅ With this:
      final userId = await _getLoggedInUserId();
      // 1. Create Shift Locally in SQLite
      final localShiftId = await ShiftDbHelper().createShiftOffline(
        userId: userId,
        openingBalance: totalAmount,
        requestPayload: request.toJson(),
      );

      // 2. Save active localShiftId for POS orders
      await userDbHelper.updateUserShiftId(localShiftId);

      if (kDebugMode) {
        print('✅ [OfflineShift] Shift opened offline with Local ID: $localShiftId');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Shift opened offline. Transactions will sync automatically when online.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // 3. Show Start Shift Dialog
      bool? result = await CustomDialog.showStartShiftVerification(
        context,
        totalAmount: totalAmount,
        overShort: 0.0,
      );

      if (result == true && mounted) {
        _resetState();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const POSHomeScreen()),
              (_) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ [OfflineShift] Open error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open shift offline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _tryOfflineCloseShift(int shiftId, ShiftRequest closeRequest) async {
    try {
      // 1. Verification Dialog
      bool? confirmClose = await CustomDialog.showCloseShiftVerification(
        context,
        totalAmount: totalAmount,
        overShort: 0.0,
      );

      if (confirmClose != true) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // 2. Close Shift Locally in SQLite
      final result = await ShiftDbHelper().closeShiftByLocalOrServerId(
        shiftId: shiftId,
        userId: await _getLoggedInUserId(),
        closingBalance: totalAmount,
        closePayload: closeRequest.toJson(),
      );

      if (kDebugMode) {
        print('✅ [OfflineShift] Shift closed offline: $result');
      }

      // 3. Clear active shift ID
      await UserDbHelper().updateUserShiftId(null);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Shift closed offline. Reconciliation will sync when connected.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // 4. Logout / Navigate to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (kDebugMode) print('❌ [OfflineShift] Close error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close shift offline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // EXISTING DENOMINATION HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _loadSafeEnable() async {
    _isSafeEnabled = await SafeStorageHelper.getSafeEnable();
    if (mounted) setState(() {});
  }
  Future<int> _getLoggedInUserId() async {
    try {
      final userHelper = UserDbHelper();
      dynamic userData;

      // Safely check whichever method exists in your UserDbHelper
      try {
        userData = await (userHelper as dynamic).getUserDetails();
      } catch (_) {
        try {
          userData = await (userHelper as dynamic).getUserData();
        } catch (_) {
          try {
            userData = await (userHelper as dynamic).getUser();
          } catch (_) {}
        }
      }

      if (userData != null) {
        if (userData is Map) {
          final id = userData['id'] ?? userData['user_id'] ?? userData['userId'];
          if (id != null) return int.tryParse(id.toString()) ?? 1;
        } else {
          final id = userData.id ?? userData.userId;
          if (id != null) return int.tryParse(id.toString()) ?? 1;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Could not fetch user ID: $e');
    }
    return 1; // Fallback default user ID
  }
  void _resetState() {
    if (kDebugMode) {
      print("Resetting ShiftOpenCloseBalanceScreen state");
    }
    _clearCounts();
    _controllers.forEach((key, controller) => controller.clear());
    _coinControllers.forEach((key, controller) => controller.clear());
    setState(() {
      _noteTotals.updateAll((key, value) => 0.0);
      _coinTotals.updateAll((key, value) => 0.0);
      _grandTotal = 0.0;
    });
  }

  Future<void> _checkShiftId() async {
    int? shiftId = await UserDbHelper().getUserShiftId();
    if (shiftId != null) {
      _shiftId = shiftId.toString();
    }
    if (kDebugMode) {
      print("#### _checkShiftId: $_shiftId");
    }
  }

  void _checkPreviousScreen() {
    final previousScreen =
    ModalRoute.of(context)?.settings.arguments as String?;
    _originScreen = previousScreen;
    _resetState();
    if (previousScreen == TextConstants.navLogout) {
      setState(() {
        screenTitle = TextConstants.shiftClose;
      });
    } else if (previousScreen == TextConstants.navShiftHistory) {
      setState(() {
        screenTitle = TextConstants.shiftBal;
      });
    }
  }

  Future<void> _fetchDenominations() async {
    if (kDebugMode) {
      print("Fetching denominations from AssetDBHelper...");
    }
    _notesDenominations = await AssetDBHelper.instance.getNotesDenomList();
    _coinsDenominations = await AssetDBHelper.instance.getCoinDenomList();

    setState(() {
      for (var denom in _notesDenominations) {
        _coinDenominations[denom.denom.toString()] = double.parse(denom.denom);
        _noteTotals[denom.denom.toString()] = 0.0;
        _controllers[denom.denom.toString()] = TextEditingController();
        _controllers[denom.denom.toString()]!.addListener(() =>
            _updateTotal(denom.denom.toString(), _controllers[denom.denom.toString()]!));
      }

      for (var denom in _coinsDenominations) {
        _coinDenominations[denom.denom.toString()] = double.parse(denom.denom);
        _coinTotals[denom.denom.toString()] = 0.0;
        _coinControllers[denom.denom.toString()] = TextEditingController();
        _coinControllers[denom.denom.toString()]!.addListener(() =>
            _updateCoinTotal(denom.denom.toString(), _coinControllers[denom.denom.toString()]!));
      }
    });
  }

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _coinControllers = {};

  final Map<String, double> _noteDenominations = {
    '100': 100.0,
    '50': 50.0,
    '20': 20.0,
    '10': 10.0,
    '5': 5.0,
    '2': 2.0,
    '1': 1.0,
  };

  final Map<String, double> _noteTotals = {
    '100': 0.0,
    '50': 0.0,
    '20': 0.0,
    '10': 0.0,
    '5': 0.0,
    '2': 0.0,
    '1': 0.0,
  };

  final Map<String, double> _coinDenominations = {
    '0.50': 0.50,
    '0.25': 0.25,
    '0.10': 0.10,
    '0.05': 0.05,
  };

  final Map<String, double> _coinTotals = {
    '0.50': 0.0,
    '0.25': 0.0,
    '0.10': 0.0,
    '0.05': 0.0,
  };

  double _grandTotal = 0.0;

  void _updateTotal(String denomination, TextEditingController controller) {
    setState(() {
      final int count = int.tryParse(controller.text) ?? 0;
      final double value = double.tryParse(denomination) ?? 0.0;
      _noteTotals[denomination] = count * value;
      _calculateGrandTotal();
    });
  }

  void _updateCoinTotal(String denomination, TextEditingController controller) {
    setState(() {
      final int count = int.tryParse(controller.text) ?? 0;
      final double value = double.tryParse(denomination) ?? 0.0;
      _coinTotals[denomination] = count * value;
      _calculateGrandTotal();
    });
  }

  ShiftRequest _buildShiftRequest({int? shiftId, String? status}) {
    List<Denomination> drawerDenoms = [];

    for (var denom in _notesDenominations) {
      int count =
          int.tryParse(_controllers[denom.denom.toString()]?.text ?? '0') ?? 0;
      drawerDenoms.add(Denomination(
          denomination: num.tryParse(denom.denom.toString()) ?? 0,
          denomCount: count));
    }
    for (var denom in _coinsDenominations) {
      int count =
          int.tryParse(_coinControllers[denom.denom.toString()]?.text ?? '0') ?? 0;
      drawerDenoms.add(Denomination(
          denomination: num.tryParse(denom.denom.toString()) ?? 0,
          denomCount: count));
    }

    List<TubeDenomination> tubeDenoms = [];
    for (var denom in denominations) {
      tubeDenoms.add(TubeDenomination(
        denomination: denom['denomValue'],
        tubeCount: denom['tubeCount'],
        cellCount: denom['tubeCount'],
        total: denom['amount'],
      ));
    }

    return ShiftRequest(
      shiftId: shiftId,
      status: status,
      drawerDenominations: drawerDenoms,
      drawerTotalAmount: cashNotesCoin,
      tubeDenominations: tubeDenoms,
      tubeTotalAmount: cashTubes,
      totalAmount: totalAmount,
    );
  }

  // ---------------------------------------------------------------------------
  // SUBMISSION LOGIC (With Offline-First Pattern Matching LoginScreen)
  // ---------------------------------------------------------------------------

  Future<void> _handleShiftSubmit({bool navigateNext = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _hasErrorShown = false;

    // Check connectivity first (Same as LoginScreen._handleLogin)
    final hasNet = await _hasInternet();
    if (!mounted) return;
    setState(() {
      _isOfflineMode = !hasNet;
    });

    int? shiftId = await UserDbHelper().getUserShiftId();
    String? previousScreen = _originScreen;

    String status = TextConstants.open;
    String? closeShiftStatus;

    if (shiftId != null) {
      if (previousScreen == TextConstants.navLogout) {
        status = TextConstants.update;
        closeShiftStatus = TextConstants.closed;
      } else if (previousScreen == TextConstants.navShiftHistory) {
        status = TextConstants.update;
      }
    }

    final request = _buildShiftRequest(
      shiftId: shiftId,
      status: status,
    );

    // =========================================================================
    // 1. NO INTERNET → DIRECT OFFLINE HANDLING (No API call)
    // =========================================================================
    if (!hasNet) {
      if (kDebugMode) {
        print('📵 No internet → Executing shift operation completely offline');
      }
      if (closeShiftStatus != null && shiftId != null) {
        final closeRequest = _buildShiftRequest(
          shiftId: shiftId,
          status: TextConstants.closed,
        );
        await _tryOfflineCloseShift(shiftId, closeRequest);
      } else {
        await _tryOfflineOpenShift(request);
      }
      return;
    }

    // =========================================================================
    // 2. ONLINE → API SUBMISSION WITH AUTOMATIC OFFLINE FALLBACK
    // =========================================================================
    var progressDialogShown = false;
    void dismissSubmitProgress() {
      if (!progressDialogShown || !mounted) return;
      progressDialogShown = false;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    }

    try {
      await _shiftSubscription?.cancel();
      _shiftBloc.manageShift(request);

      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        progressDialogShown = true;
      }

      bool dialogShown = false;

      _shiftSubscription = _shiftBloc.shiftStream.listen((response) async {
        if (!mounted || dialogShown) return;

        // ---------- SUCCESS ----------
        if (response.status == Status.COMPLETED) {
          dialogShown = true;
          dismissSubmitProgress();
          setState(() => _isSubmitting = false);

          // OPEN / UPDATE
          if (closeShiftStatus == null) {
            bool? result;

            if (status == TextConstants.open) {
              await UserDbHelper().updateUserShiftId(response.data!.shiftId);

              result = await CustomDialog.showStartShiftVerification(
                context,
                totalAmount: totalAmount,
                overShort: response.data!.overShort.toDouble(),
              );
            } else {
              result = await CustomDialog.showUpdateShiftVerification(
                context,
                totalAmount: totalAmount,
                overShort: response.data!.overShort.toDouble(),
              );
            }

            if (result == true && mounted) {
              _resetState();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const POSHomeScreen()),
                    (_) => false,
              );
            }
            return;
          }

          // CLOSE SHIFT
          bool? confirmClose = await CustomDialog.showCloseShiftVerification(
            context,
            totalAmount: totalAmount,
            overShort: response.data!.overShort.toDouble(),
          );

          if (confirmClose != true) return;

          CustomDialog.showCloseShiftVerification(
            context,
            totalAmount: totalAmount,
            overShort: response.data!.overShort.toDouble(),
            isLoading: true,
          );

          await _shiftSubscription?.cancel();

          final closeRequest = _buildShiftRequest(
            shiftId: shiftId,
            status: TextConstants.closed,
          );
          _calculateGrandTotal();

          _shiftBloc.manageShift(closeRequest);

          _shiftSubscription =
              _shiftBloc.shiftStream.listen((closeResponse) async {
                if (closeResponse.status == Status.COMPLETED) {
                  await UserDbHelper().updateUserShiftId(null);
                  logoutBloc.performLogout();

                  StreamSubscription? logoutSub;
                  logoutSub = logoutBloc.logoutStream.listen((logoutResponse) {
                    if (logoutResponse.status == Status.COMPLETED && mounted) {
                      logoutSub?.cancel();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  });
                }
              });
        }

        // ---------- ERROR / OFFLINE FALLBACK ----------
        if (response.status == Status.ERROR) {
          dismissSubmitProgress();
          setState(() => _isSubmitting = false);

          final errorMsg = response.message;
          if (kDebugMode) {
            print("⚠️ Shift API Error: $errorMsg");
          }

          // SERVER / NETWORK ERROR → FALLBACK TO OFFLINE LOCAL STORAGE (Like LoginScreen)
          // Opening a shift must remain available when the server rejects an
          // old/offline token with 403.  Closing is deliberately excluded:
          // a rejected close must not be marked as closed locally.
          final canOpenOffline = status == TextConstants.open &&
              (errorMsg?.toLowerCase().contains('403') ?? false);
          if (_isServerOrNetworkError(errorMsg) || canOpenOffline) {
            if (!_hasErrorShown) {
              _hasErrorShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                setState(() {
                  _isOfflineMode = true;
                });
                if (kDebugMode) {
                  print('⚠️ Network error during API call → falling back to offline execution');
                }

                if (closeShiftStatus != null && shiftId != null) {
                  final closeRequest = _buildShiftRequest(
                    shiftId: shiftId,
                    status: TextConstants.closed,
                  );
                  await _tryOfflineCloseShift(shiftId, closeRequest);
                } else {
                  await _tryOfflineOpenShift(request);
                }
              });
            }
            return;
          }

          // Real Business / Validation error from API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? TextConstants.failedToUpdateShift),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      dismissSubmitProgress();
      setState(() => _isSubmitting = false);
      if (kDebugMode) print("Submit error: $e");
    }
  }

  void _calculateGrandTotal() {
    final double noteTotal = _noteTotals.values.fold(0.0, (a, b) => a + b);
    final double coinTotal = _coinTotals.values.fold(0.0, (a, b) => a + b);

    cashNotesCoin = noteTotal + coinTotal;
    totalAmount = cashNotesCoin + cashTubes;
    _grandTotal = cashNotesCoin;
  }

  void _clearCounts() {
    _controllers.forEach((key, controller) => controller.clear());
    _coinControllers.forEach((key, controller) => controller.clear());

    setState(() {
      _noteTotals.updateAll((key, value) => 0.0);
      _coinTotals.updateAll((key, value) => 0.0);
      _grandTotal = 0.0;
    });
  }

  TextEditingController _getControllerForDenomination(String denomination) {
    return _controllers[denomination] ?? TextEditingController();
  }

  TextEditingController _getControllerForCoinDenomination(String denomination) {
    return _coinControllers[denomination] ?? TextEditingController();
  }

  @override
  void dispose() {
    _shiftSubscription?.cancel();
    _shiftBloc.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    _coinControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Widget _loadSvg(String path, double height, double width) {
    if (path.startsWith('http')) {
      return SvgPicture.network(
        path,
        height: height,
        width: width,
        placeholderBuilder: (context) => SvgPicture.asset(
          'assets/svg/1.svg',
          height: height,
          width: width,
        ),
      );
    } else {
      return SvgPicture.asset(
        path,
        height: height,
        width: width,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previousScreen =
    ModalRoute.of(context)?.settings.arguments as String?;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              screen: Screen.SHIFT,
              onModeChanged: () async {
                String newLayout;
                if (sidebarPosition == SidebarPosition.left) {
                  newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
                } else if (sidebarPosition == SidebarPosition.right) {
                  newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
                } else {
                  newLayout = orderPanelPosition == OrderPanelPosition.left
                      ? SharedPreferenceTextConstants.navBottomOrderRight
                      : SharedPreferenceTextConstants.navLeftOrderRight;
                }

                PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                await UserDbHelper().saveUserSettings(
                    {AppDBConst.layoutSelection: newLayout},
                    modeChange: true);
                setState(() {});
              },
            ),
            const Divider(color: Colors.grey, thickness: 0.4, height: 1),
            Expanded(
              child: Row(
                children: [
                  if (sidebarPosition == SidebarPosition.left)
                    custom_widgets.NavigationBar(
                      selectedSidebarIndex: _selectedSidebarIndex,
                      onSidebarItemSelected: (index) {
                        setState(() {
                          _selectedSidebarIndex = index;
                        });
                      },
                      isVertical: true,
                      isShiftScreen: true,
                    ),

                  Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.primaryBackground
                                : Colors.white,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16, right: 16, left: 16),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            screenTitle,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            TextConstants.shiftSubTitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          // ========== OFFLINE BANNER (Like LoginScreen) ==========
                                          if (_isOfflineMode)
                                            Padding(
                                              padding:
                                              const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Offline mode — shift will be saved locally',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          // ========================================================
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.06,
                                            width: MediaQuery.of(context)
                                                .size
                                                .width *
                                                0.1,
                                            child: OutlinedButton(
                                              onPressed: ((_shiftId == null ||
                                                  _shiftId!.isEmpty) &&
                                                  (previousScreen !=
                                                      TextConstants
                                                          .navCashier))
                                                  ? null
                                                  : () {
                                                CustomDialog.showAreYouSure(
                                                  context,
                                                  confirm: () {
                                                    Future.delayed(
                                                        const Duration(
                                                            milliseconds:
                                                            100), () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (context) =>
                                                            const POSHomeScreen(
                                                                lastSelectedIndex:
                                                                0)),
                                                      );
                                                    });
                                                  },
                                                  description: TextConstants
                                                      .areYouSureExitShiftDescription,
                                                  confirmText:
                                                  TextConstants.yesExit,
                                                  cancelText:
                                                  TextConstants.noStay,
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                                side: BorderSide(
                                                  color: ((_shiftId == null ||
                                                      _shiftId!.isEmpty) &&
                                                      (previousScreen !=
                                                          TextConstants
                                                              .navCashier))
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade300,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                TextConstants.backText,
                                                style: TextStyle(
                                                  color: (_shiftId == null ||
                                                      _shiftId!.isEmpty)
                                                      ? Colors.grey.shade400
                                                      : themeHelper.themeMode ==
                                                      ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.blueGrey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.06,
                                            width: MediaQuery.of(context)
                                                .size
                                                .width *
                                                0.1,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                FocusScope.of(context).unfocus();

                                                if (_isSafeEnabled) {
                                                  Navigator.push(
                                                    context,
                                                    SlideRightRoute(
                                                      page: SafeOpenScreen(
                                                        cashNotesCoins:
                                                        _grandTotal,
                                                        previousScreen:
                                                        _originScreen ??
                                                            TextConstants
                                                                .navShiftHistory,
                                                      ),
                                                      arguments: TextConstants
                                                          .navShiftHistory,
                                                    ),
                                                  );
                                                } else {
                                                  await _handleShiftSubmit(
                                                      navigateNext: true);
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                const Color(0xFFFF6B6B),
                                                foregroundColor: Colors.white,
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text('Submit',
                                                  style:
                                                  TextStyle(fontSize: 16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Notes Container
                                    Container(
                                      margin: const EdgeInsets.only(
                                          left: 16, right: 8),
                                      padding: const EdgeInsets.all(8),
                                      width: MediaQuery.of(context).size.width *
                                          0.425,
                                      height: sidebarPosition ==
                                          SidebarPosition.bottom
                                          ? MediaQuery.of(context).size.height *
                                          0.625
                                          : MediaQuery.of(context).size.height *
                                          0.7,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: themeHelper.themeMode ==
                                            ThemeMode.dark
                                            ? ThemeNotifier.secondaryBackground
                                            : Colors.grey.shade100,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 2,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 0),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            TextConstants.notes,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ).poppins(),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  TextConstants.type,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: themeHelper.themeMode ==
                                                        ThemeMode.dark
                                                        ? ThemeNotifier.textDark
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  TextConstants.noOfNotes,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: themeHelper.themeMode ==
                                                        ThemeMode.dark
                                                        ? ThemeNotifier.textDark
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  TextConstants.totalAmountText,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: themeHelper.themeMode ==
                                                        ThemeMode.dark
                                                        ? ThemeNotifier.textDark
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Divider(color: Colors.grey.shade300),
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount:
                                              _notesDenominations.length,
                                              physics:
                                              const AlwaysScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              itemBuilder: (context, index) {
                                                final denom =
                                                _notesDenominations[index];
                                                String denomination =
                                                denom.denom.toString();
                                                return Padding(
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 7.0,
                                                      horizontal: 7.0),
                                                  child: Row(
                                                    children: [
                                                      _loadSvg(
                                                        denom.image ??
                                                            'assets/svg/1.svg',
                                                        24,
                                                        24,
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 12.0),
                                                        child: Text(
                                                          '×',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode.dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        height:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .height *
                                                            0.06,
                                                        width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width *
                                                            0.15,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode.dark
                                                                ? ThemeNotifier
                                                                .borderColor
                                                                : Colors.grey
                                                                .shade300,
                                                          ),
                                                          borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                          color: themeHelper
                                                              .themeMode ==
                                                              ThemeMode.dark
                                                              ? ThemeNotifier
                                                              .paymentEntryContainerColor
                                                              : Colors.white,
                                                        ),
                                                        child: TextField(
                                                          controller:
                                                          _getControllerForDenomination(
                                                              denomination),
                                                          keyboardType:
                                                          TextInputType.number,
                                                          textInputAction:
                                                          TextInputAction.next,
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          decoration:
                                                          InputDecoration(
                                                            hintText: '0',
                                                            hintStyle: TextStyle(
                                                              color: themeHelper
                                                                  .themeMode ==
                                                                  ThemeMode.dark
                                                                  ? ThemeNotifier
                                                                  .textDark
                                                                  : Colors.grey,
                                                            ),
                                                            border:
                                                            InputBorder.none,
                                                            contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 8,
                                                              vertical: 9.0,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 12.0),
                                                        child: Text(
                                                          '=',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode.dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        height:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .height *
                                                            0.06,
                                                        width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width *
                                                            0.15,
                                                        alignment: Alignment
                                                            .centerRight,
                                                        padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode.dark
                                                                ? ThemeNotifier
                                                                .borderColor
                                                                : Colors.grey
                                                                .shade400,
                                                          ),
                                                          borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                          color: themeHelper
                                                              .themeMode ==
                                                              ThemeMode.dark
                                                              ? ThemeNotifier
                                                              .orderPanelTabBackground
                                                              : Colors.grey
                                                              .shade300,
                                                        ),
                                                        child: Text(
                                                          '${TextConstants.currencySymbol}${_noteTotals[denomination]!.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode.dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : Colors.grey,
                                                            fontWeight:
                                                            FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Coins Container & Totals
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(
                                              left: 16, right: 8),
                                          padding: const EdgeInsets.all(8),
                                          width: MediaQuery.of(context)
                                              .size
                                              .width *
                                              0.425,
                                          height: sidebarPosition ==
                                              SidebarPosition.bottom
                                              ? MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.45
                                              : MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.45,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(5),
                                            color: themeHelper.themeMode ==
                                                ThemeMode.dark
                                                ? ThemeNotifier
                                                .secondaryBackground
                                                : Colors.grey.shade100,
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                Colors.black.withOpacity(0.1),
                                                blurRadius: 2,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 0),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                TextConstants.coins,
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold),
                                              ).poppins(),
                                              const SizedBox(height: 5),
                                              Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      TextConstants.type,
                                                      style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.w500,
                                                        color: themeHelper
                                                            .themeMode ==
                                                            ThemeMode.dark
                                                            ? ThemeNotifier
                                                            .textDark
                                                            : Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      TextConstants.noOfCoins,
                                                      style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.w500,
                                                        color: themeHelper
                                                            .themeMode ==
                                                            ThemeMode.dark
                                                            ? ThemeNotifier
                                                            .textDark
                                                            : Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      TextConstants
                                                          .totalAmountText,
                                                      style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.w500,
                                                        color: themeHelper
                                                            .themeMode ==
                                                            ThemeMode.dark
                                                            ? ThemeNotifier
                                                            .textDark
                                                            : Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Divider(color: Colors.grey.shade300),
                                              Expanded(
                                                child: ListView.builder(
                                                  itemCount:
                                                  _coinsDenominations.length,
                                                  physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                                  padding: EdgeInsets.zero,
                                                  itemBuilder: (context, index) {
                                                    final denom =
                                                    _coinsDenominations[index];
                                                    String denomination =
                                                    denom.denom.toString();
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 7.0,
                                                          horizontal: 7.0),
                                                      child: Row(
                                                        children: [
                                                          _loadSvg(
                                                            denom.image ??
                                                                'assets/svg/50_cents.svg',
                                                            24,
                                                            24,
                                                          ),
                                                          Padding(
                                                            padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                12.0),
                                                            child: Text(
                                                              '×',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color: themeHelper
                                                                    .themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? ThemeNotifier
                                                                    .textDark
                                                                    : Colors.grey,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            height:
                                                            MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                                0.06,
                                                            width:
                                                            MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                                0.15,
                                                            decoration:
                                                            BoxDecoration(
                                                              border: Border.all(
                                                                color: themeHelper
                                                                    .themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? ThemeNotifier
                                                                    .borderColor
                                                                    : Colors.grey
                                                                    .shade300,
                                                              ),
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  5),
                                                              color: themeHelper
                                                                  .themeMode ==
                                                                  ThemeMode
                                                                      .dark
                                                                  ? ThemeNotifier
                                                                  .paymentEntryContainerColor
                                                                  : Colors.white,
                                                            ),
                                                            child: TextField(
                                                              controller:
                                                              _getControllerForCoinDenomination(
                                                                  denomination),
                                                              keyboardType:
                                                              TextInputType
                                                                  .number,
                                                              textInputAction:
                                                              TextInputAction
                                                                  .next,
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter
                                                                    .digitsOnly,
                                                              ],
                                                              decoration:
                                                              InputDecoration(
                                                                hintText: '0',
                                                                hintStyle:
                                                                TextStyle(
                                                                  color: themeHelper
                                                                      .themeMode ==
                                                                      ThemeMode
                                                                          .dark
                                                                      ? ThemeNotifier
                                                                      .textDark
                                                                      : Colors
                                                                      .grey,
                                                                ),
                                                                border:
                                                                InputBorder
                                                                    .none,
                                                                contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 9.0,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                12.0),
                                                            child: Text(
                                                              '=',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                                color: themeHelper
                                                                    .themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? ThemeNotifier
                                                                    .textDark
                                                                    : Colors.grey,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            height:
                                                            MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                                0.06,
                                                            width:
                                                            MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                                0.15,
                                                            alignment: Alignment
                                                                .centerRight,
                                                            padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                8),
                                                            decoration:
                                                            BoxDecoration(
                                                              border: Border.all(
                                                                color: themeHelper
                                                                    .themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? ThemeNotifier
                                                                    .borderColor
                                                                    : Colors.grey
                                                                    .shade400,
                                                              ),
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  4),
                                                              color: themeHelper
                                                                  .themeMode ==
                                                                  ThemeMode
                                                                      .dark
                                                                  ? ThemeNotifier
                                                                  .orderPanelTabBackground
                                                                  : Colors.grey
                                                                  .shade300,
                                                            ),
                                                            child: Text(
                                                              '${TextConstants.currencySymbol}${_coinTotals[denomination]!.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: themeHelper
                                                                    .themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? ThemeNotifier
                                                                    .textDark
                                                                    : Colors.grey,
                                                                fontWeight:
                                                                FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton(
                                          onPressed: _clearCounts,
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side:
                                            const BorderSide(color: Colors.grey),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('CLEAR COUNTS'),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Text(
                                              TextConstants.totalAmount,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Container(
                                              height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                                  0.06,
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                                  0.25,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey.shade300),
                                                borderRadius:
                                                BorderRadius.circular(5),
                                              ),
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '${TextConstants.currencySymbol}${_grandTotal.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: themeHelper.themeMode ==
                                                      ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),


                      if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
                      });
                    },
                    isVertical: true,
                    isShiftScreen: true,
                  ),
                ],
              ),
            ),
            if (sidebarPosition == SidebarPosition.bottom)
              custom_widgets.NavigationBar(
                selectedSidebarIndex: _selectedSidebarIndex,
                onSidebarItemSelected: (index) {
                  setState(() {
                    _selectedSidebarIndex = index;
                  });
                },
                isVertical: false,
                isShiftScreen: true,
              ),
          ],
        ),
      ),
    );
  }
}

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;
  final String arguments;
  SlideRightRoute({required this.page, this.arguments = ''})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 1000),
    reverseTransitionDuration: const Duration(milliseconds: 1000),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween =
      Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
    settings: RouteSettings(arguments: arguments),
  );
}
