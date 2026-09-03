// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'services/mqtt_customer_display_service.dart';
// import 'providers/display_provider.dart';
// import 'screens/customer_display_screen.dart';
//
// // Must match the same broker host used in the POS app's main.dart.
// const String kMqttBrokerHost = '172.18.7.11';
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   final service = MqttCustomerDisplayService(
//     brokerHosts: [
//       kMqttBrokerHost,
//     ],
//     brokerPort: 1883,
//     displayId: 'CFD01',
//     username: 'pinaka_cfd',
//     token: 'generated-device-token',
//     topicPrefix: 'pinaka/M1001/S001/POS01/cfd',
//   );
//
//   final provider = DisplayProvider(service);
//   await provider.start();
//
//   runApp(
//     ChangeNotifierProvider.value(
//       value: provider,
//       child: const MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: CustomerDisplayScreen(),
//       ),
//     ),
//   );
// }



///////========


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/mqtt_customer_display_service.dart';
import 'providers/display_provider.dart';
import 'screens/customer_display_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = MqttCustomerDisplayService(
    brokerPort: 1883,
    displayId: 'CFD01',
    username: 'pinaka_cfd',
    token: 'generated-device-token',
    topicPrefix: 'pinaka/M1001/S001/POS01/cfd',
  );

  final provider = DisplayProvider(service);

  await provider.start();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CustomerDisplayScreen(),
      ),
    ),
  );
}

