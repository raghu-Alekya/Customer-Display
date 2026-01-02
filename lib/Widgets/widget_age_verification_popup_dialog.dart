import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:pinaka_pos/Widgets/widget_custom_num_pad.dart';
import 'package:pinaka_pos/Widgets/widget_logs_toast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';

import '../Constants/misc_features.dart';
import '../Helper/Extentions/theme_notifier.dart';

class AgeVerificationPopup extends StatefulWidget {
  final int minimumAge;
  final VoidCallback onManualVerify;
  final VoidCallback onAgeVerified;
  final VoidCallback? onCancel;

  const AgeVerificationPopup({
    Key? key,
    required this.minimumAge,
    required this.onManualVerify,
    required this.onAgeVerified,
    this.onCancel,
  }) : super(key: key);

  @override
  State<AgeVerificationPopup> createState() => _AgeVerificationPopupState();
}

class _AgeVerificationPopupState extends State<AgeVerificationPopup> {
  final TextEditingController _dobController = TextEditingController();
  String? _errorMessage;
  bool _isVerifyEnabled = false;
  bool _showDatePicker = false;
  DateTime? _selectedDate;

  // Scanner State
  String _buffer = '';
  String _rawData = '';
  Map<String, String> _parsedData = {};
  Timer? _scanTimer;
  DateTime? _scanTime;
  bool _isScanningLicense = false;
  bool _isProcessingScan = false;
  String _scanStatusMessage = '';

  // Android specific
  final TextEditingController _barcodeController = TextEditingController();
  final bool _isAndroid = Platform.isAndroid;

  bool _isScanningInProgress = false;

  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _dobController.addListener(_onDobChanged);
    if (_isAndroid) {
      _barcodeController.addListener(_onAndroidBarcodeChanged);
    }
  }

  @override
  void dispose() {
    _dobController.dispose();
    _barcodeController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  // Android: Process pasted barcode
  // void _onAndroidBarcodeChanged() {
  //   final barcode = _barcodeController.text.trim();
  //   if (barcode.isEmpty) return;
  //
  //   if (barcode.contains('DBB') && barcode.contains('DAQ')) {
  //     final parsedData = parseAAMVABarcode(barcode);
  //     final dobRaw = parsedData['Date of Birth'];
  //
  //     if (dobRaw != null && dobRaw != 'Not found') {
  //       setState(() {
  //         _dobController.text = dobRaw;
  //         _dobController.selection = TextSelection.fromPosition(
  //           TextPosition(offset: dobRaw.length),
  //         );
  //       });
  //       _onDobChanged();
  //
  //       _barcodeController.clear();
  //
  //       // LogsToast.show(
  //       //   context: context,
  //       //   message: "DOB auto-filled from license!",
  //       //   duration: const Duration(seconds: 3),
  //       // );
  //
  //     } else {
  //       // LogsToast.show(
  //       //   context: context,
  //       //   message: "No valid DOB found in scanned data",
  //       //   isError: true,
  //       // );
  //     }
  //   }
  // }   /////working

  //////

  void _onAndroidBarcodeChanged() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300)); // optional processing delay

      if (barcode.contains('DBB') && barcode.contains('DAQ')) {
        final parsedData = parseAAMVABarcode(barcode);
        final dobRaw = parsedData['Date of Birth'];

        if (dobRaw != null && dobRaw != 'Not found') {
          setState(() {
            _dobController.text = dobRaw;
            _dobController.selection = TextSelection.fromPosition(
              TextPosition(offset: dobRaw.length),
            );
          });
          _onDobChanged();
        }
        _barcodeController.clear();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _parseLicense(String raw) {
    setState(() {
      _isProcessingScan = true;
      _scanStatusMessage = 'Processing scanned data...';
    });

    print("📌 RAW LICENSE DATA ↓↓↓");
    print(raw);
    print("📌 RAW LICENSE DATA ↑↑↑");

    // Clean raw data
    final firstAnsi = raw.indexOf('@ANSI');
    if (firstAnsi != -1) {
      raw = raw.substring(firstAnsi);
      final secondAnsi = raw.indexOf('@ANSI', 1);
      if (secondAnsi != -1) {
        raw = raw.substring(0, secondAnsi);
      }
    } else {
      final ansiIndex = raw.indexOf('ANSI');
      if (ansiIndex != -1) {
        raw = raw.substring(ansiIndex);
      }
      raw = raw.replaceAll('J', '');
    }

    final Map<String, String> data = {};

    String? getField(String code) {
      final match = RegExp('$code([^A-Z]*)', dotAll: true).firstMatch(raw);
      return match?.group(1)?.trim();
    }

    data['First Name'] = getField('DAC') ?? getField('DCT') ?? 'Not found';
    data['Last Name'] = getField('DCS') ?? 'Not found';
    data['Middle Name'] = getField('DAD') ?? '';
    data['License Number'] = getField('DAQ') ?? 'Not found';
    data['Street'] = getField('DAG') ?? 'Not found';
    data['City'] = getField('DAI') ?? 'Not found';
    data['State'] = getField('DAJ') ?? 'Not found';
    data['Postal Code'] = getField('DAK') ?? 'Not found';
    data['Country'] = getField('DCG') ?? 'USA';

    final genderCode = getField('DBC');
    data['Gender'] = genderCode == '1'
        ? 'Male'
        : genderCode == '2'
        ? 'Female'
        : 'Unknown';

    String formatDate(String? mmddyyyy) {
      if (mmddyyyy == null || mmddyyyy.length != 8) return 'Not found';
      final month = mmddyyyy.substring(0, 2);
      final day = mmddyyyy.substring(2, 4);
      final year = mmddyyyy.substring(4, 8);
      return "$month/$day/$year";
    }

    data['Date of Birth'] = formatDate(getField('DBB'));
    data['Issue Date'] = formatDate(getField('DBD'));
    data['Expiration Date'] = formatDate(getField('DBA'));

    print(" PARSED LICENSE DATA ↓↓↓");
    data.forEach((k, v) => print("$k: $v"));
    print(" PARSED LICENSE DATA ↑↑↑");

    final dobRaw = getField('DBB');
    if (dobRaw != null && dobRaw.length == 8) {
      final formattedDob = formatDate(dobRaw);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _dobController.text = formattedDob;
          _dobController.selection = TextSelection.fromPosition(
            TextPosition(offset: formattedDob.length),
          );
        });
        _onDobChanged();
      });
    }

    setState(() {
      _rawData = raw;
      _parsedData = data;
      _scanTime = DateTime.now();
      _isProcessingScan = false;
      _scanStatusMessage = data['Date of Birth'] != 'Not found' &&
          data['Last Name'] != 'Not found'
          ? '✅ Valid license scanned'
          : '⚠️ Incomplete data';

      if (data['Date of Birth'] != 'Not found' &&
          data['Last Name'] != 'Not found') {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanningLicense = false;
              _scanStatusMessage = '';
            });
          }
        });
      }
    });
  }

  Map<String, String> parseAAMVABarcode(String raw) {
    print("📌 RAW BARCODE DATA ↓↓↓");
    print(raw);
    print("📌 RAW BARCODE DATA ↑↑↑");

    final firstAnsi = raw.indexOf('@ANSI');
    if (firstAnsi != -1) {
      raw = raw.substring(firstAnsi);
      final secondAnsi = raw.indexOf('@ANSI', 1);
      if (secondAnsi != -1) {
        raw = raw.substring(0, secondAnsi);
      }
    } else {
      final ansiIndex = raw.indexOf('ANSI');
      if (ansiIndex != -1) {
        raw = raw.substring(ansiIndex);
      }
      raw = raw.replaceAll('J', '');
    }

    final Map<String, String> data = {};

    String? getField(String code) {
      final match = RegExp('$code([^A-Z]*)', dotAll: true).firstMatch(raw);
      return match?.group(1)?.trim();
    }

    data['First Name'] = getField('DAC') ?? getField('DCT') ?? 'Not found';
    data['Last Name'] = getField('DCS') ?? 'Not found';
    data['Middle Name'] = getField('DAD') ?? '';
    data['License Number'] = getField('DAQ') ?? 'Not found';
    data['Street'] = getField('DAG') ?? 'Not found';
    data['City'] = getField('DAI') ?? 'Not found';
    data['State'] = getField('DAJ') ?? 'Not found';
    data['Postal Code'] = getField('DAK') ?? 'Not found';
    data['Country'] = getField('DCG') ?? 'USA';

    final genderCode = getField('DBC');
    data['Gender'] = genderCode == '1'
        ? 'Male'
        : genderCode == '2'
        ? 'Female'
        : 'Unknown';

    String formatDate(String? mmddyyyy) {
      if (mmddyyyy == null || mmddyyyy.length != 8) return 'Not found';
      final month = mmddyyyy.substring(0, 2);
      final day = mmddyyyy.substring(2, 4);
      final year = mmddyyyy.substring(4, 8);
      return "$month/$day/$year";
    }

    data['Date of Birth'] = formatDate(getField('DBB'));
    data['Issue Date'] = formatDate(getField('DBD'));
    data['Expiration Date'] = formatDate(getField('DBA'));

    print("========== DRIVER LICENSE DATA ==========");
    data.forEach((k, v) => print("$k: $v"));
    print("=========================================");

    return data;
  }

  void _startLicenseScanning() {
    setState(() {
      _isScanningLicense = true;
      _rawData = '';
      _parsedData = {};
      _scanTime = null;
      _isProcessingScan = false;
      _scanStatusMessage = 'Ready to scan...';
    });

    print("🚀 STARTING DRIVER LICENSE SCANNING MODE");
  }

  void _stopLicenseScanning() {
    setState(() {
      _isScanningLicense = false;
      _isProcessingScan = false;
      _scanStatusMessage = '';
    });
    print("❌ License scanning cancelled");
  }

  void _handleKeyboardEvent(RawKeyEvent event) {
    if (!_isScanningLicense) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_buffer.isNotEmpty) {
          setState(() {
            _isProcessingScan = true;
            _scanStatusMessage = 'Processing barcode data...';
          });

          final scanned = _buffer.trim();
          _buffer = '';
          _parseLicense(scanned);
        }
        return;
      }

      if (event.character == null || event.character!.isEmpty) return;

      _buffer += event.character!;

      setState(() {
        _scanStatusMessage = 'Scanning... (${_buffer.length} chars)';
      });

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(milliseconds: 500), () {
        if (_buffer.isNotEmpty) {
          setState(() {
            _isProcessingScan = true;
            _scanStatusMessage = 'Auto-processing barcode...';
          });

          final scanned = _buffer.trim();
          _buffer = '';
          _parseLicense(scanned);
        }
      });
    }
  }

  void _onDobChanged() {
    final input = _dobController.text;
    if (kDebugMode) {
      print("##### DEBUG:Age Verification _onDobChanged - date input $input");
    }
    _errorMessage = null;
    _isVerifyEnabled = false;

    if (input.length == 10) {
      try {
        final parts = input.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1500) {
            _errorMessage = 'Invalid date.';
            setState(() {});
            return;
          }

          final dob = DateTime(year, month, day);
          final now = DateTime.now();

          if (dob.isAfter(now)) {
            _errorMessage = 'Date cannot be in the future.';
            setState(() {});
            return;
          }

          final age = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);

          if (age < widget.minimumAge) {
            _errorMessage = 'You must be at least ${widget.minimumAge} years old.';
            setState(() {});
            return;
          }

          _isVerifyEnabled = true;
        } else {
          _errorMessage = 'Invalid format.';
        }
      } catch (e) {
        _errorMessage = 'Invalid date.';
      }
    }
    setState(() {});
  }

  void _onDatePickerSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is DateTime) {
      _selectedDate = args.value as DateTime;
      final formattedDate = DateFormat('MM/dd/yyyy').format(_selectedDate!);
      _dobController.text = formattedDate;
      _dobController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedDate.length),
      );
    }
  }

  void _showDatePickerDialog() {
    setState(() {
      _showDatePicker = true;
    });
  }

  void _hideDatePicker() {
    setState(() {
      _showDatePicker = false;
    });
  }

  void _onDatePickerConfirm() {
    if (_selectedDate != null) {
      final formattedDate = DateFormat('MM/dd/yyyy').format(_selectedDate!);
      _dobController.text = formattedDate;
      _dobController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedDate.length),
      );
    }
    _hideDatePicker();
  }

  void updateDob(String digit) {
    final currentText = _dobController.text;
    String newText = currentText + digit;

    String digitsOnly = newText.replaceAll('/', '');

    if (digitsOnly.length > 8) return;

    String formattedText = digitsOnly;
    if (digitsOnly.length >= 2) {
      formattedText = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
    }
    if (digitsOnly.length >= 4) {
      formattedText = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}/${digitsOnly.substring(4)}';
    }

    if (digitsOnly.length == 1) {
      int firstDigit = int.parse(digitsOnly);
      if (firstDigit >= 2) {
        formattedText = '0$digitsOnly/';
      } else if (firstDigit == 1 || firstDigit == 0) {
        formattedText = digitsOnly;
        setState(() {
          _errorMessage = null;
        });
      }
    }

    if (digitsOnly.length == 2) {
      String month = digitsOnly.substring(0, 2);
      int monthNum = int.parse(month);

      if (monthNum >= 1 && monthNum <= 12) {
        formattedText = '$month/';
      } else if (month == "00") {
        setState(() {
          _errorMessage = 'Invalid month. Try 01-12.';
        });
        return;
      } else {
        String dayDigit = digitsOnly[1];
        formattedText = '01/$dayDigit';
        digitsOnly = '01$dayDigit';
      }
    }

    if (digitsOnly.length == 3) {
      String month = digitsOnly.substring(0, 2);
      String dayStartDigit = digitsOnly[2];
      int dayDigitInt = int.parse(dayStartDigit);

      if (dayDigitInt >= 4) {
        formattedText = '$month/0$dayStartDigit/';
      } else {
        formattedText = '$month/$dayStartDigit';
      }
    }

    if (digitsOnly.length == 4) {
      String month = digitsOnly.substring(0, 2);
      String day = digitsOnly.substring(2, 4);
      int monthNum = int.parse(month);
      int dayNum = int.parse(day);

      int maxDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][monthNum - 1];

      if (dayNum >= 1 && dayNum <= maxDays) {
        formattedText = '$month/$day/';
      } else if (dayNum == 0) {
        setState(() {
          _errorMessage = 'Invalid day (cannot be 00)';
        });
        return;
      } else {
        String firstDayDigit = digitsOnly[2];
        String yearDigit = digitsOnly[3];

        int singleDay = int.parse(firstDayDigit);
        if (singleDay >= 1 && singleDay <= maxDays) {
          formattedText = '$month/0$firstDayDigit/$yearDigit';
        } else {
          setState(() {
            _errorMessage = 'Invalid day for this month (max $maxDays)';
          });
          return;
        }
      }
    }

    setState(() {
      _errorMessage = null;
      _dobController.text = formattedText;
      _dobController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedText.length),
      );
    });
  }

  void clearDob() {
    _dobController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  void _onVerifyAge() {
    final dob = _dobController.text;
    if (dob.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid date of birth';
      });
      return;
    }

    try {
      final parts = dob.split('/');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birthDate = DateTime(year, month, day);
      final now = DateTime.now();
      final age = now.difference(birthDate).inDays ~/ 365;

      if (age >= widget.minimumAge) {
        widget.onAgeVerified();
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Customer is not eligible for this product';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Please enter a valid date of birth';
      });
    }
  }

  void _onManualVerify() {
    widget.onManualVerify();
    Navigator.of(context).pop();
  }

  // // Reusable DOB field – fixes the hint issue
  // Widget _buildDobField(ThemeNotifier themeHelper) {
  //   return Container(
  //     height: 50,
  //     width: 320,
  //     decoration: BoxDecoration(
  //       color: themeHelper.themeMode == ThemeMode.dark
  //           ? ThemeNotifier.paymentEntryContainerColor
  //           : Colors.white,
  //       border: Border.all(
  //           color: themeHelper.themeMode == ThemeMode.dark
  //               ? ThemeNotifier.borderColor
  //               : const Color(0xFF6E7B87)),
  //       borderRadius: BorderRadius.circular(8),
  //       boxShadow: [
  //         BoxShadow(
  //           color: themeHelper.themeMode == ThemeMode.dark
  //               ? ThemeNotifier.shadow_F7
  //               : Colors.grey.withOpacity(0.1),
  //           blurRadius: 2,
  //           offset: const Offset(0, 0),
  //         ),
  //       ],
  //     ),
  //     child: GestureDetector(
  //       onTap: _showDatePickerDialog,
  //       child: TextField(
  //         controller: _dobController,
  //         readOnly: true,
  //         enabled: true,
  //         decoration: InputDecoration(
  //           hintText: 'mm/dd/yyyy',
  //           hintStyle: TextStyle(
  //             color: themeHelper.themeMode == ThemeMode.dark
  //                 ? Colors.grey[600]
  //                 : Colors.grey[500],
  //           ),
  //           border: InputBorder.none,
  //           focusedBorder: InputBorder.none,
  //           suffixIcon: Icon(
  //             Icons.calendar_today_rounded,
  //             color: themeHelper.themeMode == ThemeMode.dark
  //                 ? ThemeNotifier.textDark
  //                 : Colors.grey[600],
  //           ),
  //           contentPadding: const EdgeInsets.symmetric(
  //             horizontal: 12,
  //             vertical: 14,
  //           ),
  //         ),
  //         style: TextStyle(
  //           fontSize: 18,
  //           fontWeight: FontWeight.w500,
  //           letterSpacing: 1.2,
  //           color: themeHelper.themeMode == ThemeMode.dark
  //               ? ThemeNotifier.textDark
  //               : Colors.black87,
  //         ),
  //       ),
  //     ),
  //   );
  // }


  Widget _buildDobField(ThemeNotifier themeHelper) {
    return Container(
      height: 50,
      width: 320,
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.paymentEntryContainerColor
            : Colors.white,
        border: Border.all(
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.borderColor
              : const Color(0xFF6E7B87),
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.shadow_F7
                : Colors.grey.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: TextField(
        controller: _dobController,
        readOnly: true,
        onTap: _showDatePickerDialog, //------ move tap here
        decoration: InputDecoration(
          hintText: 'mm/dd/yyyy',
          hintStyle: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? Colors.grey[600]
                : Colors.grey[500],
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: Icon(
            Icons.calendar_today_rounded,
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : Colors.grey[600],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark
              : Colors.black87,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);

    return Stack(
      children: [
        Dialog(
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.popUpsBackground
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isScanningLicense
              ? RawKeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKey: _handleKeyboardEvent,
            child: _buildScannerUI(themeHelper),
          )
              : (_isAndroid
              ? _buildAndroidMainUI(themeHelper)
              : BarcodeKeyboardListener(
            bufferDuration: const Duration(milliseconds: 400),
            useKeyDownEvent: true,
            onBarcodeScanned: (barcode) async {
              if (_isScanningInProgress) return;

              setState(() {
                _isScanningInProgress = true;
              });

              barcode = barcode.trim();

              if (barcode.isEmpty) {
                setState(() {
                  _isScanningInProgress = false;
                });
                return;
              }

              if (barcode.contains('DBB') && barcode.contains('DAQ')) {
                final parsedData = parseAAMVABarcode(barcode);

                final dobRaw = parsedData['Date of Birth'];
                if (dobRaw != null && dobRaw != 'Not found') {
                  setState(() {
                    _dobController.text = dobRaw;
                    _dobController.selection = TextSelection.fromPosition(
                      TextPosition(offset: dobRaw.length),
                    );
                  });
                  _onDobChanged();
                }
              }

              setState(() {
                _isScanningInProgress = false;
              });
            },
            child: _buildWindowsMainUI(themeHelper),
          )),
        ),
        if (_showDatePicker) _buildDatePickerOverlay(themeHelper),
      ],
    );
  }



  // Widget _buildAndroidMainUI(ThemeNotifier themeHelper) {
  //   return SingleChildScrollView(
  //     child: Container(
  //       height: MediaQuery.of(context).size.height * 0.75,
  //       width: MediaQuery.of(context).size.width * 0.325,
  //       padding: const EdgeInsets.all(15),
  //       child: Column(
  //         children: [
  //           // Header
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const SizedBox(width: 40),
  //               Text(
  //                 'Age Verification Required',
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.w600,
  //                   color: themeHelper.themeMode == ThemeMode.dark
  //                       ? ThemeNotifier.textDark
  //                       : Colors.black87,
  //                 ),
  //               ),
  //               IconButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 icon: Container(
  //                   width: 32,
  //                   height: 32,
  //                   decoration: const BoxDecoration(
  //                     color: Colors.red,
  //                     shape: BoxShape.circle,
  //                   ),
  //                   child: const Icon(Icons.close, color: Colors.white, size: 20),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 12),
  //
  //           // Hidden but functional barcode field
  //           SizedBox(
  //             height: 1, // almost invisible
  //             width: 1,  // almost invisible
  //             child: Opacity(
  //               opacity: 0, // fully invisible
  //               child: TextField(
  //                 controller: _barcodeController,
  //                 autofocus: true, // so scanner input works
  //                 maxLines: 2,
  //               ),
  //             ),
  //           ),
  //
  //           const SizedBox(height: 20),
  //           const Align(
  //             alignment: Alignment.centerLeft,
  //             child: Padding(
  //               padding: EdgeInsets.only(left: 30),
  //               child: Text(
  //                 'Enter Customer Age',
  //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //
  //           // DOB input field (visible)
  //           _buildDobField(themeHelper),
  //
  //           if (_errorMessage != null)
  //             Padding(
  //               padding: const EdgeInsets.only(top: 8),
  //               child: Text(
  //                 _errorMessage!,
  //                 style: const TextStyle(color: Colors.red, fontSize: 14),
  //               ),
  //             ),
  //           const SizedBox(height: 12),
  //
  //           SizedBox(
  //             height: MediaQuery.of(context).size.height * 0.42,
  //             child: CustomNumPad(
  //               numPadType: NumPadType.age,
  //               onDigitPressed: updateDob,
  //               onClearPressed: clearDob,
  //               isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
  //             ),
  //           ),
  //
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: ElevatedButton(
  //                   onPressed: _onManualVerify,
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: const Color(0xFF4C5F7D),
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                   ),
  //                   child: const Text('Manually Verified'),
  //                 ),
  //               ),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: ElevatedButton(
  //                   onPressed: _isVerifyEnabled ? _onVerifyAge : null,
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: _isVerifyEnabled ? Colors.red : Colors.grey[400],
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                   ),
  //                   child: const Text('Verify Age'),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildAndroidMainUI(ThemeNotifier themeHelper) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        width: MediaQuery.of(context).size.width * 0.325,
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Text(
                  'Age Verification Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hidden but functional barcode field
            SizedBox(
              height: 1, // almost invisible
              width: 1,  // almost invisible
              child: Opacity(
                opacity: 0, // fully invisible
                child: TextField(
                  controller: _barcodeController,
                  autofocus: true, // so scanner input works
                  maxLines: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 30),
                child: Text(
                  'Enter Customer Age',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // DOB input field (visible)
            _buildDobField(themeHelper),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            const SizedBox(height: 12),

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.42,
              child: CustomNumPad(
                numPadType: NumPadType.age,
                onDigitPressed: updateDob,
                onClearPressed: clearDob,
                isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onManualVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C5F7D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Manually Verified'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifyEnabled ? _onVerifyAge : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVerifyEnabled ? Colors.red : Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Verify Age'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  // Windows / non-Android UI (original)
  Widget _buildWindowsMainUI(ThemeNotifier themeHelper) {
    return Container(
      // height: 575,
      height: MediaQuery.of(context).size.height * 0.9,

      width: MediaQuery.of(context).size.width * 0.325,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              Text(
                'Age Verification Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ElevatedButton.icon(
          //   onPressed: _startLicenseScanning,
          //   icon: const Icon(Icons.credit_card, size: 20),
          //   label: const Text('Scan Driver License'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.blue,
          //     foregroundColor: Colors.white,
          //     minimumSize: const Size(double.infinity, 45),
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          //   ),
          // ),
          // const SizedBox(height: 12),
          // Text(
          //   'This product is age-restricted. Enter the customer\'s age to verify eligibility, or confirm visually',
          //   textAlign: TextAlign.center,
          //   softWrap: true,
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: themeHelper.themeMode == ThemeMode.dark
          //         ? Colors.white70
          //         : Colors.grey[600],
          //     height: 1.4,
          //   ),
          // ),
          // const SizedBox(height: 12),

          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 30),
              child: Text(
                'Enter Customer Age',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildDobField(themeHelper),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: CustomNumPad(
              numPadType: NumPadType.age,
              onDigitPressed: updateDob,
              onClearPressed: clearDob,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onManualVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C5F7D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Manually Verified'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isVerifyEnabled ? _onVerifyAge : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVerifyEnabled ? Colors.red : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Verify Age'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerUI(ThemeNotifier themeHelper) {
    return Container(
      height: 575,
      width: MediaQuery.of(context).size.width * 0.325,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text(
                'Scanning Driver License',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.blue),
              ),
              IconButton(
                onPressed: _stopLicenseScanning,
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Please scan the driver license barcode now...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.blue, height: 1.4),
          ),
          if (_scanStatusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _scanStatusMessage.contains('Valid')
                    ? Colors.green.shade50
                    : _scanStatusMessage.contains('Incomplete')
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _scanStatusMessage.contains('Valid')
                      ? Colors.green.shade200
                      : _scanStatusMessage.contains('Incomplete')
                      ? Colors.orange.shade200
                      : Colors.blue.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _scanStatusMessage.contains('Valid')
                        ? Icons.check_circle
                        : _scanStatusMessage.contains('Incomplete')
                        ? Icons.warning
                        : Icons.info,
                    color: _scanStatusMessage.contains('Valid')
                        ? Colors.green
                        : _scanStatusMessage.contains('Incomplete')
                        ? Colors.orange
                        : Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _scanStatusMessage,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_isProcessingScan)
            const Center(child: CircularProgressIndicator()),
          if (_parsedData.isNotEmpty && !_isProcessingScan)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'License scanned successfully. DOB auto-filled below.',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 64, color: Colors.blue.shade200),
                  const SizedBox(height: 16),
                  const Text('Waiting for barcode scan...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Point the scanner at the driver license barcode', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _stopLicenseScanning,
            icon: const Icon(Icons.arrow_back),
            label: Text(_parsedData.isEmpty ? 'Cancel Scanning' : 'Back to Main Screen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C5F7D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerOverlay(ThemeNotifier themeHelper) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.popUpsBackground
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Date of Birth',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: _hideDatePicker,
                        icon: Icon(
                          Icons.close,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SfDateRangePicker(
                    onSelectionChanged: _onDatePickerSelectionChanged,
                    selectionMode: DateRangePickerSelectionMode.single,
                    initialSelectedDate: _selectedDate,
                    initialDisplayDate: _selectedDate ??
                        DateTime.now().subtract(const Duration(days: 365 * 25)),
                    maxDate: DateTime.now(),
                    minDate: DateTime(1900),
                    showNavigationArrow: true,
                    monthViewSettings: DateRangePickerMonthViewSettings(
                      viewHeaderStyle: DateRangePickerViewHeaderStyle(
                        textStyle: TextStyle(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                    ),
                    monthCellStyle: DateRangePickerMonthCellStyle(
                      textStyle: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.black87,
                      ),
                      todayTextStyle: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    headerStyle: DateRangePickerHeaderStyle(
                      textStyle: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    yearCellStyle: DateRangePickerYearCellStyle(
                      textStyle: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.black87,
                      ),
                    ),
                    allowViewNavigation: true,
                    view: DateRangePickerView.decade,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _hideDatePicker,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _onDatePickerConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFE6464),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgeVerificationHelper {
  static Future<void> showAgeVerification({
    required BuildContext context,
    required int minimumAge,
    required VoidCallback onManualVerify,
    required VoidCallback onAgeVerified,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AgeVerificationPopup(
        minimumAge: minimumAge,
        onManualVerify: onManualVerify,
        onAgeVerified: onAgeVerified,
        onCancel: onCancel,
      ),
    );
  }
}