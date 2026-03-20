// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart'; // ✅ ADDED
//
// class VP3350Service {
//   static const MethodChannel _channel =
//   MethodChannel('vp3350_channel');
//
//   /// Initialize SoftPOS SDK
//   static Future<String> initialize() async {
//     try {
//       final String result =
//       await _channel.invokeMethod('initialize');
//       return result;
//     } on PlatformException catch (e) {
//       return "Error: ${e.message}";
//     }
//   }
//
//   /// Start Sale Transaction
//   static Future<String> startTransaction(String amount) async {
//     try {
//       final String result =
//       await _channel.invokeMethod('startTransaction', {
//         "amount": amount,
//       });
//       return result;
//     } on PlatformException catch (e) {
//       return "Error: ${e.message}";
//     }
//   }
// }
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'NMI SoftPOS Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const NmiPaymentScreen(),
//     );
//   }
// }
//
// class NmiPaymentScreen extends StatefulWidget {
//   const NmiPaymentScreen({super.key});
//
//   @override
//   State<NmiPaymentScreen> createState() => _NmiPaymentScreenState();
// }
//
// class _NmiPaymentScreenState extends State<NmiPaymentScreen> {
//   bool isInitialized = false;
//
//   /// ✅ ADDED: Location Permission Check
//   Future<bool> checkLocationPermission() async {
//     var status = await Permission.location.status;
//
//     if (!status.isGranted) {
//       status = await Permission.location.request();
//     }
//
//     if (status.isGranted) {
//       return true;
//     } else if (status.isPermanentlyDenied) {
//       await openAppSettings();
//       return false;
//     }
//
//     return false;
//   }
//
//   Future<void> initializeSoftPOS() async {
//     final response = await VP3350Service.initialize();
//
//     setState(() {
//       isInitialized = true;
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(response)),
//     );
//   }
//
//   /// ✅ MODIFIED (minimal): Added permission + success/fail UI
//   Future<void> startPayment() async {
//     bool hasPermission = await checkLocationPermission();
//
//     if (!hasPermission) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Location permission required")),
//       );
//       return;
//     }
//
//     final response = await VP3350Service.startTransaction("10.00");
//
//     bool isSuccess = response.toLowerCase().contains("success");
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(response),
//         backgroundColor: isSuccess ? Colors.green : Colors.red,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("NMI Payment Screen"),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//
//               const SizedBox(height: 30),
//
//               ElevatedButton(
//                 onPressed: initializeSoftPOS,
//                 child: const Text("Initialize SoftPOS"),
//               ),
//
//               const SizedBox(height: 15),
//
//               ElevatedButton(
//                 onPressed: isInitialized ? startPayment : null,
//                 child: const Text("Tap Card - Charge \$10"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

/////////////////////////////

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class VP3350Service {
  static const MethodChannel _channel =
  MethodChannel('vp3350_channel');

  /// Initialize SoftPOS SDK
  static Future<String> initialize() async {
    try {
      final String result =
      await _channel.invokeMethod('initialize');
      return result;
    } on PlatformException catch (e) {
      return "Error: ${e.message}";
    }
  }

  /// Start Sale Transaction
  static Future<String> startTransaction(String amount) async {
    try {
      final String result =
      await _channel.invokeMethod('startTransaction', {
        "amount": amount,
      });
      return result;
    } on PlatformException catch (e) {
      return "Error: ${e.message}";
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMI SoftPOS Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const NmiPaymentScreen(),
    );
  }
}

class NmiPaymentScreen extends StatefulWidget {
  const NmiPaymentScreen({super.key});

  @override
  State<NmiPaymentScreen> createState() => _NmiPaymentScreenState();
}

class _NmiPaymentScreenState extends State<NmiPaymentScreen> {
  bool isInitialized = false;

  ///  ADDED: Location Permission Check
  Future<bool> checkLocationPermission() async {
    var status = await Permission.location.status;

    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<void> initializeSoftPOS() async {
    final response = await VP3350Service.initialize();

    setState(() {
      isInitialized = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response)),
    );
  }

  ///  MODIFIED (minimal): Added permission + success/fail UI
  Future<void> startPayment() async {
    bool hasPermission = await checkLocationPermission();

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission required")),
      );
      return;
    }

    // ---- Added only: show tap log + measure response time ----
    const String amount = "10.00";
    const String currency = "840";
    const String transactionPoi = "TAP_TO_MOBILE";
    const String transactionType = "SALE";

    final String transactionId = DateTime.now().millisecondsSinceEpoch.toString();
    final int startMs = DateTime.now().millisecondsSinceEpoch;

    // Matches your Android log format (Flutter-side transaction id).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "startTransaction: [CURRENCY : $currency, AMOUNT : $amount, TRANSACTION_POI : $transactionPoi, TRANSACTION_TYPE : $transactionType, TRANSACTION_ID : $transactionId]",
        ),
      ),
    );

    final response = await VP3350Service.startTransaction("10.00");
    final int elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;

    bool isSuccess = response.toLowerCase().contains("success");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );

    // Extra snackbar with response time (without changing existing response UI).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Response time: ${elapsedMs} ms"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NMI Payment Screen"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: initializeSoftPOS,
                child: const Text("Initialize SoftPOS"),
              ),

              const SizedBox(height: 15),

              ElevatedButton(
                onPressed: isInitialized ? startPayment : null,
                child: const Text("Tap Card - Charge \$10"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}