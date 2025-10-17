import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinaka_pos/services/CustomerDisplayService.dart';
import 'package:provider/provider.dart';
import 'Constants/misc_features.dart';
import 'Database/db_helper.dart';
import 'Helper/Extentions/theme_notifier.dart';
import 'Helper/customerdisplayhelper.dart';
import 'Preferences/pinaka_preferences.dart';
import 'Screens/Auth/splash_screen.dart';
import 'package:flutter/services.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter services are ready
  await PinakaPreferences.prepareSharedPref(); //Build #1.0.7: Initialize SharedPref

  /// Build #1.0.187: Required -> Disable device back button completely
  /// This block locks the app to hides system overlays (e.g., status bar, navigation bar) if enableHardwareBackButton is false
  if (!Misc.enableHardwareBackButton) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  ThemeNotifier themeNotifier = ThemeNotifier();
  await themeNotifier.initializeThemeMode(); // Build #1.0.9 : By default dark theme getting selected on launch even after changing from settings

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
