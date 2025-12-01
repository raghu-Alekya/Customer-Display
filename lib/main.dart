import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:pinaka_pos/services/CustomerDisplayService.dart';
import 'package:provider/provider.dart';
import 'Constants/misc_features.dart';
import 'Database/db_helper.dart';
import 'Database/user_db_helper.dart';
import 'Helper/Extentions/theme_notifier.dart';
import 'Helper/cashbackhelper.dart';
import 'Helper/customerdisplayhelper.dart';
import 'Helper/url_helper.dart';
import 'Preferences/pinaka_preferences.dart';
import 'Screens/Auth/splash_screen.dart';
import 'package:flutter/services.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter services are ready
  await Hive.initFlutter();

  await Hive.openBox('categoryCache');
  await Hive.openBox('productCache');
  await Hive.openBox('offlineOrders');
  await Hive.openBox('fastKeysBox');
  await Hive.openBox('deletedOrders');
  await Hive.openBox('cashbackConfig');
  await Hive.openBox('user');

  // 1️⃣ First → initialize base URL
  await UrlHelper.initializeBaseUrl();

  // 2️⃣ Then prepare shared preferences
  await PinakaPreferences.prepareSharedPref();

  // 3️⃣ Then load cashback config
  final userData = await UserDbHelper().getUserData();
  final token = userData?[AppDBConst.userToken];

  if (token != null && token.toString().isNotEmpty) {
    await CashbackHelper.loadCashbackOnStartup();
  } else {
    print("⚠ No user token found — skipping cashback API");
  }
  /// Build #1.0.187: Required -> Disable device back button completely
  /// This block locks the app to hides system overlays (e.g., status bar, navigation bar) if enableHardwareBackButton is false
  if (!Misc.enableHardwareBackButton) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  ThemeNotifier themeNotifier = ThemeNotifier();
  await themeNotifier.initializeThemeMode();
  // Build #1.0.9 : By default dark theme getting selected on launch even after changing from settings
  await UrlHelper.initializeBaseUrl();
  await DBHelper.instance.database;
  final storeInfo = PinakaPreferences.getLoggedInStore();
  if (storeInfo.isNotEmpty) {
    await CustomerDisplayHelper.updateWelcomeWithStore(
      storeInfo['storeId']!,
      storeInfo['storeName']!,
      storeLogoUrl: storeInfo['storeLogoUrl'],
      storeBaseUrl: storeInfo['storeBaseUrl'],
    );
  } else {
    await CustomerDisplayService.showWelcome();
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => themeNotifier,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SafeArea(  //Build #1.0.2 : Fixed - status bar overlapping with design
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeNotifier.lightTheme.copyWith(
          // Add Poppins to your existing light theme
          textTheme: GoogleFonts.interTextTheme(ThemeNotifier.lightTheme.textTheme),
        ),
        darkTheme: ThemeNotifier.darkTheme.copyWith(
          // Add Poppins to your existing dark theme
          textTheme: GoogleFonts.interTextTheme(ThemeNotifier.darkTheme.textTheme),
        ),
        themeMode: themeHelper.themeMode,
        builder: (context, child) {
          // Widget error = const Text('...rendering error...');

          // final scale = MediaQuery.of(context).textScaleFactor.clamp(0.9, 1.0);
          final scale = MediaQuery.of(context)
              .textScaler
              .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.0);
          return MediaQuery(
            // data: MediaQuery.of(context).copyWith(textScaleFactor: scale ), child: child!, //set desired text scale factor here
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            child: child!, //set desired text scale factor here
          );
        },
        home: PopScope( // Build #1.0.187: Fixed - prevents back navigation / hardware back button
          canPop: Misc.enableHardwareBackButton, // Build #1.0.189: Added misc boolean value for enable/disable device back button
          child: Scaffold(
            body: SplashScreen(),
          ),
        ),
      ),
    );
  }
}
