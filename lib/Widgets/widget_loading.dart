import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Loading extends StatelessWidget { // Build #1.0.8, Naveen added
  final String? loadingMessage;
  double? fontSize = 16;
  Color? textColor = Colors.white;
  double? loadingH = 20.0, loadingW = 20.0;
  double? strokeWidth = 1.5;

  Loading({super.key, this.loadingMessage, this.fontSize = 16, this.textColor = Colors.white, this.loadingH = 20.0, this.loadingW = 20.0, this.strokeWidth = 1.5});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print("loading widget ...");
    }
    return
      Theme(
        // Find and extend the parent theme using `copyWith`.
        // To learn more, check out the section on `Theme.of`.
          data: Theme.of(context).copyWith(
            progressIndicatorTheme : ProgressIndicatorThemeData(color: Colors.orange,circularTrackColor: textColor, linearTrackColor: Colors.orange, refreshBackgroundColor: Colors.orange),
          ),
          child:
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  loadingMessage ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,//Colors.blueAccent,
                    fontSize: (loadingMessage ?? "") == "" ? 0: fontSize,
                  ),
                ),
                SizedBox(height: (loadingMessage ?? "") == "" ? 0: 24, width: (loadingMessage ?? "") == "" ? 0: 10,),
                SizedBox(
                  height: loadingH,
                  width: loadingW,
                  child: CircularProgressIndicator(
                    strokeWidth: strokeWidth ?? 1.5,
                    // color: textColor,// no use, it is always override by theme color
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueGrey), // Build #1.0.16
                  ),
                ),

              ],
            ),
          )
      );
  }
}