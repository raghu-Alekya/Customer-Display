// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:pinaka_pos/Helper/Extentions/theme_notifier.dart';
// import 'package:pinaka_pos/Utilities/printer_settings.dart';
// import 'package:provider/provider.dart';
// import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
// import 'package:thermal_printer/thermal_printer.dart';
// import 'package:image/image.dart' as img;
// // import 'package:dart_ping_ios/dart_ping_ios.dart';
// import '../../../Constants/text.dart';
// import '../../../Preferences/pinaka_preferences.dart';
// import 'image_utils.dart';
//
// void main() async {
//   // Register DartPingIOS
//   // if (Platform.isIOS) {
//   //   DartPingIOS.register();
//   // }
//   WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter services are ready
//   await PinakaPreferences.prepareSharedPref();
//   ThemeNotifier themeNotifier = ThemeNotifier();
//   await themeNotifier.initializeThemeMode();
//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => themeNotifier,
//       child: const PrinterSetup(),
//     ),
//   );
// }
//
// class PrinterSetup extends StatefulWidget {
//   const PrinterSetup({Key? key}) : super(key: key);
//
//   @override
//   State<PrinterSetup> createState() => _PrinterSetupState();
// }
//
// class _PrinterSetupState extends State<PrinterSetup> {
//   // Printer Type [bluetooth, usb, network]
//   var defaultPrinterType = PrinterType.bluetooth;
//   var _isBle = false;
//   var _reconnect = false; /// remove this
//   var _isConnected = false;
//   var printerManager = PrinterManager.instance; /// remove this
//   var devices = <BluetoothPrinter>[];
//   StreamSubscription<PrinterDevice>? _subscription;
//   StreamSubscription<BTStatus>? _subscriptionBtStatus;
//   StreamSubscription<USBStatus>? _subscriptionUsbStatus;
//   StreamSubscription<TCPStatus>? _subscriptionTCPStatus;
//   BTStatus _currentStatus = BTStatus.none; /// remove this
//   // ignore: unused_field
//   TCPStatus _currentTCPStatus = TCPStatus.none;
//   // _currentUsbStatus is only supports on Android
//   // ignore: unused_field
//   USBStatus _currentUsbStatus = USBStatus.none;
//   List<int>? pendingTask;/// remove this
//   String _ipAddress = '';
//   String _port = '9100';
//   final _ipController = TextEditingController();
//   final _portController = TextEditingController();
//   static BluetoothPrinter? selectedPrinter; /// remove this
//   final PrinterSettings _printerSettings = PrinterSettings();
//
//   /// Build #1.0.279: Added this list for Usb Printer Testing purpose
//   // final List<BluetoothPrinter> testUsbPrinters = [
//   //   BluetoothPrinter(
//   //     deviceName: "USB-Thermal-Printer-80mm",
//   //     productId: "1155",
//   //     vendorId: "22339",
//   //     typePrinter: PrinterType.usb,
//   //     isBle: false,
//   //   ),
//   //   BluetoothPrinter(
//   //     deviceName: "USB-Receipt-Printer-58mm",
//   //     productId: "1156",
//   //     vendorId: "22340",
//   //     typePrinter: PrinterType.usb,
//   //     isBle: false,
//   //   ),
//   // ];
//
//   @override
//   void initState() {
//     if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
//     super.initState();
//     _portController.text = _port;
//     _scan();
//
//     // subscription to listen change status of bluetooth connection
//     _subscriptionBtStatus = PrinterManager.instance.stateBluetooth.listen((status) {
//       log(' ----------------- status bt $status ------------------ ');
//       _currentStatus = status;
//       if (status == BTStatus.connected) {
//         setState(() {
//           _isConnected = true;
//         });
//       }
//       if (status == BTStatus.none) {
//         setState(() {
//           _isConnected = false;
//         });
//       }
//       if (status == BTStatus.connected && pendingTask != null) {
//         if (Platform.isAndroid) {
//           Future.delayed(const Duration(milliseconds: 1000), () {
//             PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
//             pendingTask = null;
//           });
//         } else if (Platform.isIOS) {
//           PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
//           pendingTask = null;
//         }
//       }
//     });
//     //  PrinterManager.instance.stateUSB is only supports on Android
//     _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
//       if (kDebugMode) {
//         print(' ----------------- status usb $status ------------------ ');
//       }
//       _currentUsbStatus = status;
//       if (Platform.isAndroid) {
//         if (status == USBStatus.connected && pendingTask != null) {
//           Future.delayed(const Duration(milliseconds: 1000), () {
//             PrinterManager.instance.send(type: PrinterType.usb, bytes: pendingTask!);
//             pendingTask = null;
//           });
//         }
//       }
//     });
//
//     //  PrinterManager.instance.stateUSB is only supports on Android
//     _subscriptionTCPStatus = PrinterManager.instance.stateTCP.listen((status) {
//       log(' ----------------- status tcp $status ------------------ ');
//       _currentTCPStatus = status;
//     });
//   }
//
//   @override
//   void dispose() {
//     _subscription?.cancel();
//     _subscriptionBtStatus?.cancel();
//     _subscriptionUsbStatus?.cancel();
//     _subscriptionTCPStatus?.cancel();
//     _portController.dispose();
//     _ipController.dispose();
//     super.dispose();
//   }
//
//   // method to scan devices according PrinterType
//   void _scan() {
//     devices.clear();
//
//     /// Build #1.0.279: ADDED THIS -> Test USB printers when type is USB
//     // if (defaultPrinterType == PrinterType.usb) {
//     //   devices.addAll(testUsbPrinters);
//     //   if (kDebugMode) {
//     //     print("#### Added ${testUsbPrinters.length} test USB printers");
//     //   }
//     // }
//
//     _subscription = printerManager.discovery(
//       type: defaultPrinterType,
//       isBle: _isBle,
//     ).listen((device) {
//       if (kDebugMode) {
//         print("device found: ${device.name}, address: ${device.address}");
//       }
//
//       devices.add(BluetoothPrinter(
//         deviceName: device.name ?? "Unknown Printer",
//         address: device.address ?? "USB001",
//         isBle: _isBle,
//         vendorId: Platform.isWindows ? (device.name ?? "WindowsPrinter") : device.vendorId,
//         productId: Platform.isWindows ? (device.address ?? "USB001") : device.productId,
//         typePrinter: defaultPrinterType,
//       ));
//       setState(() {});
//     });
//   }
//
//   Future<void> setPort(String value) async {
//     if (value.isEmpty) value = '9100';
//     _port = value;
//     var device = BluetoothPrinter(
//       deviceName: value,
//       address: _ipAddress,
//       port: _port,
//       typePrinter: PrinterType.network,
//       state: false,
//     );
//     await _printerSettings.selectDevice(device);
//     setState(() {
//       selectedPrinter = device;
//       if (kDebugMode) {
//         print(">>>>> Device selected ");
//       }
//     });
//   }
//
//   Future<void> setIpAddress(String value) async {
//     _ipAddress = value;
//     var device = BluetoothPrinter(
//       deviceName: value,
//       address: _ipAddress,
//       port: _port,
//       typePrinter: PrinterType.network,
//       state: false,
//     );
//     await _printerSettings.selectDevice(device);
//     setState(() {
//       selectedPrinter = device;
//       if (kDebugMode) {
//         print(">>>>> Device selected ");
//       }
//     });
//   }
//
//   Future _printCustomTest() async {
//     List<int> bytes = [];
//     // Xprinter XP-N160I
//     final profile = await CapabilityProfile.load(name: 'XP-N160I');
//
//     // PaperSize.mm80 or PaperSize.mm58
//
//     final ticket =  Generator(PaperSize.mm58, profile);
//     bytes += ticket.row([
//       PosColumn(text: "x3", width: 1),
//       PosColumn(text: "Shan Haleem Masala Mix", width:7),
//       PosColumn(text: "135.0", width: 2),
//       PosColumn(text: "420.0", width: 2),
//     ]);
//     _printEscPos(bytes, ticket);
//   }
//
//   Future _printReceiveTest() async {
//     List<int> bytes = [];
//
//     // Xprinter XP-N160I
//     final profile = await CapabilityProfile.load(name: 'XP-N160I');
//
//     // PaperSize.mm80 or PaperSize.mm58
//     final generator = Generator(PaperSize.mm58, profile);
//     bytes += generator.setGlobalCodeTable('CP1252');
//     bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.left));
//     bytes += generator.text('Product 1 - some description of the product needed here');
//     bytes += generator.text('Product 2 - some description of the product needed here');
//
//     // bytes += generator.text('￥1,990', containsChinese: true, styles: const PosStyles(align: PosAlign.left));
//     // bytes += generator.emptyLines(1);
//
//     // sum width total column must be 12
//     bytes += generator.row([
//       PosColumn(width: 7, text: 'Lemon lime export quality per pound x 5 units', styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       PosColumn(width: 3, text: 'USD 2.00', styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       PosColumn(width: 2, text: 'Desc of USD 2.00', styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//     ]);
//
//     bytes += generator.row([
//       PosColumn(text: "x3", width: 1),
//       PosColumn(text: "Shan Haleem Masala Mix", width:7),
//       PosColumn(text: "135.0", width: 2),
//       PosColumn(text: "420.0", width: 2),
//     ]);
//
//     final ByteData data = await rootBundle.load('assets/printer.png');
//     if (data.lengthInBytes > 0) {
//       final Uint8List imageBytes = data.buffer.asUint8List();
//       // decode the bytes into an image
//       final decodedImage = img.decodeImage(imageBytes)!;
//       // Create a black bottom layer
//       // Resize the image to a 130x? thumbnail (maintaining the aspect ratio).
//       img.Image thumbnail = img.copyResize(decodedImage, height: 130);
//       // creates a copy of the original image with set dimensions
//       img.Image originalImg = img.copyResize(decodedImage, width: 380, height: 130);
//       // fills the original image with a white background
//       img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
//       var padding = (originalImg.width - thumbnail.width) / 2;
//
//       //insert the image inside the frame and center it
//       drawImage(originalImg, thumbnail, dstX: padding.toInt());
//
//       // convert image to grayscale
//       var grayscaleImage = img.grayscale(originalImg);
//
//       bytes += generator.feed(1);
//       // bytes += generator.imageRaster(img.decodeImage(imageBytes)!, align: PosAlign.center);
//       bytes += generator.imageRaster(grayscaleImage, align: PosAlign.center);
//       bytes += generator.feed(1);
//
//       ///open cash drawer
//       // generator.drawer();
//     }
//
//     // // // Chinese characters
//     // bytes += generator.row([
//     //   PosColumn(width: 8, text: '豚肉・木耳と玉子炒め弁当', styles: const PosStyles(align: PosAlign.left), containsChinese: true),
//     //   PosColumn(width: 4, text: '￥1,990', styles: const PosStyles(align: PosAlign.right), containsChinese: true),
//     // ]);
//     _printEscPos(bytes, generator);
//   }
//
//   /// print ticket: remove this
//   void _printEscPos(List<int> bytes, Generator generator) async {
//     var connectedTCP = false;
//     if (selectedPrinter == null) return;
//     var bluetoothPrinter = selectedPrinter!;
//
//     if (kDebugMode) {
//       print(">>>>> PrinterSettings printTicket selected printer is '${selectedPrinter?.isBle}' ${selectedPrinter?.deviceName}, ${selectedPrinter?.productId ?? selectedPrinter?.address}, ${selectedPrinter?.vendorId}, ${selectedPrinter?.typePrinter}");
//     }
//
//     switch (bluetoothPrinter.typePrinter) {
//       case PrinterType.usb:
//         bytes += generator.feed(2);
//         bytes += generator.cut();
//         await printerManager.connect(
//             type: bluetoothPrinter.typePrinter,
//             model: UsbPrinterInput(name: bluetoothPrinter.deviceName, productId: bluetoothPrinter.productId, vendorId: bluetoothPrinter.vendorId));
//         pendingTask = null;
//         break;
//       case PrinterType.bluetooth:
//         bytes += generator.cut();
//         await printerManager.connect(
//             type: bluetoothPrinter.typePrinter,
//             model: BluetoothPrinterInput(
//                 name: bluetoothPrinter.deviceName,
//                 address: bluetoothPrinter.address!,
//                 isBle: bluetoothPrinter.isBle ?? false,
//                 autoConnect: _reconnect));
//         pendingTask = null;
//         if (Platform.isAndroid) pendingTask = bytes;
//         break;
//       case PrinterType.network:
//         bytes += generator.feed(2);
//         bytes += generator.cut();
//         connectedTCP = await printerManager.connect(type: bluetoothPrinter.typePrinter, model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!));
//         if (!connectedTCP) print(' --- please review your connection ---');
//         break;
//       default:
//     }
//     if (bluetoothPrinter.typePrinter == PrinterType.bluetooth && Platform.isAndroid) {
//       if (_currentStatus == BTStatus.connected) {
//         printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
//         pendingTask = null;
//       }
//     } else {
//       printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
//       print("windows print ${bluetoothPrinter.typePrinter}");
//     }
//   }
//
//
//   /// remove this
//   _1connectDevice() async {
//     _isConnected = false;
//     if (selectedPrinter == null) return;
//     switch (selectedPrinter!.typePrinter) {
//       case PrinterType.usb:
//         await printerManager.connect(
//             type: selectedPrinter!.typePrinter,
//             model: UsbPrinterInput(name: selectedPrinter!.deviceName, productId: selectedPrinter!.productId, vendorId: selectedPrinter!.vendorId));
//         _isConnected = true;
//         break;
//       case PrinterType.bluetooth:
//         await printerManager.connect(
//             type: selectedPrinter!.typePrinter,
//             model: BluetoothPrinterInput(
//                 name: selectedPrinter!.deviceName,
//                 address: selectedPrinter!.address!,
//                 isBle: selectedPrinter!.isBle ?? false,
//                 autoConnect: _reconnect));
//         break;
//       case PrinterType.network:
//         await printerManager.connect(type: selectedPrinter!.typePrinter, model: TcpPrinterInput(ipAddress: selectedPrinter!.address!));
//         _isConnected = true;
//         break;
//       default:
//     }
//
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext icontext) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return
//       //   MaterialApp(
//       //   home: ,
//       // );
//       Scaffold(
//         backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textLight : ThemeNotifier.textDark,
//         appBar: AppBar(
//           title: Text('Select a device to connect',
//             style: TextStyle(
//               color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
//             ),
//           ),
//           foregroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
//           backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.cardDark : ThemeNotifier.cardLight,
//           leading: IconButton(
//             icon: Icon(Icons.arrow_back, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//         ),
//         body: SafeArea(
//           child: Center(
//             child: Container(
//               color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textLight : ThemeNotifier.textDark,
//               height: double.infinity,
//               constraints: const BoxConstraints(maxWidth: 400),
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.zero,
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: selectedPrinter == null || _isConnected
//                                   ? null
//                                   : () async {
//                                 try {
//                                   _isConnected = await _printerSettings.connectDevice();
//                                   if(!_isConnected){
//                                     if (mounted) {
//                                       ScaffoldMessenger.of(icontext).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             "Printer does not have required details. Please select another printer.",
//                                             style: const TextStyle(
//                                                 color: Colors.white),
//                                           ),
//                                           backgroundColor: Colors.red,
//                                           duration: const Duration(seconds: 3),
//                                         ),
//                                       );
//                                     }
//                                     return;
//                                   }
//                                   setState(() {
//                                     if (kDebugMode) {
//                                       print(">>>>> PrinterSetupScreen Device is connected : $_isConnected");
//                                     }
//                                   });
//                                   Navigator.pop(context, TextConstants.refresh); // Pass a result when popping
//                                 } catch(e,s){
//                                   if (kDebugMode) {
//                                     print("Exception at PrinterSetupScreen.connectDevice() $e, Stack: $s");
//                                   }
//                                   if (mounted) {
//                                     ScaffoldMessenger.of(icontext).showSnackBar(
//                                       SnackBar(
//                                         content: Text(
//                                           "Printer does not have required details. Please select another printer.",
//                                           style: const TextStyle(
//                                               color: Colors.white),
//                                         ),
//                                         backgroundColor: Colors.red,
//                                         duration: const Duration(seconds: 3),
//                                       ),
//                                     );
//                                   }
//                                 }
//                               },
//                               child: const Text("Connect", textAlign: TextAlign.center),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: selectedPrinter == null || !_isConnected
//                                   ? null
//                                   : () {
//                                 if (selectedPrinter != null) printerManager.disconnect(type: selectedPrinter!.typePrinter);
//                                 setState(() {
//                                   _isConnected = false;
//                                 });
//                               },
//                               child: const Text("Disconnect", textAlign: TextAlign.center),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     DropdownButtonFormField<PrinterType>(
//                       value: defaultPrinterType,
//                       decoration: const InputDecoration(
//                         prefixIcon: Icon(
//                           Icons.print,
//                           size: 24,
//                         ),
//                         labelText: "Type Printer Device",
//                         labelStyle: TextStyle(fontSize: 18.0),
//                         focusedBorder: InputBorder.none,
//                         enabledBorder: InputBorder.none,
//                       ),
//                       items: <DropdownMenuItem<PrinterType>>[
//                         if (Platform.isAndroid || Platform.isIOS)
//                           const DropdownMenuItem(
//                             value: PrinterType.bluetooth,
//                             child: Text("bluetooth"),
//                           ),
//                         if (Platform.isAndroid || Platform.isWindows )
//                           const DropdownMenuItem(
//                             value: PrinterType.usb,
//                             child: Text("usb"),
//                           ),
//                         const DropdownMenuItem(
//                           value: PrinterType.network,
//                           child: Text("Wifi"),
//                         ),
//                       ],
//                       onChanged: (PrinterType? value) {
//                         setState(() {
//                           if (value != null) {
//                             setState(() {
//                               defaultPrinterType = value;
//                               selectedPrinter = null;
//                               _isBle = false;
//                               _isConnected = false;
//                               _scan();
//                             });
//                           }
//                         });
//                       },
//                     ),
//                     Visibility(
//                       visible: defaultPrinterType == PrinterType.bluetooth && Platform.isAndroid,
//                       child: SwitchListTile.adaptive(
//                         contentPadding: const EdgeInsets.only(bottom: 20.0, left: 20),
//                         title: const Text(
//                           "This device supports ble (low energy)",
//                           textAlign: TextAlign.start,
//                           style: TextStyle(fontSize: 19.0),
//                         ),
//                         value: _isBle,
//                         onChanged: (bool? value) {
//                           setState(() {
//                             _isBle = value ?? false;
//                             _isConnected = false;
//                             selectedPrinter = null;
//                             _scan();
//                           });
//                         },
//                       ),
//                     ),
//                     Visibility(
//                       visible: defaultPrinterType == PrinterType.bluetooth && Platform.isAndroid,
//                       child: SwitchListTile.adaptive(
//                         contentPadding: const EdgeInsets.only(bottom: 20.0, left: 20),
//                         title: const Text(
//                           "reconnect",
//                           textAlign: TextAlign.start,
//                           style: TextStyle(fontSize: 19.0),
//                         ),
//                         value: _reconnect,
//                         onChanged: (bool? value) {
//                           setState(() {
//                             _reconnect = value ?? false;
//                           });
//                         },
//                       ),
//                     ),
//                     Column(
//                         children: devices
//                             .map(
//                               (device) => ListTile(
//                             title: Text('${device.deviceName}'),
//                             subtitle: Platform.isAndroid && defaultPrinterType == PrinterType.usb
//                                 ? null
//                                 : Visibility(visible: !Platform.isWindows, child: Text("${device.address}")),
//                             onTap: () async {
//                               // do something
//                               if (kDebugMode) {
//                                 print("Selected printer device is ${device.deviceName}, $device");
//                               }
//                               await _printerSettings.selectDevice(device);
//                               setState(() {
//                                 selectedPrinter = device;
//                                 if (kDebugMode) {
//                                   print(">>>>> Device selected ");
//                                 }
//                               });
//                             },
//                             leading: selectedPrinter != null &&
//                                 ((device.typePrinter == PrinterType.usb && Platform.isWindows
//                                     ? device.deviceName == selectedPrinter!.deviceName
//                                     : device.vendorId != null && selectedPrinter!.vendorId == device.vendorId) ||
//                                     (device.address != null && selectedPrinter!.address == device.address))
//                                 ? const Icon(
//                               Icons.check,
//                               color: Colors.green,
//                             )
//                                 : null,
//                             trailing: OutlinedButton(
//                               onPressed: selectedPrinter == null || device.deviceName != selectedPrinter?.deviceName
//                                   ? null
//                                   : () async {
//                                 _printReceiveTest();
//                               },
//                               child: const Padding(
//                                 padding: EdgeInsets.symmetric(vertical: 2, horizontal: 20),
//                                 child: Text("Print test ticket", textAlign: TextAlign.center),
//                               ),
//                             ),
//                           ),
//                         )
//                             .toList()),
//                     Visibility(
//                       visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
//                       child: Padding(
//                         padding: const EdgeInsets.only(top: 10.0),
//                         child: TextFormField(
//                           controller: _ipController,
//                           keyboardType: const TextInputType.numberWithOptions(signed: true),
//                           decoration: const InputDecoration(
//                             label: Text("Ip Address"),
//                             prefixIcon: Icon(Icons.wifi, size: 24),
//                           ),
//                           onChanged: setIpAddress,
//                         ),
//                       ),
//                     ),
//                     Visibility(
//                       visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
//                       child: Padding(
//                         padding: const EdgeInsets.only(top: 10.0),
//                         child: TextFormField(
//                           controller: _portController,
//                           keyboardType: const TextInputType.numberWithOptions(signed: true),
//                           decoration: const InputDecoration(
//                             label: Text("Port"),
//                             prefixIcon: Icon(Icons.numbers_outlined, size: 24),
//                           ),
//                           onChanged: setPort,
//                         ),
//                       ),
//                     ),
//                     Visibility(
//                       visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
//                       child: Padding(
//                         padding: const EdgeInsets.only(top: 10.0),
//                         child: OutlinedButton(
//                           onPressed: () async {
//                             if (_ipController.text.isNotEmpty) setIpAddress(_ipController.text);
//                             _printReceiveTest();
//                           },
//                           child: const Padding(
//                             padding: EdgeInsets.symmetric(vertical: 4, horizontal: 50),
//                             child: Text("Print test ticket", textAlign: TextAlign.center),
//                           ),
//                         ),
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//   }
// }



import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinaka_pos/Helper/Extentions/theme_notifier.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:provider/provider.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:thermal_printer/thermal_printer.dart';
import 'package:image/image.dart' as img;
import '../../../Constants/text.dart';
import '../../../Preferences/pinaka_preferences.dart';
import 'image_utils.dart';
import '../../../Database/printer_db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PinakaPreferences.prepareSharedPref();
  ThemeNotifier themeNotifier = ThemeNotifier();
  await themeNotifier.initializeThemeMode();
  runApp(
    ChangeNotifierProvider(
      create: (_) => themeNotifier,
      child: const PrinterSetup(),
    ),
  );
}

class PrinterSetup extends StatefulWidget {
  const PrinterSetup({Key? key}) : super(key: key);

  @override
  State<PrinterSetup> createState() => _PrinterSetupState();
}

class _PrinterSetupState extends State<PrinterSetup> {
  var defaultPrinterType = PrinterType.bluetooth;
  var _isBle = false;
  var _reconnect = false;
  var _isConnected = false;
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<USBStatus>? _subscriptionUsbStatus;
  StreamSubscription<TCPStatus>? _subscriptionTCPStatus;
  BTStatus _currentStatus = BTStatus.none;
  TCPStatus _currentTCPStatus = TCPStatus.none;
  USBStatus _currentUsbStatus = USBStatus.none;
  List<int>? pendingTask;
  String _ipAddress = '';
  String _port = '9100';
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  static BluetoothPrinter? selectedPrinter;
  final PrinterSettings _printerSettings = PrinterSettings();

  // NEW: Multi-printer selection variables
  final Set<BluetoothPrinter> _selectedPrinters = {};
  final Map<BluetoothPrinter, bool> _printerConnectionStatus = {};

  @override
  void initState() {
    if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
    super.initState();
    _portController.text = _port;
    _scan();

    _subscriptionBtStatus = PrinterManager.instance.stateBluetooth.listen((status) {
      log(' ----------------- status bt $status ------------------ ');
      _currentStatus = status;
      if (status == BTStatus.connected) {
        setState(() {
          _isConnected = true;
        });
      }
      if (status == BTStatus.none) {
        setState(() {
          _isConnected = false;
        });
      }
      if (status == BTStatus.connected && pendingTask != null) {
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
            pendingTask = null;
          });
        } else if (Platform.isIOS) {
          PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
          pendingTask = null;
        }
      }
    });

    _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
      if (kDebugMode) {
        print(' ----------------- status usb $status ------------------ ');
      }
      _currentUsbStatus = status;
      if (Platform.isAndroid) {
        if (status == USBStatus.connected && pendingTask != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(type: PrinterType.usb, bytes: pendingTask!);
            pendingTask = null;
          });
        }
      }
    });

    _subscriptionTCPStatus = PrinterManager.instance.stateTCP.listen((status) {
      log(' ----------------- status tcp $status ------------------ ');
      _currentTCPStatus = status;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscriptionBtStatus?.cancel();
    _subscriptionUsbStatus?.cancel();
    _subscriptionTCPStatus?.cancel();
    _portController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _scan() {
    devices.clear();
    _subscription = printerManager.discovery(
      type: defaultPrinterType,
      isBle: _isBle,
    ).listen((device) {
      if (kDebugMode) {
        print("device found: ${device.name}, address: ${device.address}, vendorId: ${device.vendorId}, productId: ${device.productId}");
      }

      // ==== FIXED FILTER TO SHOW DEVICES WHILE BLOCKING NON-PRINTERS ====
      // Skip Linux Foundation USB root hubs/controllers (vendorId 0x1D6B = 7531)
      if (device.vendorId == 7531 || device.vendorId == 0x1D6B) {
        if (kDebugMode) {
          print("#### [FILTER] Skipping USB root hub/controller: ${device.name}");
        }
        return;
      }

      // Block known non-printer devices (e.g., ASIX AX88179 Ethernet Adapter)
      final Set<int> blockedNonPrinterVendors = {
        2965,    // ASIX Ethernet Adapter (0x0B95)
        0x0B95,  // ASIX alternate ID
        0x05E3,  // Genesys Logic (USB hubs)
        0x0424,  // Microchip/SMSC (USB hubs/LAN)
      };

      if (device.vendorId != null && blockedNonPrinterVendors.contains(device.vendorId)) {
        if (kDebugMode) {
          print("#### [FILTER] Skipping known non-printer USB device: V:${device.vendorId} P:${device.productId} Name: ${device.name}");
        }
        return;
      }

      // Allow all other USB devices to show up (no strict allow-list)
      // This ensures your printer (vendorId 1155) and others are displayed
      if (kDebugMode) {
        print("#### [FILTER] Allowing device: V:${device.vendorId} P:${device.productId} Name: ${device.name}");
      }
      // ==== END OF FIXED FILTER ====

      // Better name fallback for better display
      String printerName = (device.name?.isNotEmpty ?? false)
          ? device.name!
          : "Thermal Printer (V:${device.vendorId} P:${device.productId})";

      devices.add(BluetoothPrinter(
        deviceName: printerName,
        address: device.address ?? "USB001",
        isBle: _isBle,
        vendorId: Platform.isWindows ? (device.name ?? "WindowsPrinter") : device.vendorId,
        productId: Platform.isWindows ? (device.address ?? "USB001") : device.productId,
        typePrinter: defaultPrinterType,
      ));
      setState(() {});
    }, onError: (error) {
      if (kDebugMode) {
        print("#### [SCAN ERROR] Failed to discover devices: $error");
      }
    });
  }

  Future<void> setPort(String value) async {
    if (value.isEmpty) value = '9100';
    _port = value;
    var device = BluetoothPrinter(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    await _printerSettings.selectDevice(device);
    setState(() {
      selectedPrinter = device;
      if (kDebugMode) {
        print(">>>>> Device selected ");
      }
    });
  }

  Future<void> setIpAddress(String value) async {
    _ipAddress = value;
    var device = BluetoothPrinter(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    await _printerSettings.selectDevice(device);
    setState(() {
      selectedPrinter = device;
      if (kDebugMode) {
        print(">>>>> Device selected ");
      }
    });
  }

  void _togglePrinterSelection(BluetoothPrinter device) {
    setState(() {
      if (_selectedPrinters.contains(device)) {
        _selectedPrinters.remove(device);
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Deselected printer: ${device.deviceName}");
          print("#### [MULTI-PRINTER] Total selected printers: ${_selectedPrinters.length}");
        }
      } else {
        _selectedPrinters.add(device);
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Selected printer: ${device.deviceName}");
          print("#### [MULTI-PRINTER] Printer details - Name: ${device.deviceName}, Address: ${device.address}, Type: ${device.typePrinter}");
          print("#### [MULTI-PRINTER] Total selected printers: ${_selectedPrinters.length}");
        }
      }
    });
  }

  Future<void> _connectAllSelectedPrinters(BuildContext icontext) async {
    if (_selectedPrinters.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(icontext).showSnackBar(
          const SnackBar(
            content: Text(
              "Please select at least one printer to connect.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      print("#### [MULTI-PRINTER] Starting connection process for ${_selectedPrinters.length} printer(s)");
    }

    int successCount = 0;
    int failCount = 0;

    for (var printer in _selectedPrinters) {
      try {
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Attempting to connect: ${printer.deviceName}");
          print("#### [MULTI-PRINTER] Printer details - Address: ${printer.address}, Type: ${printer.typePrinter}, VendorId: ${printer.vendorId}, ProductId: ${printer.productId}");
        }

        await _printerSettings.selectDevice(printer);
        selectedPrinter = printer;

        bool isConnected = await _printerSettings.connectDevice();

        if (!isConnected) {
          failCount++;
          if (kDebugMode) {
            print("#### [MULTI-PRINTER] Failed to connect: ${printer.deviceName} - Device does not have required details");
          }
          _printerConnectionStatus[printer] = false;
        } else {
          successCount++;
          _printerConnectionStatus[printer] = true;

          // FIXED: Use multi-printer safe save method (no delete!)
          await PrinterDBHelper().addPrinterToDB(printer);

          if (kDebugMode) {
            print("#### [MULTI-PRINTER] Successfully connected and saved: ${printer.deviceName}");
          }
        }
      } catch (e, s) {
        failCount++;
        _printerConnectionStatus[printer] = false;
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Exception connecting to ${printer.deviceName}: $e");
          print("#### [MULTI-PRINTER] Stack trace: $s");
        }
      }
    }

    setState(() {
      if (successCount > 0) {
        _isConnected = true;
      }
    });

    if (kDebugMode) {
      print("#### [MULTI-PRINTER] Connection summary - Success: $successCount, Failed: $failCount");
      print("#### [MULTI-PRINTER] Connection status map: $_printerConnectionStatus");
    }

    if (mounted) {
      if (successCount > 0 && failCount == 0) {
        ScaffoldMessenger.of(icontext).showSnackBar(
          SnackBar(
            content: Text(
              "All $successCount printer(s) connected successfully!",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, TextConstants.refresh);
      } else if (successCount > 0 && failCount > 0) {
        ScaffoldMessenger.of(icontext).showSnackBar(
          SnackBar(
            content: Text(
              "Connected $successCount printer(s), $failCount failed. Check console for details.",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(icontext).showSnackBar(
          const SnackBar(
            content: Text(
              "Failed to connect to selected printers. Please check printer details.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _printToMultiplePrinters() async {
    if (_selectedPrinters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one printer"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (kDebugMode) {
      print("#### [MULTI-PRINTER] Starting print process for ${_selectedPrinters.length} printer(s)");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Printing to selected printers..."),
            ],
          ),
        );
      },
    );

    int successCount = 0;
    int failCount = 0;

    for (var printer in _selectedPrinters) {
      try {
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Preparing to print to: ${printer.deviceName}");
        }

        List<int> bytes = await _generatePrintBytes();

        if (_printerConnectionStatus[printer] != true) {
          if (kDebugMode) {
            print("#### [MULTI-PRINTER] Printer ${printer.deviceName} not connected, attempting connection...");
          }
          await _printerSettings.selectDevice(printer);
          bool connected = await _printerSettings.connectDevice();
          if (!connected) {
            failCount++;
            if (kDebugMode) {
              print("#### [MULTI-PRINTER] Failed to connect ${printer.deviceName} for printing");
            }
            continue;
          }
          _printerConnectionStatus[printer] = true;
        }

        await _printToSinglePrinter(printer, bytes);
        successCount++;

        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Successfully printed to ${printer.deviceName}");
        }

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        failCount++;
        if (kDebugMode) {
          print("#### [MULTI-PRINTER] Failed to print to ${printer.deviceName}: $e");
        }
      }
    }

    if (kDebugMode) {
      print("#### [MULTI-PRINTER] Print summary - Success: $successCount, Failed: $failCount");
    }

    if (mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Printed to $successCount printer(s)" +
                  (failCount > 0 ? ", $failCount failed" : "")
          ),
          backgroundColor: successCount > 0 ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<List<int>> _generatePrintBytes() async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load(name: 'XP-N160I');
    final generator = Generator(PaperSize.mm58, profile);

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Product 1 - some description of the product needed here');
    bytes += generator.text('Product 2 - some description of the product needed here');

    bytes += generator.row([
      PosColumn(width: 7, text: 'Lemon lime export quality per pound x 5 units',
          styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
      PosColumn(width: 3, text: 'USD 2.00',
          styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      PosColumn(width: 2, text: 'Desc of USD 2.00',
          styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
    ]);

    bytes += generator.row([
      PosColumn(text: "x3", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width: 7),
      PosColumn(text: "135.0", width: 2),
      PosColumn(text: "420.0", width: 2),
    ]);

    try {
      final ByteData data = await rootBundle.load('assets/printer.png');
      if (data.lengthInBytes > 0) {
        final Uint8List imageBytes = data.buffer.asUint8List();
        final decodedImage = img.decodeImage(imageBytes)!;
        img.Image thumbnail = img.copyResize(decodedImage, height: 130);
        img.Image originalImg = img.copyResize(decodedImage, width: 380, height: 130);
        img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
        var padding = (originalImg.width - thumbnail.width) / 2;
        drawImage(originalImg, thumbnail, dstX: padding.toInt());
        var grayscaleImage = img.grayscale(originalImg);
        bytes += generator.feed(1);
        bytes += generator.imageRaster(grayscaleImage, align: PosAlign.center);
        bytes += generator.feed(1);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Image loading error: $e");
      }
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<void> _printToSinglePrinter(BluetoothPrinter printer, List<int> bytes) async {
    switch (printer.typePrinter) {
      case PrinterType.usb:
      case PrinterType.network:
        printerManager.send(type: printer.typePrinter, bytes: bytes);
        break;
      case PrinterType.bluetooth:
        if (Platform.isAndroid) {
          if (_currentStatus == BTStatus.connected) {
            printerManager.send(type: printer.typePrinter, bytes: bytes);
          } else {
            await _printerSettings.selectDevice(printer);
            await _printerSettings.connectDevice();
            await Future.delayed(const Duration(milliseconds: 1000));
            printerManager.send(type: printer.typePrinter, bytes: bytes);
          }
        } else {
          printerManager.send(type: printer.typePrinter, bytes: bytes);
        }
        break;
      default:
    }
  }

  Future _printCustomTest() async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load(name: 'XP-N160I');
    final ticket = Generator(PaperSize.mm58, profile);
    bytes += ticket.row([
      PosColumn(text: "x3", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width: 7),
      PosColumn(text: "135.0", width: 2),
      PosColumn(text: "420.0", width: 2),
    ]);
    _printEscPos(bytes, ticket);
  }

  Future _printReceiveTest() async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load(name: 'XP-N160I');
    final generator = Generator(PaperSize.mm58, profile);
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Product 1 - some description of the product needed here');
    bytes += generator.text('Product 2 - some description of the product needed here');

    bytes += generator.row([
      PosColumn(width: 7, text: 'Lemon lime export quality per pound x 5 units',
          styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
      PosColumn(width: 3, text: 'USD 2.00',
          styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      PosColumn(width: 2, text: 'Desc of USD 2.00',
          styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
    ]);

    bytes += generator.row([
      PosColumn(text: "x3", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width: 7),
      PosColumn(text: "135.0", width: 2),
      PosColumn(text: "420.0", width: 2),
    ]);

    final ByteData data = await rootBundle.load('assets/printer.png');
    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes)!;
      img.Image thumbnail = img.copyResize(decodedImage, height: 130);
      img.Image originalImg = img.copyResize(decodedImage, width: 380, height: 130);
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;
      drawImage(originalImg, thumbnail, dstX: padding.toInt());
      var grayscaleImage = img.grayscale(originalImg);
      bytes += generator.feed(1);
      bytes += generator.imageRaster(grayscaleImage, align: PosAlign.center);
      bytes += generator.feed(1);
    }
    _printEscPos(bytes, generator);
  }

  void _printEscPos(List<int> bytes, Generator generator) async {
    var connectedTCP = false;
    if (selectedPrinter == null) return;
    var bluetoothPrinter = selectedPrinter!;

    if (kDebugMode) {
      print(">>>>> PrinterSettings printTicket selected printer is '${selectedPrinter?.isBle}' ${selectedPrinter?.deviceName}, ${selectedPrinter?.productId ?? selectedPrinter?.address}, ${selectedPrinter?.vendorId}, ${selectedPrinter?.typePrinter}");
    }

    switch (bluetoothPrinter.typePrinter) {
      case PrinterType.usb:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: UsbPrinterInput(
            name: bluetoothPrinter.deviceName,
            productId: bluetoothPrinter.productId,
            vendorId: bluetoothPrinter.vendorId,
          ),
        );
        pendingTask = null;
        break;
      case PrinterType.bluetooth:
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: BluetoothPrinterInput(
            name: bluetoothPrinter.deviceName,
            address: bluetoothPrinter.address!,
            isBle: bluetoothPrinter.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        pendingTask = null;
        if (Platform.isAndroid) pendingTask = bytes;
        break;
      case PrinterType.network:
        bytes += generator.feed(2);
        bytes += generator.cut();
        connectedTCP = await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!),
        );
        if (!connectedTCP) print(' --- please review your connection ---');
        break;
      default:
    }

    if (bluetoothPrinter.typePrinter == PrinterType.bluetooth && Platform.isAndroid) {
      if (_currentStatus == BTStatus.connected) {
        printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
        pendingTask = null;
      }
    } else {
      printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
      print("windows print ${bluetoothPrinter.typePrinter}");
    }
  }

  _1connectDevice() async {
    _isConnected = false;
    if (selectedPrinter == null) return;
    switch (selectedPrinter!.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: UsbPrinterInput(
            name: selectedPrinter!.deviceName,
            productId: selectedPrinter!.productId,
            vendorId: selectedPrinter!.vendorId,
          ),
        );
        _isConnected = true;
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: BluetoothPrinterInput(
            name: selectedPrinter!.deviceName,
            address: selectedPrinter!.address!,
            isBle: selectedPrinter!.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        break;
      case PrinterType.network:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: TcpPrinterInput(ipAddress: selectedPrinter!.address!),
        );
        _isConnected = true;
        break;
      default:
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext icontext) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      backgroundColor: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.textLight
          : ThemeNotifier.textDark,
      appBar: AppBar(
        title: Text(
          'Select device(s) to connect',
          style: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : ThemeNotifier.textLight,
          ),
        ),
        foregroundColor: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.textDark
            : ThemeNotifier.textLight,
        backgroundColor: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.cardDark
            : ThemeNotifier.cardLight,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : ThemeNotifier.textLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textLight
                : ThemeNotifier.textDark,
            height: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedPrinter == null || _isConnected
                                ? null
                                : () async {
                              try {
                                _isConnected = await _printerSettings.connectDevice();
                                if (!_isConnected) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(icontext).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Printer does not have required details. Please select another printer.",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setState(() {
                                  if (kDebugMode) {
                                    print(">>>>> PrinterSetupScreen Device is connected : $_isConnected");
                                  }
                                });
                                Navigator.pop(context, TextConstants.refresh);
                              } catch (e, s) {
                                if (kDebugMode) {
                                  print("Exception at PrinterSetupScreen.connectDevice() $e, Stack: $s");
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(icontext).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Printer does not have required details. Please select another printer.",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text("Connect", textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedPrinter == null || !_isConnected
                                ? null
                                : () {
                              if (selectedPrinter != null) {
                                printerManager.disconnect(type: selectedPrinter!.typePrinter);
                              }
                              setState(() {
                                _isConnected = false;
                              });
                            },
                            child: const Text("Disconnect", textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_selectedPrinters.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                "${_selectedPrinters.length} printer(s) selected",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: (_selectedPrinters.isEmpty || _isConnected)
                                          ? null
                                          : () async {
                                        await _connectAllSelectedPrinters(icontext);
                                      },
                                      icon: const Icon(Icons.link, size: 18),
                                      label: const Text("Connect All"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _printToMultiplePrinters,
                                      icon: const Icon(Icons.print, size: 18),
                                      label: const Text("Print All"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  DropdownButtonFormField<PrinterType>(
                    value: defaultPrinterType,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.print, size: 24),
                      labelText: "Type Printer Device",
                      labelStyle: TextStyle(fontSize: 18.0),
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                    items: <DropdownMenuItem<PrinterType>>[
                      if (Platform.isAndroid || Platform.isIOS)
                        const DropdownMenuItem(
                          value: PrinterType.bluetooth,
                          child: Text("bluetooth"),
                        ),
                      if (Platform.isAndroid || Platform.isWindows)
                        const DropdownMenuItem(
                          value: PrinterType.usb,
                          child: Text("usb"),
                        ),
                      const DropdownMenuItem(
                        value: PrinterType.network,
                        child: Text("Wifi"),
                      ),
                    ],
                    onChanged: (PrinterType? value) {
                      if (value != null) {
                        setState(() {
                          defaultPrinterType = value;
                          selectedPrinter = null;
                          _isBle = false;
                          _isConnected = false;
                          _selectedPrinters.clear();
                          _printerConnectionStatus.clear();
                          _scan();
                        });
                      }
                    },
                  ),

                  Visibility(
                    visible: defaultPrinterType == PrinterType.bluetooth && Platform.isAndroid,
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.only(bottom: 20.0, left: 20),
                      title: const Text(
                        "This device supports ble (low energy)",
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 19.0),
                      ),
                      value: _isBle,
                      onChanged: (bool? value) {
                        setState(() {
                          _isBle = value ?? false;
                          _isConnected = false;
                          selectedPrinter = null;
                          _selectedPrinters.clear();
                          _printerConnectionStatus.clear();
                          _scan();
                        });
                      },
                    ),
                  ),

                  Visibility(
                    visible: defaultPrinterType == PrinterType.bluetooth && Platform.isAndroid,
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.only(bottom: 20.0, left: 20),
                      title: const Text(
                        "reconnect",
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 19.0),
                      ),
                      value: _reconnect,
                      onChanged: (bool? value) {
                        setState(() {
                          _reconnect = value ?? false;
                        });
                      },
                    ),
                  ),

                  Column(
                    children: devices.map((device) {
                      bool isSelected = _selectedPrinters.contains(device);
                      bool isSingleSelected = selectedPrinter != null &&
                          ((device.typePrinter == PrinterType.usb && Platform.isWindows
                              ? device.deviceName == selectedPrinter!.deviceName
                              : device.vendorId != null && selectedPrinter!.vendorId == device.vendorId) ||
                              (device.address != null && selectedPrinter!.address == device.address));
                      bool isConnected = _printerConnectionStatus[device] == true;

                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                _togglePrinterSelection(device);
                              },
                            ),
                            if (isSingleSelected)
                              const Icon(Icons.check, color: Colors.green),
                            if (isConnected)
                              const Icon(Icons.link, color: Colors.blue, size: 18),
                          ],
                        ),
                        title: Text('${device.deviceName}'),
                        subtitle: Platform.isAndroid && defaultPrinterType == PrinterType.usb
                            ? null
                            : Visibility(
                          visible: !Platform.isWindows,
                          child: Text("${device.address}"),
                        ),
                        onTap: () async {
                          if (kDebugMode) {
                            print("Selected printer device is ${device.deviceName}, $device");
                          }
                          await _printerSettings.selectDevice(device);
                          setState(() {
                            selectedPrinter = device;
                            if (kDebugMode) {
                              print(">>>>> Device selected ");
                            }
                          });
                        },
                        trailing: OutlinedButton(
                          onPressed: selectedPrinter == null ||
                              device.deviceName != selectedPrinter?.deviceName
                              ? null
                              : () async {
                            _printReceiveTest();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                            child: Text("Print test ticket", textAlign: TextAlign.center),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  Visibility(
                    visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: TextFormField(
                        controller: _ipController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        decoration: const InputDecoration(
                          label: Text("Ip Address"),
                          prefixIcon: Icon(Icons.wifi, size: 24),
                        ),
                        onChanged: setIpAddress,
                      ),
                    ),
                  ),

                  Visibility(
                    visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        decoration: const InputDecoration(
                          label: Text("Port"),
                          prefixIcon: Icon(Icons.numbers_outlined, size: 24),
                        ),
                        onChanged: setPort,
                      ),
                    ),
                  ),

                  Visibility(
                    visible: defaultPrinterType == PrinterType.network && Platform.isWindows,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: OutlinedButton(
                        onPressed: () async {
                          if (_ipController.text.isNotEmpty) {
                            setIpAddress(_ipController.text);
                          }
                          _printReceiveTest();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 50),
                          child: Text("Print test ticket", textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}