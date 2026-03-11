import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Models/Theme/theme_model.dart';
import '../../Preferences/pinaka_preferences.dart';

/// class that will manage the theme data and notify listeners when the theme changes.
class ThemeNotifier with ChangeNotifier { // Build #1.0.6 - Added Theme code & added to Fast Key Screen for testing
  ThemeMode _themeMode = ThemeMode.light;
  final PinakaPreferences _preferences = PinakaPreferences(); // Create an instance

  ThemeNotifier();

  ThemeMode get themeMode => _themeMode;

  /// Public method to initialize theme mode
  Future<void> initializeThemeMode() async { // Build #1.0.9 : By default dark theme getting selected on launch even after changing from settings
    await _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final userData = await UserDbHelper().getUserData();
    var savedThemeData = userData?[AppDBConst.themeMode]; //Build #1.0.122: using from DB
    String? savedTheme = savedThemeData ?? ThemeMode.light.toString();
    _themeMode = _mapStringToThemeMode(savedTheme);
    notifyListeners();
  }

  ThemeMode getThemeMode() {
    return _themeMode;
  }

  void setThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) return; //Build #1.0.54: added prevent system theme
    _themeMode = mode;
    notifyListeners();
    /// Build #1.0.122 : no need to saveUserSettings here, while onTap saveChanges we are doing
   // await UserDbHelper().saveUserSettings({AppDBConst.themeMode: mode}, themeChange: true); //Build #1.0.122: using from DB
    // await _preferences.saveAppThemeMode(mode); // Build #1.0.7
  }

  // Convert String? to ThemeMode
  ThemeMode _mapStringToThemeMode(String? themeString) {
    if (themeString == ThemeMode.dark.toString()) {
      return ThemeMode.dark;
    }
      return ThemeMode.light; //Build #1.0.54: added default to light
  }

  static const Color lightBackground = Color(0xFFE0E0E0);
  static const Color appBarBackground = Color(0xFF201E2B);
  static const Color darkBackground = Color(0xFF121212);
  static const Color greyBackground = Color(0xFF252837);
  static const Color primaryBackground = Color(0xFF1F1D2B);
  static const Color secondaryBackground = Color(0xFF252837);
  static const Color orderPanelBackground = Color(0xFF221E2B);
  static const Color circularNavBackground = Color(0xFF373A4A);
  static const Color tabsBackground = Color(0xFF313441);
  static const Color tabsLightBackground = Color(0xFFF1F5F9);
  static const Color popUpsBackground = Color(0xFF201E2B);
  static const Color searchBarBackground = Color(0xFF2D303F);
  static const Color buttonLight = Color(0xFF1E2745);
  static const Color buttonDark = Color(0xFF1EA628);
  static const Color cardLight = Color(0xFFFAFAFA);
  static const Color cardDark = Color(0xFF111315);
  static const Color textLight = Colors.black;
  static const Color textDark = Colors.white;
  static const Color tabSelection = Color(0xFFFCDFDC);
  static const Color orderPanelTabSelection = Color(0xFFFFDCD9);
  static const Color orderPanelSummary = Color(0xFF221E2B);
  static const Color orderPanelAddButton = Color(0xFF23202C);
  static const Color orderPanelTabBackground = Color(0xFF313441);
  static const Color borderColor = Color(0xFF1E1E2A);
  static const Color paymentEntryContainerColor = Color(0xFF606372);

  ///grey scale for shadow
  static const Color shadow_F7 = Color(0xFFFFF7F7);

  // Light
  static final ThemeData lightTheme = ThemeData(
    secondaryHeaderColor: textLight,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(),
    primaryColor: primaryBackground,
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      color: primaryBackground,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      labelLarge: TextStyle(color: Colors.white),
    ),
    typography: Typography.material2021(),
    iconTheme: const IconThemeData(color: Colors.black87),
    primaryIconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.grey[400],
    buttonTheme: ButtonThemeData(
      buttonColor: buttonLight,
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blue,
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 2,
      shadowColor: Colors.grey[300],
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(Colors.blue),
    ),
    // switchTheme: SwitchThemeData(
    //   thumbColor: WidgetStateProperty.all(Colors.blue),
    // ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Colors.blue,
      thumbColor: Colors.blue,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Colors.black87),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(Colors.white),
      elevation: WidgetStateProperty.all(2),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(Colors.grey.shade700),
      trackColor: WidgetStateProperty.all(Colors.grey.shade300),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: Colors.white,
      headerTextStyle: const TextStyle(color: Colors.black),
    ),
  );

  // Dark
  static final ThemeData darkTheme = ThemeData(
    secondaryHeaderColor: textDark,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(),
    primaryColor: primaryBackground,
    scaffoldBackgroundColor: greyBackground,
    dialogBackgroundColor: greyBackground,
    appBarTheme: const AppBarTheme(
      color: primaryBackground,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textDark),
      bodyMedium: TextStyle(color: textDark),
      labelLarge: TextStyle(color: textDark),
    ),
    typography: Typography.material2021(),
    iconTheme: const IconThemeData(color: textDark),
    primaryIconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.grey[700],
    buttonTheme: ButtonThemeData(
      buttonColor: buttonDark,
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blue,
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 2,
      shadowColor: Colors.grey[900],
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(Colors.green),
    ),
    // switchTheme: SwitchThemeData(
    //   thumbColor: WidgetStateProperty.all(Colors.green),
    // ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Colors.green,
      thumbColor: Colors.green,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Colors.white70),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
      elevation: WidgetStateProperty.all(2),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(Colors.grey.shade400),
      trackColor: WidgetStateProperty.all(Colors.grey.shade800),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: Colors.grey,
      headerTextStyle: const TextStyle(color: Colors.white),
    ),
  );

  // Light Scheme
  ColorScheme lightColorScheme = ColorScheme(
    primary: Colors.blue,
    secondary: Colors.blue[700]!,
    surface: const Color(0xFFFFFFFF),
    error: Colors.black,
    onError: Colors.black,
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: const Color(0xFF241E30),
    brightness: Brightness.light,
  );

  // Dark Scheme
  ColorScheme darkColorScheme = ColorScheme(
    primary: Colors.blue,
    secondary: Colors.blue[700]!,
    surface: const Color(0xFFFFFFFF),
    error: Colors.black,
    onError: Colors.black,
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: const Color(0xFF241E30),
    brightness: Brightness.light,
  );

  // ColorScheme darkColorScheme = ColorScheme(
  //
  // );
  ThemeData getTheme(BuildContext context) {
    if (_themeMode == ThemeMode.light) {
      return lightTheme;
    } else if (_themeMode == ThemeMode.dark) {
      return darkTheme;
    } else {
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.light ? lightTheme : darkTheme;
    }
  }
}