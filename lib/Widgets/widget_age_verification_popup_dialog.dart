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
  //final String productName;
  final int minimumAge;
  final VoidCallback onManualVerify;
  final VoidCallback onAgeVerified;
  final VoidCallback? onCancel;

  const AgeVerificationPopup({
    Key? key,
    // required this.productName,
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

  @override
  void initState() {
    super.initState();
    _dobController.addListener(_onDobChanged);
  }

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  void _onDobChanged() {
    final input = _dobController.text;
    if (kDebugMode) {
      print("##### DEBUG:Age Verification _onDobChanged - date input $input, ${input.length}");
    }
    _errorMessage = null;
    _isVerifyEnabled = false;//old code: _isVerifyEnabled = _dobController.text.length == 10; // MM/dd/yyyy format

    if (input.length == 10) {
      try {
        final parts = input.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          if (kDebugMode) {
            print("##### DEBUG:Age Verification _onDobChanged - date month $month, day $day, year $year");
          }
          // Check ranges
          if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1500) {
            _errorMessage = 'Invalid date.';
            return;
          }

          final dob = DateTime(year, month, day);
          final now = DateTime.now();

          // Check if future date
          if (dob.isAfter(now)) {
            _errorMessage = 'Date cannot be in the future.';
            return;
          }

          final age = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);

          if (kDebugMode) {
            print("##### DEBUG:Age Verification _onDobChanged - date age $age");
          }
          if (age < widget.minimumAge) {
            _errorMessage = 'You must be at least ${widget.minimumAge} years old.';
            return;
          }

          if (kDebugMode) {
            print("##### DEBUG:Age Verification _onDobChanged - valid date");
          }
          // If all good
          _isVerifyEnabled = true;
        } else {
          if (kDebugMode) {
            print("##### DEBUG:Age Verification _onDobChanged - Invalid date");
          }
          _errorMessage = 'Invalid format.';
        }
      } catch (e) {
        _errorMessage = 'Invalid date.';
      }
    }
    setState(() {
    });
  }

  void _onDatePickerSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value != null) {
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

    // Remove slashes and work with digits only
    String digitsOnly = newText.replaceAll('/', '');

    // Limit to 8 digits max
    if (digitsOnly.length > 8) return;

    // Format with slashes: MM/DD/YYYY
    String formattedText = digitsOnly;
    if (digitsOnly.length >= 2) {
      formattedText = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
    }
    if (digitsOnly.length >= 4) {
      formattedText = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}/${digitsOnly.substring(4)}';
    }

    // Handle month auto-completion
    if (digitsOnly.length == 1) {
      int firstDigit = int.parse(digitsOnly);
      if (firstDigit >= 2) {
        // 2-9 are definitely single digit months, auto-complete with 0
        formattedText = '0$digitsOnly/';
      } else if (firstDigit == 1 || firstDigit == 0) {
        // 1 or 0 could be start of valid months (10-12 or 01-09)
        // Let user continue typing
        formattedText = digitsOnly;
        setState(() {
          _errorMessage = null; // Clear any errors
        });
      }
    }

    // Special handling: if user types another digit after "1" or "0" in month position
    if (digitsOnly.length == 2) {
      String month = digitsOnly.substring(0, 2);
      int monthNum = int.parse(month);

      if (monthNum >= 1 && monthNum <= 12) {
        formattedText = '$month/';
      } else if (month == "00") {
        // Handle special case of 00 - invalid month
        setState(() {
          _errorMessage = 'Invalid month. Try 01-12.';
        });
        return;
      } else {
        // 13-19 - treat first digit (1) as single month, second as day
        String dayDigit = digitsOnly[1];
        formattedText = '01/$dayDigit';

        // Update digitsOnly to reflect the new format for subsequent processing
        digitsOnly = '01$dayDigit';
      }
    }

    // // Handle day auto-completion
    // if (digitsOnly.length == 3) {
    //   String month = digitsOnly.substring(0, 2);
    //   int dayDigit = int.parse(digitsOnly[2]);
    //
    //   if (dayDigit >= 4) {
    //     // 4-9 are definitely single digit days
    //     formattedText = '$month/0${digitsOnly[2]}/';
    //   } else if (dayDigit >= 1 && dayDigit <= 3) {
    //     // 1-3 could be single or first digit of two-digit day
    //     formattedText = '$month/$dayDigit';
    //   } else {
    //     // 0 is invalid day start
    //     setState(() {
    //       _errorMessage = 'Day cannot start with 0. Try 01-31.';
    //     });
    //     return;
    //   }
    // }
    // Handle day auto-completion (when the user types the 3rd digit)
    if (digitsOnly.length == 3) {
      String month = digitsOnly.substring(0, 2);
      String dayStartDigit = digitsOnly[2];
      int dayDigitInt = int.parse(dayStartDigit);

      // Unambiguous single-digit days (4, 5, 6, 7, 8, 9)
      if (dayDigitInt >= 4) {
        // We know it must be 04, 05, etc., so we auto-complete
        formattedText = '$month/0$dayStartDigit/';
      }
      // Ambiguous days that could be single or two-digit (0, 1, 2, 3)
      else {
        // Just format as MM/D and wait for the next digit.
        // This now correctly handles typing '0' as the start of '01'-'09'.
        formattedText = '$month/$dayStartDigit';
      }
    }

    // Special handling: if user types another digit after "1", "2", or "3" in day position
    if (digitsOnly.length == 4) {
      String month = digitsOnly.substring(0, 2);
      String day = digitsOnly.substring(2, 4);
      int monthNum = int.parse(month);
      int dayNum = int.parse(day);

      // Get max days for the month
      int maxDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][monthNum - 1];

      if (dayNum >= 1 && dayNum <= maxDays) {
        formattedText = '$month/$day/';
      } else if (dayNum == 0) {
        setState(() {
          _errorMessage = 'Invalid day (cannot be 00)';
        });
        return;
      } else {
        // Invalid day like 32-39 - treat first digit as single day, second as year
        String firstDayDigit = digitsOnly[2];
        String yearDigit = digitsOnly[3];

        // Check if single day digit is valid for this month
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

    // Clear error if validation passes
    setState(() {
      _errorMessage = null;
    });

    _dobController.text = formattedText;
    _dobController.selection = TextSelection.fromPosition(
      TextPosition(offset: formattedText.length),
    );
  }

  void setDob(String dob) {
    _dobController.text = dob;
    _dobController.selection = TextSelection.fromPosition(
      TextPosition(offset: dob.length),
    );
  }

  void clearDob() {
    _dobController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  void _onVerifyAge() {
    if (kDebugMode) {
      print("AgeVerification _onVerifyAge()");
    }
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
    if (kDebugMode) {
      print("AgeVerification _onManualVerify()");
    }
    widget.onManualVerify();
    Navigator.of(context).pop();
  }

  /// Extract DOB from barcode: expects "DBBMMDDYYYY"
  String? parseDOBFromBarcode(String barcodeData) {
    try {
      if (kDebugMode) {
        print("Order Panel parseDOBFromBarcode: $barcodeData");
      }
      final dobMatch = RegExp(r'DBB(\d{8})').firstMatch(barcodeData);
      if (dobMatch != null) {
        final dobStr = dobMatch.group(1)!;
        final month = dobStr.substring(0, 2);
        final day = dobStr.substring(2, 4);
        final year = dobStr.substring(4, 8);
        if (kDebugMode) {
          print("Order Panel parseDOBFromBarcode: $month/$day/$year");
        }
        // return DateTime(year, month, day);
        return "$month/$day/$year";
      }
    } catch (e) {
      if (kDebugMode) print("Error parsing DOB: $e");
    }
    return null;
  }

  bool _isScanningInProgress = false;
  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    // if(_isScanningInProgress) return CircularProgressIndicator();
    return Stack(
      children: [
        Dialog(
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.popUpsBackground : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child:
          BarcodeKeyboardListener( // Added - Wrap with BarcodeKeyboardListener for barcode scanning
            bufferDuration: Duration(milliseconds: 400),
            useKeyDownEvent: true,
            onBarcodeScanned:(barcode) async {
              setState(() {
                _isScanningInProgress = true;
              });
              if (kDebugMode) {
                print("AgeVerification onBarcodeScanned _isScanningInProgress: $_isScanningInProgress");
              }
              barcode = barcode.trim().replaceAll(' ', '');

              if (kDebugMode) {
                print(
                    "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode, _isScanningInProgress: $_isScanningInProgress");
              }

              if (barcode.isNotEmpty) {
                String? dobScanned = "";
                /// Testing code: not working, Scanner will generate multiple tap events and call when scanned driving licence with PDF417 format irrespective of this code here
                if (barcode.contains('DBB')) {
                  // if (barcode.startsWith('@') || barcode.contains('\n')) {
                  // PDF417 often includes structured data with newlines or starts with '@' (AAMVA standard)
                  if (kDebugMode) {
                    print('PDF417 Detected: $barcode');
                  }
                  // var date = parseDOBFromBarcode(barcode);
                  dobScanned = parseDOBFromBarcode(barcode); //"${date?.month}/${date?.day}/${date?.year}";
                  _dobController.text = dobScanned ?? "";
                  if (kDebugMode) {
                    print("##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode, $dobScanned");
                  }
                  setState(() {
                    _isScanningInProgress = false;
                  });
                  return;
                } else {
                  if (kDebugMode) {
                    print('Non-PDF417 Barcode: $barcode');
                  }
                }
                if (kDebugMode) {
                  print(
                      "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode");
                }
              }
              setState(() {
                _isScanningInProgress = false;
              });
            },
            child:
            _isScanningInProgress
                ? SizedBox(height: MediaQuery.of(context).size.height * 0.3, child: CircularProgressIndicator(),)
                : Container(
              height: 575,
              width: MediaQuery.of(context).size.width * 0.325,
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  // Header with close button
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
                              ? ThemeNotifier.textDark : Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Future.delayed(Duration(milliseconds: 2000));
                          if (_isScanningInProgress) return;
                          //widget.onCancel?.call();
                          if (kDebugMode) {
                            print("AgeVerification Close()");
                          }
                          if (Misc.enableUILogMessages) { // Build #1.0.256: we have to clear if enableUILogMessages is true
                            // Clear global steps when toast is closed
                            globalProcessSteps.clear();
                          }
                          Navigator.of(context).pop();
                        },
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'This product is age-restricted. Enter the customer\'s age to verify eligibility, or confirm visually',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? Colors.white70 : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Date input section
                  Align(
                    alignment: Alignment.centerLeft, // ⭐ center-left alignment
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30), // ⭐ Add your padding here
                      child: Text(
                        'Enter Customer Age',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(height: 4),

// Date input field testing code for barcode scanner
//                 BarcodeKeyboardListener( // Added - Wrap with BarcodeKeyboardListener for barcode scanning
//                     bufferDuration: Duration(milliseconds: 400),
//                     useKeyDownEvent: true,
//                     onBarcodeScanned:(barcode) async {
//                       barcode = barcode.trim().replaceAll(' ', '');
//
//                     if (kDebugMode) {
//                       print(
//                           "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode");
//                     }
//
//                     if (barcode.isNotEmpty) {
//                       String? dobScanned = "";
//                       /// Testing code: not working, Scanner will generate multiple tap events and call when scanned driving licence with PDF417 format irrespective of this code here
//                       if (barcode.startsWith('@') || barcode.contains('\n') || barcode.startsWith('ansi') || barcode.startsWith('2') || barcode.startsWith('DBB')) {
//                         // if (barcode.startsWith('@') || barcode.contains('\n')) {
//                         // PDF417 often includes structured data with newlines or starts with '@' (AAMVA standard)
//                         if (kDebugMode) {
//                           print('PDF417 Detected: $barcode');
//                         }
//                         // var date = parseDOBFromBarcode(barcode);
//                         dobScanned = parseDOBFromBarcode(barcode); //"${date?.month}/${date?.day}/${date?.year}";
//                         _dobController.text = dobScanned ?? "";
//                         if (kDebugMode) {
//                           print("##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode, $dobScanned");
//                         }
//                         return;
//                       } else {
//                         if (kDebugMode) {
//                           print('Non-PDF417 Barcode: $barcode');
//                         }
//                       }
//                       if (kDebugMode) {
//                         print(
//                             "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode");
//                       }
//                     }
//                   },
//                   child: TextField(
//                     controller: _dobController,
//                     readOnly: true,
//                     decoration: InputDecoration(
//                       hintText: 'mm/dd/yyyy',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide(color: Colors.grey[300]!),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: const BorderSide(color: Colors.blue),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 16,
//                       ),
//                     ),
//                     style: const TextStyle(
//                       fontSize: 16,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ),
                  // Date input field with date picker
                  Container(
                    height: 50,
                    width: 320,
                    decoration: BoxDecoration(
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
                      border: Border.all(color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.borderColor : Color(0xFF6E7B87)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.shadow_F7
                              : Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: _showDatePickerDialog,
                      child: AbsorbPointer(
                        child:
                        // BarcodeKeyboardListener( // Added - Wrap with BarcodeKeyboardListener for barcode scanning
                        //   bufferDuration: Duration(milliseconds: 400),
                        //   useKeyDownEvent: true,
                        //   onBarcodeScanned:(barcode) async {
                        //     _isScanningInProgress = true;
                        //     if (kDebugMode) {
                        //       print("AgeVerification onBarcodeScanned _isScanningInProgress: $_isScanningInProgress");
                        //     }
                        //     barcode = barcode.trim().replaceAll(' ', '');
                        //
                        //     if (kDebugMode) {
                        //       print(
                        //           "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode, _isScanningInProgress: $_isScanningInProgress");
                        //     }
                        //
                        //     if (barcode.isNotEmpty) {
                        //       String? dobScanned = "";
                        //       /// Testing code: not working, Scanner will generate multiple tap events and call when scanned driving licence with PDF417 format irrespective of this code here
                        //       if (barcode.contains('DBB')) {
                        //         // if (barcode.startsWith('@') || barcode.contains('\n')) {
                        //         // PDF417 often includes structured data with newlines or starts with '@' (AAMVA standard)
                        //         if (kDebugMode) {
                        //           print('PDF417 Detected: $barcode');
                        //         }
                        //         // var date = parseDOBFromBarcode(barcode);
                        //         dobScanned = parseDOBFromBarcode(barcode); //"${date?.month}/${date?.day}/${date?.year}";
                        //         _dobController.text = dobScanned ?? "";
                        //         if (kDebugMode) {
                        //           print("##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode, $dobScanned");
                        //         }
                        //         _isScanningInProgress = false;
                        //         setState(() {
                        //         });
                        //         return;
                        //       } else {
                        //         if (kDebugMode) {
                        //           print('Non-PDF417 Barcode: $barcode');
                        //         }
                        //       }
                        //       if (kDebugMode) {
                        //         print(
                        //             "##### DEBUG:Age Verification onBarcodeScanned - Scanned barcode: $barcode");
                        //       }
                        //     }
                        //     _isScanningInProgress = false;
                        //     setState(() {
                        //     });
                        //   },
                        //   child:
                        TextField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'mm/dd/yyyy',
                            hintStyle: TextStyle(color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark : Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Icon(
                              Icons.calendar_today_rounded,
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark : Colors.grey[600],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 1.2,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark : Colors.black87,
                          ),
                        ),
                        // ),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.42,
                    child: CustomNumPad(
                      numPadType: NumPadType.age, // Choose: login, payment, age
                      onDigitPressed: updateDob,
                      onClearPressed: clearDob,
                      isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isScanningInProgress ? null : () {
                            // _isScanningInProgress = true;
                            // Future.delayed(Duration(milliseconds: 2200)).whenComplete((){
                            if (kDebugMode) {
                              print("AgeVerification _onManualVerify() 1 _isScanningInProgress: $_isScanningInProgress");
                            }
                            if(!_isScanningInProgress) _onManualVerify();
                            // });

                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4C5F7D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Manually Verified',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isVerifyEnabled ? _onVerifyAge : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isVerifyEnabled ? Colors.red : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Verify Age',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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

        // Date Picker Overlay
        if (_showDatePicker)
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.popUpsBackground : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Date Picker Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? Colors.grey[800] : Colors.grey[100],
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
                                    ? ThemeNotifier.textDark : Colors.black87,
                              ),
                            ),
                            IconButton(
                              onPressed: _hideDatePicker,
                              icon: Icon(
                                Icons.close,
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date Picker
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: SfDateRangePicker(
                            onSelectionChanged: _onDatePickerSelectionChanged,
                            selectionMode: DateRangePickerSelectionMode.single,
                            initialSelectedDate: _selectedDate,
                            initialDisplayDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                            maxDate: DateTime.now(),
                            minDate: DateTime(1900),
                            showNavigationArrow: true,
                            monthViewSettings: DateRangePickerMonthViewSettings(
                              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                                textStyle: TextStyle(
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? ThemeNotifier.textDark : Colors.black87,
                                ),
                              ),
                            ),
                            monthCellStyle: DateRangePickerMonthCellStyle(
                              textStyle: TextStyle(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark : Colors.black87,
                              ),
                              todayTextStyle: TextStyle(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? Colors.white : Colors.black,
                              ),
                            ),
                            headerStyle: DateRangePickerHeaderStyle(
                              textStyle: TextStyle(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            yearCellStyle: DateRangePickerYearCellStyle(
                              textStyle: TextStyle(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark : Colors.black87,
                              ),
                            ),
                            allowViewNavigation: true,
                            view: DateRangePickerView.decade,
                          ),
                        ),
                      ),

                      // Date Picker Actions
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
                                      ? ThemeNotifier.textDark : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _onDatePickerConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFE6464),
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
          ),
      ],
    );
  }
}

// Helper class to show the popup
class AgeVerificationHelper {
  static Future<void> showAgeVerification({
    required BuildContext context,
    //required String productName,
    required int minimumAge,
    required VoidCallback onManualVerify,
    required VoidCallback onAgeVerified,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AgeVerificationPopup(
        // productName: productName,
        minimumAge: minimumAge,
        onManualVerify: onManualVerify,
        onAgeVerified: onAgeVerified,
        onCancel: onCancel,
      ),
    );
  }
}