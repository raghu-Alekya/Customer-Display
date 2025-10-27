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
// import 'package:dart_ping_ios/dart_ping_ios.dart';
import '../../../Constants/text.dart';
import '../../../Preferences/pinaka_preferences.dart';
import 'image_utils.dart';

void main() async {
  // Register DartPingIOS
  // if (Platform.isIOS) {
  //   DartPingIOS.register();
  // }
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter services are ready
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
  // Printer Type [bluetooth, usb, network]
  var defaultPrinterType = PrinterType.bluetooth;
  var _isBle = false;
  var _reconnect = false; /// remove this
  var _isConnected = false;
  var printerManager = PrinterManager.instance; /// remove this
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<USBStatus>? _subscriptionUsbStatus;
  StreamSubscription<TCPStatus>? _subscriptionTCPStatus;
  BTStatus _currentStatus = BTStatus.none; /// remove this
  // ignore: unused_field
  TCPStatus _currentTCPStatus = TCPStatus.none;
  // _currentUsbStatus is only supports on Android
  // ignore: unused_field
  USBStatus _currentUsbStatus = USBStatus.none;
  List<int>? pendingTask;/// remove this
  String _ipAddress = '';
  String _port = '9100';
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  static BluetoothPrinter? selectedPrinter; /// remove this
  final PrinterSettings _printerSettings = PrinterSettings();

  /// Build #1.0.279: Added this list for Usb Printer Testing purpose
  // final List<BluetoothPrinter> testUsbPrinters = [
  //   BluetoothPrinter(
  //     deviceName: "USB-Thermal-Printer-80mm",
  //     productId: "1155",
  //     vendorId: "22339",
  //     typePrinter: PrinterType.usb,
  //     isBle: false,
  //   ),
  //   BluetoothPrinter(
  //     deviceName: "USB-Receipt-Printer-58mm",
  //     productId: "1156",
  //     vendorId: "22340",
  //     typePrinter: PrinterType.usb,
  //     isBle: false,
  //   ),
  // ];

  @override
  void initState() {
    if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
    super.initState();
    _portController.text = _port;
    _scan();

    // subscription to listen change status of bluetooth connection
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
    //  PrinterManager.instance.stateUSB is only supports on Android
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

    //  PrinterManager.instance.stateUSB is only supports on Android
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

  // method to scan devices according PrinterType
  void _scan() {
    devices.clear();

    /// Build #1.0.279: ADDED THIS -> Test USB printers when type is USB
    // if (defaultPrinterType == PrinterType.usb) {
    //   devices.addAll(testUsbPrinters);
    //   if (kDebugMode) {
    //     print("#### Added ${testUsbPrinters.length} test USB printers");
    //   }
    // }

    _subscription = printerManager.discovery(type: defaultPrinterType, isBle: _isBle)
        .listen((device) {
      if (kDebugMode) {
        print("device ${device.name}, $device");
      }
      devices.add(BluetoothPrinter(
        deviceName: device.name,
        address: device.address,
        isBle: _isBle,
        vendorId: device.vendorId,
        productId: device.productId,
        typePrinter: defaultPrinterType,
      ));
      setState(() {});
    },
      // onError: (error){
      //     if (kDebugMode) {
      //       print("Error while scanning $error");
      //     }
      // },
    );
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

  Future _printCustomTest() async {
    List<int> bytes = [];
    // Xprinter XP-N160I
    final profile = await CapabilityProfile.load(name: 'XP-N160I');

    // PaperSize.mm80 or PaperSize.mm58

    final ticket =  Generator(PaperSize.mm58, profile);
    bytes += ticket.row([
      PosColumn(text: "x3", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width:7),
      PosColumn(text: "135.0", width: 2),
      PosColumn(text: "420.0", width: 2),
    ]);
    _printEscPos(bytes, ticket);
  }

  Future _printReceiveTest() async {
    List<int> bytes = [];

    // Xprinter XP-N160I
    final profile = await CapabilityProfile.load(name: 'XP-N160I');

    // PaperSize.mm80 or PaperSize.mm58
    final generator = Generator(PaperSize.mm58, profile);
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Product 1 - some description of the product needed here');
    bytes += generator.text('Product 2 - some description of the product needed here');

    // bytes += generator.text('￥1,990', containsChinese: true, styles: const PosStyles(align: PosAlign.left));
    // bytes += generator.emptyLines(1);

    // sum width total column must be 12
    bytes += generator.row([
      PosColumn(width: 7, text: 'Lemon lime export quality per pound x 5 units', styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
      PosColumn(width: 3, text: 'USD 2.00', styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      PosColumn(width: 2, text: 'Desc of USD 2.00', styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
    ]);

    bytes += generator.row([
      PosColumn(text: "x3", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width:7),
      PosColumn(text: "135.0", width: 2),
      PosColumn(text: "420.0", width: 2),
    ]);

    final ByteData data = await rootBundle.load('assets/printer.png');
    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      // decode the bytes into an image
      final decodedImage = img.decodeImage(imageBytes)!;
      // Create a black bottom layer
      // Resize the image to a 130x? thumbnail (maintaining the aspect ratio).
      img.Image thumbnail = img.copyResize(decodedImage, height: 130);
      // creates a copy of the original image with set dimensions
      img.Image originalImg = img.copyResize(decodedImage, width: 380, height: 130);
      // fills the original image with a white background
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;

      //insert the image inside the frame and center it
      drawImage(originalImg, thumbnail, dstX: padding.toInt());

      // convert image to grayscale
      var grayscaleImage = img.grayscale(originalImg);

      bytes += generator.feed(1);
      // bytes += generator.imageRaster(img.decodeImage(imageBytes)!, align: PosAlign.center);
      bytes += generator.imageRaster(grayscaleImage, align: PosAlign.center);
      bytes += generator.feed(1);

      ///open cash drawer
      // generator.drawer();
    }

    // // // Chinese characters
    // bytes += generator.row([
    //   PosColumn(width: 8, text: '豚肉・木耳と玉子炒め弁当', styles: const PosStyles(align: PosAlign.left), containsChinese: true),
    //   PosColumn(width: 4, text: '￥1,990', styles: const PosStyles(align: PosAlign.right), containsChinese: true),
    // ]);
    _printEscPos(bytes, generator);
  }

  /// print ticket: remove this
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
            model: UsbPrinterInput(name: bluetoothPrinter.deviceName, productId: bluetoothPrinter.productId, vendorId: bluetoothPrinter.vendorId));
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
                autoConnect: _reconnect));
        pendingTask = null;
        if (Platform.isAndroid) pendingTask = bytes;
        break;
      case PrinterType.network:
        bytes += generator.feed(2);
        bytes += generator.cut();
        connectedTCP = await printerManager.connect(type: bluetoothPrinter.typePrinter, model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!));
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


  /// remove this
  _1connectDevice() async {
    _isConnected = false;
    if (selectedPrinter == null) return;
    switch (selectedPrinter!.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: UsbPrinterInput(name: selectedPrinter!.deviceName, productId: selectedPrinter!.productId, vendorId: selectedPrinter!.vendorId));
        _isConnected = true;
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: BluetoothPrinterInput(
                name: selectedPrinter!.deviceName,
                address: selectedPrinter!.address!,
                isBle: selectedPrinter!.isBle ?? false,
                autoConnect: _reconnect));
        break;
      case PrinterType.network:
        await printerManager.connect(type: selectedPrinter!.typePrinter, model: TcpPrinterInput(ipAddress: selectedPrinter!.address!));
        _isConnected = true;
        break;
      default:
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext icontext) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return
      //   MaterialApp(
      //   home: ,
      // );
      Scaffold(
        backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textLight : ThemeNotifier.textDark,
        appBar: AppBar(
          title: Text('Select a device to connect',
            style: TextStyle(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
            ),
          ),
          foregroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
          backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.cardDark : ThemeNotifier.cardLight,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Container(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textLight : ThemeNotifier.textDark,
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
                                  if(!_isConnected){
                                    if (mounted) {
                                      ScaffoldMessenger.of(icontext).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Printer does not have required details. Please select another printer.",
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 3),
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
                                  Navigator.pop(context, TextConstants.refresh); // Pass a result when popping
                                } catch(e,s){
                                  if (kDebugMode) {
                                    print("Exception at PrinterSetupScreen.connectDevice() $e, Stack: $s");
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(icontext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Printer does not have required details. Please select another printer.",
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
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
                                if (selectedPrinter != null) printerManager.disconnect(type: selectedPrinter!.typePrinter);
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
                    DropdownButtonFormField<PrinterType>(
                      value: defaultPrinterType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.print,
                          size: 24,
                        ),
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
                        setState(() {
                          if (value != null) {
                            setState(() {
                              defaultPrinterType = value;
                              selectedPrinter = null;
                              _isBle = false;
                              _isConnected = false;
                              _scan();
                            });
                          }
                        });
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
                        children: devices
                            .map(
                              (device) => ListTile(
                            title: Text('${device.deviceName}'),
                            subtitle: Platform.isAndroid && defaultPrinterType == PrinterType.usb
                                ? null
                                : Visibility(visible: !Platform.isWindows, child: Text("${device.address}")),
                            onTap: () async {
                              // do something
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
                            leading: selectedPrinter != null &&
                                ((device.typePrinter == PrinterType.usb && Platform.isWindows
                                    ? device.deviceName == selectedPrinter!.deviceName
                                    : device.vendorId != null && selectedPrinter!.vendorId == device.vendorId) ||
                                    (device.address != null && selectedPrinter!.address == device.address))
                                ? const Icon(
                              Icons.check,
                              color: Colors.green,
                            )
                                : null,
                            trailing: OutlinedButton(
                              onPressed: selectedPrinter == null || device.deviceName != selectedPrinter?.deviceName
                                  ? null
                                  : () async {
                                _printReceiveTest();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                                child: Text("Print test ticket", textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        )
                            .toList()),
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
                            if (_ipController.text.isNotEmpty) setIpAddress(_ipController.text);
                            _printReceiveTest();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 50),
                            child: Text("Print test ticket", textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
