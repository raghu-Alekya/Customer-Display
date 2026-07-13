import 'package:flutter/cupertino.dart';

class Responsive {
  static double w(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double h(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isTablet(BuildContext context) =>
      w(context) >= 700;

  static bool isDesktop(BuildContext context) =>
      w(context) >= 1100;
}