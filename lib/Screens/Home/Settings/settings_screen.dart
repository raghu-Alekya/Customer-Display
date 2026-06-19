import 'package:enum_to_string/enum_to_string.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Home/Settings/printer_setup_screen.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:provider/provider.dart';
import 'package:thermal_printer/thermal_printer.dart';

import '../../../Constants/text.dart';
import '../../../Database/assets_db_helper.dart';
import '../../../Database/db_helper.dart';
import '../../../Database/printer_db_helper.dart';
import '../../../Database/store_db_helper.dart';
import '../../../Database/user_db_helper.dart';
import '../../../Helper/Extentions/theme_notifier.dart';
import '../../../Helper/native_usb_scan_bridge.dart';
import '../../../Utilities/global_utility.dart';
import '../../../Preferences/pinaka_preferences.dart';
import '../../../Repositories/Auth/store_validation_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../Widgets/scanner_guard.dart';

class SettingsScreen extends StatefulWidget { // Build #1.0.6 - Added Settings Screen
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String keyboardType = "Virtual";
  bool quickProductAdd = false;
  bool outOfStockManage = true;
  String cacheDuration = "Never";
  String? appearance;
  bool enableGST = false;
  String selectedLanguage = "English";
  bool isRetailer = true;
  String layoutSelection = ""; // Default layout
  File? _selectedIcon;
  File? _selectedReceiptIcon; // Build #1.0.207: Added this line for receipt icon
  String? profilePhotoPath;
  String? userRole; //Build #1.0.170
  final PrinterDBHelper printerDBHelper = PrinterDBHelper(); //Build #1.0.122
  late ThemeNotifier _themeHelper; // Build #1.0.207: Added this line

  TextEditingController nameController = TextEditingController();
  TextEditingController contactNoController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController gstInController = TextEditingController();
  TextEditingController headerController = TextEditingController();
  TextEditingController footerController = TextEditingController();
  TextEditingController deviceIdController = TextEditingController();
  TextEditingController posNoController = TextEditingController();
  final PinakaPreferences _preferences = PinakaPreferences(); // Create an instance
  final PrinterSettings _printerSettings = PrinterSettings(); // Build #1.0.226
  @override
  void initState() {
    super.initState();
    ScannerGuard.isCouponPopupOpen = true;
    _themeHelper = Provider.of<ThemeNotifier>(context, listen: false); // Build #1.0.207: Initialize here
    _loadUserDataFromDB();
    _loadPrinterData(); //Build #1.0.122: Updated code: data loading from db
    // Build #1.0.226: Load printer settings & ensure initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrinterSettings();
    });
    _addThemeListener();   // Build #1.0.207: Fixed -> theme options is not updating in settings screen when updated from other screen top bar
  }

  // Build #1.0.226: Added this method to load printer settings
  Future<void> _loadPrinterSettings() async { // Changed to async
    if (kDebugMode) {
      print("#### [LOAD] Loading printer settings...");
    }

    try {
      await _printerSettings.loadPrinter(); // Added await

      if (mounted) {
        setState(() {
          if (kDebugMode) {
            print("#### [LOAD] Printer settings loaded: ${_printerSettings.selectedPrinter?.deviceName ?? 'None'}");
            print("#### [LOAD] Printer state: ${_printerSettings.selectedPrinter?.state}");
          }
        });
      }
    } catch (error) {
      if (kDebugMode) {
        print("#### [ERROR] Failed to load printer settings: $error");
      }
    }
  }
  // Build #1.0.207: Added this method to listen for theme changes
  void _addThemeListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _themeHelper.addListener(_onThemeChanged);
    });
  }

  // Build #1.0.207: Added this callback method
  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        appearance = _themeHelper.themeMode == ThemeMode.dark
            ? TextConstants.darkText
            : TextConstants.lightText;
      });
    }
  }  // # Build 1.0.182(option automatically change when tapped in top bar)

  Future<void> _loadUserDataFromDB() async {
    try {
      final userData = await UserDbHelper().getUserData();

      // NEW: Load store details from Asset Table (Recommended)
      final storeDetails = await AssetDBHelper.instance.getStoreDetails();

      final deviceDetails = await GlobalUtility.getDeviceDetails();

      if (kDebugMode) {
        print("#### Loading user data: $userData");
        print("#### Loading store details from Asset: ${storeDetails?.name}");
      }

      if (userData != null) {
        setState(() {
          nameController.text = userData[AppDBConst.userDisplayName] ?? "Unknown Name";
          emailController.text = userData[AppDBConst.userEmail] ?? "test@pinaka.com";
          deviceIdController.text = deviceDetails['device_id'] ?? "unknown";

          // Theme
          appearance = _themeHelper.themeMode == ThemeMode.dark
              ? TextConstants.darkText
              : TextConstants.lightText;

          layoutSelection = userData[AppDBConst.layoutSelection] ?? SharedPreferenceTextConstants.navLeftOrderRight;
          profilePhotoPath = userData[AppDBConst.profilePhoto];
          userRole = userData[AppDBConst.userRole] ?? "Unknown Role";

          if (profilePhotoPath != null) {
            _selectedIcon = File(profilePhotoPath!);
          }
        });
      }

      // ==================== UPDATED STORE DETAILS ====================
      if (storeDetails != null) {
        if (kDebugMode) {
          print("### Loaded Store Details from AssetDB: ${storeDetails.name}");
        }

        setState(() {
          companyNameController.text = storeDetails.name;
          contactNoController.text = storeDetails.phoneNumber ?? "";
          // gstInController.text = storeData[AppDBConst.licenseKey] ?? ""; // Keep if needed from validation
          // You can add more fields from StoreDetails model if required
        });
      }
      // Fallback: Keep old Store Validation logic (for backward compatibility)
      else {
        final storeData = await StoreDbHelper.instance.getStoreValidationData();
        if (storeData != null) {
          if (kDebugMode) print("### Fallback: Using old Store Validation data");
          setState(() {
            contactNoController.text = storeData[AppDBConst.storePhone] ?? "";
            companyNameController.text = storeData[AppDBConst.storeName] ?? "";
            gstInController.text = storeData[AppDBConst.licenseKey] ?? "";
          });
        }
      }

      if (kDebugMode) {
        print("#### User & Store data loading completed");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading user/store data: $e");
      }
    }
  }

  //Build #1.0.122: New method for printer data, data loading from db
  Future<void> _loadPrinterData() async {
    try {
      final printerData = await printerDBHelper.getPrinterFromDB();
      if (kDebugMode) {
        print("#### [LOAD] Printer data retrieved: ${printerData.length} records");
      }

      if (printerData.isNotEmpty) {
        setState(() {
          headerController.text = printerData.first[AppDBConst.receiptHeaderText] ?? "";
          footerController.text = printerData.first[AppDBConst.receiptFooterText] ?? "";
          if (printerData.first[AppDBConst.receiptIconPath] != null) {
            _selectedReceiptIcon = File(printerData.first[AppDBConst.receiptIconPath]); // Change to _selectedReceiptIcon
          }
        });

        if (kDebugMode) {// Build #1.0.226
          print("#### [LOAD] Receipt settings loaded: Header='${headerController.text}', Footer='${footerController.text}'");
        }
      } else {
        if (kDebugMode) {
          print("#### [LOAD] No printer data found in database");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("#### [ERROR] Error loading printer data: $e");
      }
    }
  }

//Build #1.0.122: Update save settings
  Future<void> _saveSettings() async {
    final userData = await UserDbHelper().getUserData();
    if (kDebugMode) {
      print("#### Saving settings for user: ${userData?[AppDBConst.userId]}");
    }
    if (userData != null) {
      // Save user settings
      await UserDbHelper().saveUserSettings({
        AppDBConst.themeMode: appearance == TextConstants.darkText ? ThemeMode.dark.toString() : ThemeMode.light.toString(),
        AppDBConst.layoutSelection: layoutSelection,
        AppDBConst.profilePhoto: profilePhotoPath,
      });
      if (kDebugMode) {
        print("#### Saved user settings: theme=$appearance, layout=$layoutSelection, photo=$profilePhotoPath");
      }

      // Get current printer data
      var printer = _printerSettings.selectedPrinter ?? BluetoothPrinter();

      // Update printer with receipt settings
      await printerDBHelper.updatePrinterToDB(BluetoothPrinter(
        deviceName: printer.deviceName ?? '',
        productId: printer.productId ?? '',
        vendorId: printer.vendorId ?? '',
        typePrinter: printer.typePrinter,
        // Added receipt settings
        receiptIconPath: _selectedReceiptIcon?.path,  // Build #1.0.207: Changed to _selectedReceiptIcon
        receiptHeaderText: headerController.text,
        receiptFooterText: footerController.text,
      ));

      if (kDebugMode) {
        print("#### Saved printer settings: header=${headerController.text}, footer=${footerController.text}");
      }
    }
  }

  // Build #1.0.108: for receipt image selection
  Future<void> _pickIcon() async {
    if (kDebugMode) print("### Picking new icon/image");
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (kDebugMode) print("### Image selected: ${pickedFile.path}");

        final imageFile = File(pickedFile.path);
        if (!imageFile.existsSync()) {
          if (kDebugMode) print("### Error: File doesn't exist at path");
          return;
        }

        final image = await decodeImageFromList(await imageFile.readAsBytes());
        if (image.width <= 128 && image.height <= 128 && pickedFile.path.endsWith('.png')) {
          setState(() {
            _selectedReceiptIcon = imageFile;  // Build #1.0.207: Changed to _selectedReceiptIcon
            if (kDebugMode) print("### Valid PNG image selected (128x128 or smaller)");
          });
        } else {
          if (kDebugMode) print("### Invalid image dimensions or format");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a PNG image with max 128x128')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print("### Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image')),
      );
    }
  }

  //Build #1.0.122: Added this new method to pick profile photo
  Future<void> _pickProfilePhoto() async {
    if (kDebugMode) print("### Picking new profile photo");
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (kDebugMode) print("### Profile photo selected: ${pickedFile.path}");

        final imageFile = File(pickedFile.path);
        setState(() {
          _selectedIcon = imageFile;
          profilePhotoPath = imageFile.path; // Update profile photo path
        });

        if (kDebugMode) print("### Profile photo updated successfully");
      }
    } catch (e) {
      if (kDebugMode) print("### Error picking profile photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select profile photo')),
      );
    }
  }


  @override
  void dispose() {
    ScannerGuard.isCouponPopupOpen = false;
    _themeHelper.removeListener(_onThemeChanged);  // # Build 1.0.182(option automatically change when tapped in top bar)
    nameController.dispose();
    contactNoController.dispose();
    emailController.dispose();
    deviceIdController.dispose();
    super.dispose();
  }

  // Build #1.0.226: Added this method to remove printer from DB and clear from settings
  Future<void> _removePrinter() async {
    try {
      if (kDebugMode) {
        print("#### [DEBUG] Removing printer from database...");
      }

      final db = await DBHelper.instance.database;
      int result = await db.delete(
        AppDBConst.printerTable,
        where: '${AppDBConst.printerId} = ?',
        whereArgs: [1],
      );

      if (kDebugMode) {
        print("#### [DEBUG] Delete operation result: $result rows affected");
      }

      // Clear from printer settings
      _printerSettings.selectedPrinter = null;

      // Clear receipt settings controllers
      setState(() {
        headerController.clear();
        footerController.clear();
        _selectedReceiptIcon = null;
      });

      if (kDebugMode) {
        print("#### [DEBUG] Printer removed successfully from DB and settings cleared");
        print("#### [DEBUG] Current selected printer: ${_printerSettings.selectedPrinter}");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Printer removed successfully"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      if (kDebugMode) {
        print("#### [ERROR] Error removing printer: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to remove printer"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  ///  Build #1.0.226: TESTING FUNCTION - REMOVE IN PRODUCTION
  /// This bypasses actual printer connection for testing
//   Future<void> _addTestPrinter() async {
//     if (kDebugMode) {
//       print("#### [TEST] Adding test printer for development...");
//       print("#### [TEST] No physical printer required");
//     }
//
//     try {
//       final testPrinter = BluetoothPrinter(
//         deviceName: "Test",
//         productId: "001",
//         vendorId: "002",
//         typePrinter: PrinterType.bluetooth,
//         state: true,
//       );
//
//       // Add to database
//       await printerDBHelper.addPrinterToDB(testPrinter);
//
//       // Update settings
//       _printerSettings.selectedPrinter = testPrinter;
//
//       setState(() {
//         if (kDebugMode) {
//           print("#### [TEST] Test printer added successfully: ${testPrinter.deviceName}");
//           print("#### [TEST] Printer state: ${testPrinter.state}");
//         }
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Test printer added (Dev Mode)')),
//       );
//
//     } catch (e) {
//       if (kDebugMode) {
//         print("#### [TEST ERROR] Failed to add test printer: $e");
//       }
//     }
//   }

  @override
  Widget build(BuildContext context) {
    //   final themeHelper = Provider.of<ThemeNotifier>(context);  // Build #1.0.207

    return Scaffold(
      backgroundColor: _themeHelper.getTheme(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeHelper.getTheme(context).textTheme.bodyLarge?.color),
          onPressed: () {
            // NativeUsbScanBridge.dispatchFromRaw('/dev/bus/usb/001/003: 2721933233');
            print("pppppppppppppppp");
           Navigator.pop(context); // Return true to indicate a refresh
          },
        ),
        title: Text(
          TextConstants.settingsHeaderText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _themeHelper.getTheme(context).textTheme.bodyLarge?.color,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              await _saveSettings(); //Build #1.0.122
              Navigator.pop(context);
            },
            child: Text(TextConstants.saveChangesBtnText, style: TextStyle(color: Colors.black)),
          ),
          SizedBox(width: 16),
        ],
        backgroundColor: _themeHelper.getTheme(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildCombinedSections(_themeHelper),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedSections(ThemeNotifier themeHelper) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left
              children: [
                _buildPersonalInfoSection(),
                Divider(color: Colors.grey[800], thickness: 1),
                _buildDeviceDetailsSection(),
                Divider(color: Colors.grey[800], thickness: 1),
                _buildAppearanceSection(themeHelper),
                Divider(color: Colors.grey[800], thickness: 1),
                _buildAppVersionSection(), // Build #1.0.151: Displaying App version
                // Divider(color: Colors.grey[800], thickness: 1),
                // _buildCacheDurationSection(), //Build #1.0.122: no need
              ],
            ),
          ),
          // Vertical Divider between left and right columns
          VerticalDivider(
            color: Colors.grey[800],
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
          SizedBox(width: 16),
          // Right Side Column
          Expanded(
            child: Column(
              children: [
                _buildReceiptSettingSection(),
                Divider(color: Colors.grey[800], thickness: 1),
                // _buildTaxesAndLanguageSection(),
                // Divider(color: Colors.grey[800], thickness: 1),
                _buildPrinterSettingsSection(),
                Divider(color: Colors.grey[800], thickness: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TextConstants.personalInfoText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 8),
        Text(TextConstants.personalInfoSubText,
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        SizedBox(height: 16),
        Row(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () {  // Build #1.0.207: Disable Edit for profile photo
                    // _pickProfilePhoto(); // Commented out as requested
                  }, // Changed to use the new function
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[800],
                      child: GlobalUtility.buildImageWidget( //Build #1.0.170: Fixed - User Profile photo not loading, created GlobalUtility function and using here!
                        imagePath: profilePhotoPath,
                        imageFile: _selectedIcon,
                        fit: BoxFit.contain,  // Build #1.0.207: Changed from cover to contain
                        defaultIcon: Icons.perm_identity, // Default icon for user profile
                        defaultIconColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Positioned(
                //   top: 0,
                //   right: 0,
                //   child: GestureDetector(
                //     onTap: _pickProfilePhoto, // Same function for edit icon
                //     child: Container(
                //       padding: EdgeInsets.all(3),
                //       // decoration: BoxDecoration(
                //       //   color: Colors.white,
                //       //   shape: BoxShape.rectangle,
                //       // ),
                //       child: Icon(Icons.edit, size: 10, color: Colors.white),
                //     ),
                //   ),
                // ),
              ],
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TextConstants.userText, style: TextStyle(fontSize: 16, color: Colors.white)),
                Text(userRole ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.tealAccent)), //Build #1.0.170: Fixed - User role not updating as per login
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    label: TextConstants.fullNameText, controller: nameController, isReadOnly: true)),
            SizedBox(width: 10),
            Expanded(
                child: _buildTextField(
                    label: TextConstants.contactNoText, controller: contactNoController, isReadOnly: true)),
          ],
        ),
        _buildTextField(label: TextConstants.emailText, controller: emailController,isReadOnly: true),
        // _buildTextField(
        //     label: "Subscription Type",
        //     controller: TextEditingController(text: storeData?[AppDBConst.subscriptionType] ?? ""),
        //     isReadOnly: true),
        // _buildTextField(
        //     label: "Expiration Date",
        //     controller: TextEditingController(text: storeData?[AppDBConst.expirationDate] ?? ""),
        //     isReadOnly: true),
      ],
    );
  }

  // Build #1.0.108: Modified _buildReceiptSettingSection
  Widget _buildReceiptSettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TextConstants.receiptText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 8),
        Text(TextConstants.ownReceiptText,
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: _pickIcon,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GlobalUtility.buildImageWidget( //Build #1.0.170: Fixed - User Profile photo not loading, created GlobalUtility function and using here!
                      imageFile: _selectedReceiptIcon, // Changed to _selectedReceiptIcon
                      fit: BoxFit.contain,  // Build #1.0.207: Changed from cover to contain
                      defaultIcon: Icons.image, // Default icon for company/receipt
                      defaultIconColor: Colors.white70,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(3),
                      // decoration: BoxDecoration(
                      //   color: Colors.tealAccent,
                      //   shape: BoxShape.circle,
                      // ),
                      child: Icon(Icons.edit, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                  label: TextConstants.companyNameText,
                  controller: companyNameController,
                  hintText: TextConstants.companyNameHintText,
                  isReadOnly: true),

            ),
          ],
        ),
        _buildTextField(label: TextConstants.gstinText, controller: gstInController, hintText: TextConstants.gstinHintText, isReadOnly: true),
        _buildTextField(
            label: TextConstants.headerText,
            hintText: TextConstants.headerHintText,
            controller: headerController),
        _buildTextField(
            label: TextConstants.footerText,
            hintText: TextConstants.footerHintText,
            controller: footerController),
      ],
    );
  }

  Widget _buildDeviceDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(TextConstants.deviceDetailsText,
        //             style:
        //             TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        //         SizedBox(height: 4),
        //         Text(TextConstants.idPOSText,
        //             style: TextStyle(fontSize: 14, color: Colors.grey)),
        //       ],
        //     ),
        //     ElevatedButton.icon(
        //       onPressed: () {
        //         // Handle Copy Token action
        //         if (kDebugMode) {
        //           print("Token Copied");
        //         }
        //       },
        //       icon: Icon(Icons.copy, color: Colors.white),
        //       label: Text(TextConstants.copyTokenBtnText, style: TextStyle(color: Colors.white)),
        //       style: ElevatedButton.styleFrom(
        //         backgroundColor: Colors.teal,
        //       ),
        //     ),
        //   ],
        // ),
        // SizedBox(height: 16),
        _buildTextField(
            label: TextConstants.deviceIdText,
            controller: deviceIdController,
            isReadOnly: true),
        // SizedBox(height: 16), //Build #1.0.122: no need
        // _buildTextField(label: TextConstants.posNumberText, hintText: TextConstants.posNumberHintText),
        // SizedBox(height: 16),
        // Text(TextConstants.posForText, style: TextStyle(fontSize: 14, color: Colors.white70)),
        // _buildToggleButtons(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTaxesAndLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TextConstants.taxesText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(TextConstants.manageTaxesText, style: TextStyle(color: Colors.grey)),
          trailing: Text(TextConstants.addBtnText, style: TextStyle(color: Colors.cyan)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(TextConstants.enableGSTText, style: TextStyle(color: Colors.white)),
          trailing: Switch(
              value: enableGST,
              onChanged: (value) {
                setState(() => enableGST = value);
              }),
        ),
        Divider(color: Colors.grey[800], height: 32),
        Text(TextConstants.languageText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold , color: Colors.white)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(TextConstants.chooseLanText, style: TextStyle(color: Colors.grey)),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: selectedLanguage,
              underline: SizedBox(),
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: Colors.white),
              items: ["English", "Spanish", "French"]
                  .map((lang) => DropdownMenuItem(
                value: lang,
                child: Text(lang, style: TextStyle(color: Colors.white)),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedLanguage = value!);
              },
              icon: Icon(Icons.arrow_drop_down, color: Colors.white), // Dropdown icon color
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeNotifier themeManager) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TextConstants.appearanceText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(TextConstants.screenModeText,
            style: TextStyle(fontSize: 14, color: Colors.white)),
        Row(
          children: [
            _buildAppearanceOption(TextConstants.lightText, themeManager),
            _buildAppearanceOption(TextConstants.darkText, themeManager),
          ],
        ),
        SizedBox(height: 16),
        Text(TextConstants.layoutSelectionHeader,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Column(
          children: [
            _buildLayoutOption(TextConstants.layoutNavLeftOrderRight, SharedPreferenceTextConstants.navLeftOrderRight),
            _buildLayoutOption(TextConstants.layoutNavRightOrderLeft, SharedPreferenceTextConstants.navRightOrderLeft),
            _buildLayoutOption(TextConstants.layoutNavBottomOrderLeft, SharedPreferenceTextConstants.navBottomOrderLeft),
            _buildLayoutOption(TextConstants.layoutNavBottomOrderRight, SharedPreferenceTextConstants.navBottomOrderRight),
          ],
        ),
        // Text(TextConstants.selectKeyboardText, // Build #1.0.15 : removed Keyboard type UI
        //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        // Row(
        //   children: [
        //     _buildRadioOption(TextConstants.virtualText),
        //     _buildRadioOption(TextConstants.systemText),
        //     _buildRadioOption(TextConstants.bothText),
        //   ],
        // ),
        // _buildSwitchOption(TextConstants.quickProAddText, quickProductAdd, (value) {
        //   setState(() => quickProductAdd = value);
        // }),
        // _buildSwitchOption(TextConstants.outOfStockMngText, outOfStockManage, (value) {
        //   setState(() => outOfStockManage = value);
        // }),
      ],
    );
  }

  // Build #1.0.151: Displaying App version
  // get the app version + build number to show
  Widget _buildAppVersionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TextConstants.appVersion,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                TextConstants.appVersionLoading,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              );
            } else if (snapshot.hasError) {
              if (kDebugMode) {
                print("#### Error getting package info: ${snapshot.error}");
              }
              return Text(
                TextConstants.appVersionError,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              );
            } else if (snapshot.hasData) {
              final packageInfo = snapshot.data!;
              final version = '${packageInfo.version}+${packageInfo.buildNumber}';
              if (kDebugMode) {
                print("#### App Version: $version");
              }
              return Text(
                version,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              );
            } else {
              return Text(
                TextConstants.appVersionLoading,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              );
            }
          },
        ),
      ],
    );
  }

  //Build #1.0.54: Add _buildLayoutOption
  Widget _buildLayoutOption(String title, String value) {
    return Row(
      children: [
        Radio(
          value: value,
          groupValue: layoutSelection,
          onChanged: (value) {
            setState(() => layoutSelection = value.toString());
            //  _preferences.saveLayoutSelection(value.toString()); // This updates the notifier
            if (PinakaPreferences.layoutSelectionNotifier.value != layoutSelection) {
              PinakaPreferences.layoutSelectionNotifier.value = layoutSelection;
            }
          },
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
        ),
        Text(title, style: TextStyle(color: Colors.white)),
      ],
    );
  }
  Widget _buildPrinterSettingsSection() {
    var name = _printerSettings.selectedPrinter?.deviceName ?? '';
    var connection = _printerSettings.selectedPrinter?.state ?? false;

    if (kDebugMode) {
      print("#### [UI] Building printer section - Name: '$name', Connected: $connection");
      print("#### [UI] Selected printer object: ${_printerSettings.selectedPrinter}");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TextConstants.printerSettText,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(TextConstants.connectedPrintText,
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            Spacer(),
            // Build #1.0.226: Always show add button - users can swap printers anytime
            ElevatedButton(
              onPressed: () {
                /// call printer setup screen
                if (kDebugMode) {
                  print("#### [ACTION] Add printer button pressed");
                  print("#### [ACTION] Navigating to PrinterSetup screen");
                }

                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => PrinterSetup(),
                )).then((result) {
                  if (result == TextConstants.refresh) {
                    if (kDebugMode) {
                      print("#### [ACTION] Returning from PrinterSetup - refreshing data");
                    }

                    // Build #1.0.226: Reload everything to ensure UI is updated
                    _printerSettings.loadPrinter().then((_) {
                      _loadPrinterData(); // Reload receipt settings
                      setState(() {
                        if (kDebugMode) {
                          print("#### [ACTION] UI refreshed after printer setup");
                          print("#### [ACTION] Current printer: ${_printerSettings.selectedPrinter?.deviceName ?? 'None'}");
                        }
                      });
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00FFAA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: Text(
                TextConstants.addBtnText,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10),
        ///Todo: show connected printer or Add printer button
        _printerSettings.selectedPrinter != null
            ? Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),),
              Spacer(),
              Icon(
                Icons.check_circle,
                color: ThemeNotifier.buttonDark,
                size: 25,
              ),
              // Remove printer button (X)
              IconButton( // Build #1.0.226: added close button
                icon: Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: _removePrinter,
                tooltip: "Remove Printer",
              ),
            ],
          ),
        ) :
        SizedBox(),
        //     : Center(
        //   child: Column(
        //     children: [
        //       SvgPicture.asset(
        //         'assets/svg/password_placeholder.svg', // Replace with actual asset path
        //         width: 120,
        //         height: 120,
        //       ),
        //       SizedBox(height: 20),
        //       Text(
        //         TextConstants.noPrinterText,
        //         style: TextStyle(
        //           color: Colors.white,
        //           fontSize: 18,
        //           fontWeight: FontWeight.bold,
        //         ),
        //       ),
        //       SizedBox(height: 20),
        //       /// Build #1.0.226: TEST BUTTON - REMOVE IN PRODUCTION
        //       // ElevatedButton(
        //       //   onPressed: _addTestPrinter,
        //       //   style: ElevatedButton.styleFrom(
        //       //     backgroundColor: Colors.blueGrey,
        //       //   ),
        //       //   child: Text(
        //       //     "Add Test Printer (Dev)",
        //       //     style: TextStyle(color: Colors.white),
        //       //   ),
        //       // ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _buildCacheDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(TextConstants.cacheText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(TextConstants.manageCacheText,
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
          Align(
            alignment: Alignment.topRight,
            child: ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.delete),
                label: Text(TextConstants.clearCacheText)),
          ),
        ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(TextConstants.cacheDurationText, style: TextStyle(fontSize: 14, color: Colors.white)),
            DropdownButton<String>(
                value: cacheDuration,
                dropdownColor: Colors.grey[800], // Dropdown background color
                onChanged: (String? newValue) {
                  setState(() => cacheDuration = newValue!);
                },
                items:
                ["Never", "1 Day", "1 Week", "1 Month"].map((String value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(color: Colors.white), // Dropdown item text color
                    ),
                  );
                }).toList(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white)
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
      {String label = "",
        String hintText = "",
        bool isReadOnly = false,
        TextEditingController? controller}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            style: TextStyle(color: Colors.white), // Change text color here
            readOnly: isReadOnly,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: 300,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => isRetailer = true);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isRetailer ? Colors.teal : Colors.black54,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      TextConstants.retailerText,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => isRetailer = false);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isRetailer ? Colors.teal : Colors.black54,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      TextConstants.distributorText,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title) {
    return Row(
      children: [
        Radio(
          value: title,
          groupValue: keyboardType,
          onChanged: (value) {
            setState(() => keyboardType = value.toString());
          },
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white; // Change the inner circle color when selected
            }
            return Colors.white; // Change the border color when unselected
          }),
        ),
        Text(title, style: TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildSwitchOption(
      String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.white)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

// Update _buildAppearanceOption
  Widget _buildAppearanceOption(String title, ThemeNotifier themeManager) {
    return Row(
      children: [
        Radio(
          value: title,
          groupValue: appearance,
          onChanged: (value) {
            setState(() {
              appearance = value.toString();
              // themeManager.setThemeMode( //Build #1.0.54: updated
              //     appearance == TextConstants.lightText ? ThemeMode.light : ThemeMode.dark
              // );
              // Build #1.0.207: Fixed -> theme options is not updating in settings screen when updated from other screen top bar
              final newTheme = appearance == TextConstants.lightText ? ThemeMode.light : ThemeMode.dark; // # Build 1.0.182(option automatically change when tapped in top bar)
              themeManager.setThemeMode(newTheme);

              // _preferences.saveAppThemeMode(themeManager.themeMode);
            });
          },
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white; // Change the inner circle color when selected
            }
            return Colors.white; // Change the border color when unselected
          }),
        ),
        Text(title, style: TextStyle(color: Colors.white)),
      ],
    );
  }
}