import 'dart:async';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Constants/misc_features.dart';
import 'package:pinaka_pos/Helper/Extentions/extensions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import '../../Blocs/Auth/safe_drop_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/db_helper.dart';
import '../../Database/printer_db_helper.dart';
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Models/Assets/asset_model.dart';
import '../../Models/Auth/safe_drop_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/safe_drop_repository.dart';
import '../../Utilities/global_utility.dart';
import '../../Utilities/printer_settings.dart';
import '../../Utilities/result_utility.dart';
import '../../Widgets/widget_alert_popup_dialogs.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_topbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../Auth/login_screen.dart';
import 'Settings/image_utils.dart';
import 'Settings/printer_setup_screen.dart';
import 'apps_dashboard_screen.dart';

class SafeDropScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  const SafeDropScreen(
      {super.key, this.lastSelectedIndex});

  @override
  State<SafeDropScreen> createState() => _SafeDropScreenState();
}

class _SafeDropScreenState extends State<SafeDropScreen> with LayoutSelectionMixin {
  bool isLoading = true;
  int _selectedSidebarIndex = 4;

  // Added: For API loading state
  bool _isApiLoading = false;

  // Modified: Map to store dynamic controllers for denominations
  final Map<String, TextEditingController> _denomControllers = {};
  final TextEditingController _totalNotesController = TextEditingController();
  final TextEditingController _totalCashController = TextEditingController();

  // Track the currently selected text field
  TextEditingController? _activeController;

  // To track totals
  late int totalNotes;
  late double totalCash;

  //Build #1.0.74: Added: List to store denominations from database
  List<Denom> _safeDenominations = [];
  // Added: SafeDropBloc instance
  late SafeDropBloc _safeDropBloc;
  final PinakaPreferences _preferences = PinakaPreferences(); // Add this
  ///printer
  var _printerSettings =  PrinterSettings();
  List<int> bytes = [];
  StreamSubscription? _safeDropSubscription; // Build #1.0.240
  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4; // Build #1.0.7: Restore previous selection

    // Initialize SafeDropBloc
    _safeDropBloc = SafeDropBloc(SafeDropRepository());
    // Added: Listen to safe drop stream for API responses
    // Build #1.0.240 Store the subscription and manage it properly
    _safeDropSubscription = _safeDropBloc.safeDropStream.listen((response) {  //Build #1.0.74
      if (response.status == Status.COMPLETED) {
        setState(() {
          _isApiLoading = false;
        });
        if (kDebugMode) print("#### SafeDropScreen: Safe drop created successfully: ${response.data!.message}");
        if (Misc.showDebugSnackBar) { // Build #1.0.254
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data!.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Clear all fields after successful save
        _denomControllers.forEach((key, controller) {
          controller.text = "0";
        });
        _calculateTotals();
        /// 1. print receipt
        if(!Misc.disablePrinter) {
          _printTicket();
        }

        // Build #1.0.240
        /// 2. Navigate back to Apps screen after successful upload
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      AppsDashboardScreen(lastSelectedIndex: 4)),
            );
            if (kDebugMode) print("Navigate back to Apps screen");
          }
        });
        _safeDropSubscription?.cancel();
      }
      else if (response.status == Status.ERROR) {
        setState(() {
          _isApiLoading = false; // Build #1.0.240 : dismiss loader on add button
        });
        if (kDebugMode) {
          print("safe drop screen --- Unauthorised : ${response.message ?? " "}");
        }
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Unauthorised : ${response.message}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (context) => LoginScreen()));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        } else {
          if (kDebugMode) print("#### SafeDropScreen: Error creating safe drop: ${response.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                response.message ?? 'Failed to create safe drop')),
          );

          // Build #1.0.240
          /// 3. Show failure popup with dismiss button
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              CustomDialog.showCustomItemAlert(
                  context,
                  title: TextConstants.tranFailed,
                  description: TextConstants.wantRetry,
                  buttonText: TextConstants.dismiss,
                  showCloseIcon: false
              );
            }
          });
        }
        _safeDropSubscription?.cancel(); // Build #1.0.238: cancel subscription
      }
    });

    // Initialize totals
    totalNotes = 0;
    totalCash = 0.0;
    _totalNotesController.text = "0";
    _totalCashController.text = "${TextConstants.currencySymbol}0.00";

    // Fetch denominations from database
    _fetchSafeDenominations();

    // Simulate a loading delay
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        isLoading = false; // Set loading to false after 3 seconds
      });
    });
  }

  //Build #1.0.74, Added: Fetch safe denominations from AssetDBHelper
  Future<void> _fetchSafeDenominations() async {
    if (kDebugMode) print("#### SafeDropScreen: Fetching safe denominations");
    try {
      final denoms = await AssetDBHelper.instance.getSafeDenomList();
      setState(() {
        _safeDenominations = denoms;
        // Initialize controllers for each denomination
        for (var denom in _safeDenominations) {
          _denomControllers[denom.denom.toString()] = TextEditingController(text: "0");
        }
      });
      if (kDebugMode) print("#### SafeDropScreen: Loaded ${_safeDenominations.length} denominations");
    } catch (e) {
      if (kDebugMode) print("#### SafeDropScreen: Error fetching denominations: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load denominations')),
      );
    }
  }

  @override
  void dispose() {
    // Build #1.0.240 : Cancel the subscription to prevent memory leaks
    _safeDropSubscription?.cancel();
    // Dispose of controllers to prevent memory leaks
    _denomControllers.forEach((key, controller) => controller.dispose());
    _totalNotesController.dispose();
    _totalCashController.dispose();
    // Dispose SafeDropBloc
    _safeDropBloc.dispose();
    super.dispose();
  }

  // Modified: Calculate totals based on dynamic denominations
  void _calculateTotals() {
    int notes = 0;
    double cash = 0.0;

    //Build #1.0.74
    _denomControllers.forEach((denom, controller) {
      final count = double.tryParse(controller.text) ?? 0;
      final denomValue = double.parse(denom);
      notes += count.round();
      cash += count * denomValue;
    });

    setState(() {
      totalNotes = notes;
      totalCash = cash;
      _totalNotesController.text = totalNotes.toString();
      _totalCashController.text = "${TextConstants.currencySymbol}${totalCash.toStringAsFixed(2)}";
    });

    if (kDebugMode) print("#### SafeDropScreen: Updated totals - Notes: $totalNotes, Cash: $totalCash");
  }

  // Handle numeric input
  void _handleNumberPress(String value) {
    if (_activeController != null) {
      String currentText = _activeController!.text;
      // Handle special cases for the CustomNumPad
      if (value == "." && currentText.contains(".")) {
        // Don't allow multiple decimal points
        return;
      } else if (value == "00") {
        // Special case for "00"
        if (currentText == "0") {
          _activeController!.text = "0";
        } else {
          _activeController!.text = currentText + "00";
        }
      } else if (currentText == "0" && value != ".") {
        // Replace leading zero, unless adding decimal
        _activeController!.text = value;
      } else {
        // Normal case: append the value
        _activeController!.text = currentText + value;
      }
      _calculateTotals();
    }
  }

  // Clear the active field
  void _handleClear() {
    if (_activeController != null) {
      _activeController!.text = "0";
      _calculateTotals();
    }
  }

  //Build #1.0.74, Modified: Handle add button press with API call
  Future<void> _handleAdd() async {
    if(totalCash == 0 || totalNotes == 0) {  // prevent empty values
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TextConstants.notesError),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    if(_isApiLoading) return; // Prevent multiple clicks

    if (kDebugMode) print("#### SafeDropScreen: Add button pressed");
    setState(() {
      _isApiLoading = true;
    });

    int? shiftId = await UserDbHelper().getUserShiftId(); // Build #1.0.149 : using from db
    if (shiftId == null) {
      if (kDebugMode) print("####### _handleAdd() : shiftId -> $shiftId");
    }
    // Prepare SafeDropRequest
    final denominations = _denomControllers.entries.map((entry) {
      final denom = num.parse(entry.key);
      final count = int.tryParse(entry.value.text) ?? 0;
      return SafeDropDenomination(
        denomination: denom,
        denominationCount: count,
        total: denom * count,
      );
    }).toList();

    final request = SafeDropRequest(
      safeDropDenominations: denominations,
      totalCash: totalCash,
      totalNotes: totalNotes,
      shiftId: shiftId ?? 0,
    );

    if (kDebugMode) print("#### SafeDropScreen: Sending safe drop request: ${request.toJson()}");
    _safeDropBloc.createSafeDrop(request);
    ///1. prepare printer and receipt
    if(!Misc.disablePrinter) {
      _preparePrintTicket();
    }
  }

  Future<Map<String, dynamic>?> loadPrinterData() async {
    var printerDB = await PrinterDBHelper().getPrinterFromDB();
    if(printerDB.isEmpty){
      if (kDebugMode) {
        print(">>>>> OrderSummaryScreen : printerDB is empty");
      }
      return null;
    }
    return printerDB.first;

  }

  Future _preparePrintTicket() async{
    if (kDebugMode) {
      print("OrderSummaryScreen _preparePrintTicket call print receipt");
    }
    ///load header and footer
    var printerData  = await loadPrinterData();
    var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
    var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
    var logo = printerData?[AppDBConst.receiptIconPath] ?? "";

    if (kDebugMode) {
      print("OrderSummaryScreen _preparePrintTicket logo: $logo, iconPath: ${printerData?[AppDBConst.receiptIconPath] ?? ""}");
    }

    bytes = [];
    final ticket =  await _printerSettings.getTicket();

    ///Header
    ///   Pinaka Logo
    ///Tax Summary
    ///   Item
    ///   tax breakdown
    ///   gross total
    ///Footer
    ///   Thank You, Visit Again


    //Pinaka Logo
    final ByteData data;
    if(logo != "") {
      data = await GlobalUtility.fileToByteData(File(logo)) ?? await rootBundle.load('assets/Bubbas_logo.png');
    } else {
      data = await rootBundle.load('assets/Bubbas_logo.png');
    }
    if (kDebugMode) {
      print("OrderSummaryScreen _preparePrintTicket data.lengthInBytes : ${data.lengthInBytes}");
    }
    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      // decode the bytes into an image
      final decodedImage = img.decodeImage(imageBytes)!;
      // Create a black bottom layer
      // Resize the image to a 130x? thumbnail (maintaining the aspect ratio).
      img.Image thumbnail = img.copyResize(decodedImage, height: 280);
      // creates a copy of the original image with set dimensions
      img.Image originalImg = img.copyResize(decodedImage, width: 470, height: 280);
      // fills the original image with a white background
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;

      //insert the image inside the frame and center it
      drawImage(originalImg, thumbnail, dstX: padding.toInt());

      // convert image to grayscale
      var grayscaleImage = img.grayscale(originalImg);
      // bytes += generator.imageRaster(img.decodeImage(imageBytes)!, align: PosAlign.center);
      bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
    }

    //Header
    ///New changes in Header on 2-Sep-2025
    ///Date and Time
    ///Store Id
    ///Address
    //         "Store name": "Kumar Swa D", => < increase font to 5 and bold >
    //         "address": "Q No: D 1847, Shirkey Colony",=>  first line will be <address>
    //         "city": "Mancherial", => second line will be <city>,<state>-<zip_code>
    //         "state": "Telangana",
    //         "country": "", => no need to show
    //         "zip_code": "504302",
    //         "phone_number": false => third line will be <phone_number>


    final DateTime createdDateTime = DateTime.now();
    var dateToPrint = DateFormat(TextConstants.dateFormat).format(createdDateTime);
    var timeToPrint = DateFormat(TextConstants.timeFormat).format(createdDateTime);

    var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
    var storeId = "${merchantDetails?[AppDBConst.storeId]}";
    var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";

    var storeDetails = await AssetDBHelper.instance.getStoreDetails();
    var storeName = "${storeDetails?.name}";
    var address = "${storeDetails?.address},";
    var cityStateZip = "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
    var orderIdToPrint = "";//'${TextConstants.orderID} $orderId';

    final userData = await UserDbHelper().getUserData();
    var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
    var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";

    if (kDebugMode) {
      print(" >>>>> PrintOrder  dateToPrint $dateToPrint ");
      print(" >>>>> PrintOrder  timeToPrint $timeToPrint ");
      print(" >>>>> PrintOrder  storeId $storeId ");
      print(" >>>>> PrintOrder  storeName $storeName ");
      print(" >>>>> PrintOrder  address $address ");
      print(" >>>>> PrintOrder  cityStateZip $cityStateZip ");
      print(" >>>>> PrintOrder  storePhone $storePhone ");
      print(" >>>>> PrintOrder  orderIdToPrint $orderIdToPrint ");
      print(" >>>>> PrintOrder  cashierName $cashierName ");
      print(" >>>>> PrintOrder  cashierRole $cashierRole ");
    }

    if(header != "") {
      bytes += ticket.row([
        PosColumn(
            text: "$header",
            width: 12,
            styles: PosStyles(align: PosAlign.center)),
      ]);
    }
    bytes += ticket.row([
      PosColumn(
        text: "***** SAFE-DROP *****",
        width: 12,
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
    ]);
    bytes += ticket.feed(1);

    //Store Name
    bytes += ticket.row([
      PosColumn(text: "$storeName", width: 12, styles: PosStyles(align: PosAlign.center,bold: true, height: PosTextSize.size2, width: PosTextSize.size2)), //Build #1.0.257: increase font to 5 and bold
    ]);
    bytes += ticket.feed(1); /// Add space between store name and address
    //Address
    bytes += ticket.row([
      PosColumn(text: "$address", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);
    //cityStateZip
    bytes += ticket.row([
      PosColumn(text: "$cityStateZip", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);
    //Store Phone
    bytes += ticket.row([
      PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);

    //Date and Time
    bytes += ticket.row([
      PosColumn(text: "Date: $dateToPrint", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "Time: $timeToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);

    //cashier and  store id
    bytes += ticket.row([
      PosColumn(text: "Cashier: $cashierName", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "StoreID: $storeId", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);

    //role and order Id
    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);

    //Item header
    bytes += ticket.row([
      PosColumn(text: "#", width: 2,styles: PosStyles(align: PosAlign.left,bold:true)),
      PosColumn(text: "Denomination", width:5, styles: PosStyles(align: PosAlign.left,bold:true)),

      PosColumn(text: "Qty", width: 2,styles: PosStyles(align: PosAlign.center,bold:true)),
      PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right,bold:true)),
    ]);
    bytes += ticket.feed(1);

    //Denominations
    int denomIndex = 0;
    _denomControllers.forEach((denom, controller) {
      denomIndex++;
      final count = double.tryParse(controller.text) ?? 0;
      final denomValue = double.parse(denom);
      var notes = count.round();
      var cash = count * denomValue;

      bytes += ticket.row([
        PosColumn(text: "$denomIndex", width: 2),
        PosColumn(text: "${TextConstants.currencySymbol}${denomValue.toStringAsFixed(2)}", width:5, styles: PosStyles(align: PosAlign.right)),
        PosColumn(text: "$notes", width:2, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: "${TextConstants.currencySymbol}${cash.toStringAsFixed(2)}", width: 3, styles: PosStyles(align: PosAlign.right)),
      ]);
    });

    bytes += ticket.feed(1);

    if (kDebugMode) {
      print(" >>>>> SafeDrop Denoms count ${_denomControllers.length} ");
      print(" SafeDrop totalNotes ${totalNotes.toString()}");
      print(" SafeDrop totalCash ${totalCash.toStringAsFixed(2)}");
    }

    //line
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    // bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: TextConstants.total, width: 7),
      PosColumn(text: totalNotes.toString(), width:2, styles: PosStyles(align: PosAlign.center)),
      PosColumn(text: "${TextConstants.currencySymbol}${totalCash.toStringAsFixed(2)}", width:3, styles: PosStyles(align: PosAlign.right)),
    ]);

    // bytes += ticket.row([
    //   PosColumn(text: TextConstants.cash, width: 10),
    //   PosColumn(text: totalCash.toStringAsFixed(2), width:2),
    // ]);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);
    //Footer
    // bytes += ticket.row([
    //   PosColumn(text: "----------------------End----------------------", width: 12),
    // ]);
    // bytes += ticket.feed(1);
  }

  Future _printTicket() async{
    final ticket =  await _printerSettings.getTicket();
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }
    switch (result) {
      case Ok<BluetoothPrinter>():
      // BluetoothPrinter printer = result.value;
        break;
      case Error<BluetoothPrinter>():
        WidgetsBinding.instance.addPostFrameCallback((_) { // Build #1.0.16
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error.getMessage,
                style: const TextStyle(color: Colors.red),
              ),
              backgroundColor: Colors.black, // ✅ Black background
              duration: const Duration(seconds: 3),
            ),
          );
          /// call printer setup screen
          if (kDebugMode) {
            print("call printer setup screen");
          }
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => PrinterSetup(),
          )).then((result) {
            if (result == TextConstants.refresh) { // Build #1.0.175: Added refresh constant string into TextConstants
              _printerSettings.loadPrinter();
              setState(() {
                // Update state to refresh the UI
                if (kDebugMode) {
                  print("SettingScreen - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
                }
                if(!Misc.disablePrinter) {
                  _printTicket();
                }
              });
            }
          });
        });
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    Widget _buildLeftContainer() {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: themeHelper.themeMode == ThemeMode.dark
              ? const Color(0xFF252837)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeHelper.themeMode == ThemeMode.dark
                ? const Color(0xFF454444)
                : Colors.grey.shade300,
          ),
        ),
        child: _safeDenominations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _safeDenominations.length,
                itemBuilder: (context, index) {
                  final denom = _safeDenominations[index];
                  final controller =
                  _denomControllers[denom.denom.toString()]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildDenominationField(
                      denom.image ?? 'assets/svg/1.svg',
                      denom.denom.toString(),
                      controller,
                      isLast: index == _safeDenominations.length - 1,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildRightContainer() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(40, 15, 40, 15),
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark
                ? const Color(0xFF252837)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? const Color(0xFF454444)
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Total Notes
              Padding(
                padding: const EdgeInsets.only(left: 0.0),
                child: Text(
                  "Total Notes",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.white
                        : ThemeNotifier.textLight,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF201E2B)
                      : Colors.white,
                  border: Border.all(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF37393C)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text(
                  _totalNotesController.text,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.white
                        : ThemeNotifier.textLight,
                  ),
                ),
              ),
              const SizedBox(height: 5),

              /// Total Cash
              Padding(
                padding: const EdgeInsets.only(left: 0.0),
                child: Text(
                  "Total Cash",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.white
                        : ThemeNotifier.textLight,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF201E2B)
                      : Colors.white,
                  border: Border.all(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF37393C)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Text(
                  _totalCashController.text,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.white
                        : ThemeNotifier.textLight,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              /// NumPad
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF1F1D2B)
                        : const Color(0xFFEBEFF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomNumPad(
                    onDigitPressed: _handleNumberPress,
                    onClearPressed: _handleClear,
                    onAddPressed: _handleAdd,
                    actionButtonType: ActionButtonType.add,
                    isDarkTheme: true,
                    isLoading: _isApiLoading,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              /// TopBar
              TopBar(
                screen: Screen.SAFE,
                onModeChanged: () async {
                  String newLayout;
                  if (sidebarPosition == SidebarPosition.left) {
                    newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
                  } else if (sidebarPosition == SidebarPosition.right) {
                    newLayout =
                        SharedPreferenceTextConstants.navBottomOrderLeft;
                  } else {
                    newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
                  }

                  PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                  await UserDbHelper().saveUserSettings(
                    {AppDBConst.layoutSelection: newLayout},
                    modeChange: true,
                  );
                  setState(() {});
                },
              ),

              Divider(color: Colors.grey, thickness: 0.4, height: 1),

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
                      ),

                    /// MAIN CONTENT
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? Colors.black
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (sidebarPosition !=
                                  SidebarPosition.bottom) ...[
                                /// Back Button Row (inside parent container)
                                InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode ==
                                          ThemeMode.dark
                                          ? const Color(0xFF252837)
                                          : const Color(0xFF37415E),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.arrow_back,
                                            size: 18, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          "Back",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                              ],

                              /// Containers layout
                              Expanded(
                                child: sidebarPosition == SidebarPosition.bottom
                                    ? Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    /// Back button on top-left
                                    InkWell(
                                      onTap: () =>
                                          Navigator.of(context).pop(),
                                      child: Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          color: themeHelper.themeMode ==
                                              ThemeMode.dark
                                              ? const Color(0xFF252837)
                                              : const Color(0xFF37415E),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.arrow_back,
                                                size: 10,
                                                color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              "Back",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),

                                    /// LEFT container
                                    Expanded(
                                        flex: 5,
                                        child: _buildLeftContainer()),
                                    const SizedBox(width: 20),

                                    /// RIGHT container
                                    Expanded(
                                        flex: 4,
                                        child: _buildRightContainer()),
                                  ],
                                )
                                    : Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: _buildLeftContainer()),
                                    const SizedBox(width: 20),
                                    Expanded(
                                        flex: 4,
                                        child: _buildRightContainer()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (sidebarPosition == SidebarPosition.right)
                      custom_widgets.NavigationBar(
                        selectedSidebarIndex: _selectedSidebarIndex,
                        onSidebarItemSelected: (index) {
                          setState(() {
                            _selectedSidebarIndex = index;
                          });
                        },
                        isVertical: true,
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
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateTotalForNote(
      String denomination, TextEditingController controller) {
    final count = int.tryParse(controller.text) ?? 0;
    final total = count * int.parse(denomination);
    return '${TextConstants.currencySymbol}${total.toStringAsFixed(2)}';
  }

  //Build #1.0.74: Added Naveen
  Future<Widget> _loadSvg(String assetPath) async {
    try {
      if (assetPath.startsWith('http')) {
        return SvgPicture.network(
          assetPath,
          height: 40,
          width: 32,
          placeholderBuilder: (context) => SvgPicture.asset(
            'assets/svg/1.svg', // Your fallback asset
            height: 40,
            width: 32,
          ),
        );
      } else {
        return SvgPicture.asset(
          assetPath,
          height: 40,
          width: 32,
        );
      }
    } catch (e) {
      if (kDebugMode)
        print("#### SafeDropScreen: Error loading SVG $assetPath: $e");
      return SvgPicture.asset(
        'assets/svg/1.svg', // Fallback SVG
        width: 40,
        height: 32,
      );
    }
  }

  Widget _buildDenominationField(
      String assetPath,
      String denomination,
      TextEditingController controller, {
        bool isResult = false,
        bool isLast = false,
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.only(left: 14.0, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// SVG Icon
                FutureBuilder<Widget>(
                  future: _loadSvg(assetPath),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) return snapshot.data!;
                    if (snapshot.hasError) {
                      if (kDebugMode)
                        print("Error loading SVG: ${snapshot.error}");
                      return SvgPicture.asset('assets/svg/1.svg',
                          width: 40, height: 30);
                    }
                    return const SizedBox(width: 40, height: 32);
                  },
                ),
                const SizedBox(width: 18),

                /// Multiplication sign (centered)
                const Text('×', style: TextStyle(fontSize: 22)),

                const SizedBox(width: 18),

                /// Input field
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.12,
                  height: MediaQuery.of(context).size.height * 0.055,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.none,
                    readOnly: isResult,
                    onTap: isResult
                        ? null
                        : () {
                      setState(() {
                        _activeController = controller;
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 7),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF4D505F)
                          : const Color(0xFFF3F2F2),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 18),

                /// Equals sign
                const Text('=',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),

                const SizedBox(width: 18),

                /// Result field
                Container(
                  width: MediaQuery.of(context).size.width * 0.16,
                  height: MediaQuery.of(context).size.height * 0.055,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF34384A)
                        : Color(0xFFE8E8E8),
                  ),
                  child: Text(
                    _calculateTotalForNote(denomination, controller),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? const Color(0xFFE6E6E6)
                          : const Color(0xFF34384A),
                    ),
                  ),
                ),
              ],
            )),
        if (!isLast) ...[
          const SizedBox(height: 7),
          Divider(
            color: isDark ? const Color(0xFF484747) : Colors.grey.shade300,
            height: 4,
            thickness: 1,
          ),
        ],
        const SizedBox(height: 2),
      ],
    );
  }
}