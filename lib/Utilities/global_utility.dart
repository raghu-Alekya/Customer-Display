import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import 'package:flutter/material.dart';

class GlobalUtility { //Build #1.0.126: Added for re-Use code at global level

  static Future<ByteData?> fileToByteData(File file) async {
    try {
      // 1. Read the file as a list of bytes (Uint8List)
      Uint8List uint8List = await file.readAsBytes();

      // 2. Create ByteData from the Uint8List
      // ByteData.view creates a ByteData view on the existing buffer of the Uint8List
      // without copying the data, which is efficient.
      ByteData byteData = ByteData.view(uint8List.buffer);

      // Alternatively, if you need a ByteData object that owns its own data
      // (e.g., if the original Uint8List might change and you need an independent snapshot),
      // you could copy it, though this is less common for simple conversions:
      // ByteData byteData = ByteData(uint8List.lengthInBytes);
      // for (int i = 0; i < uint8List.lengthInBytes; i++) {
      //   byteData.setUint8(i, uint8List[i]);
      // }

      return byteData;
    } catch (e) {
      if (kDebugMode) {
        print("Error converting file to ByteData: $e");
      }
      return null;
    }
  }

  static Future<Map<String, String>> getDeviceDetails() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';
    String model = '';
    String imei = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id ?? 'unknown';
        model = androidInfo.model ?? 'unknown';
        // IMEI typically not available without special permissions
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        model = iosInfo.model ?? 'unknown';
        // IMEI not available on iOS
      }
    } catch (e) {
      if (kDebugMode) print("Error getting device details: $e");
    }

    return {
      'device_id': deviceId,
      'model': model,
      'imei': imei,
    };
  }

  // Build #1.0.138: calculate gross total
  // static double getGrossTotal(List<Map<String, dynamic>> orderItems) {
  //   return orderItems
  //       .where((item) {
  //     final type = item[AppDBConst.itemType]?.toString() ?? '';
  //     return type == ItemType.product.value || type == ItemType.customProduct.value;
  //   // }).fold(0.0, (sum, item) => sum + (item[AppDBConst.itemSumPrice] as num).toDouble());
  //   }).fold(0.0, (sum, item) {
  //     double total = sum + (item[AppDBConst.itemSumPrice] as num).toDouble();
  //     if (kDebugMode) {
  //       print("  *** getGrossTotal sum: $sum, itemSumPrice: ${item[AppDBConst.itemSumPrice]}, total: $total ***");
  //     }
  //     return total;
  //   });
  // }

  //Build #1.0.146: Updated Code - We are subtracting payout from gross total
  static double getGrossTotal(List<Map<String, dynamic>> orderItems) {
    return orderItems.fold(0.0, (sum, item) {
      final type = item[AppDBConst.itemType]?.toString() ?? '';
      final itemPrice = (item[AppDBConst.itemSumPrice] as num).toDouble();

      if (type == ItemType.product.value || type == ItemType.customProduct.value) {
        // Add product prices
        final total = sum + itemPrice;
        if (kDebugMode) {
          print("  *** Adding product: $sum + $itemPrice = $total ***");
        }
        return total;
      } else if (type == ItemType.payout.value) {
        // Subtract payout values (always reduce total, regardless of sign)
        final payoutValue = itemPrice.abs(); // Ensure we subtract a positive value
        final total = sum - payoutValue;
        if (kDebugMode) {
          print("  *** Subtracting payout: $sum - $payoutValue = $total ***");
        }
        return total;
      } else {
        // Ignore other types (like coupon)
        return sum;
      }
    });
  }

  //Build #1.0.170: Added buildImageWidget for load api url images or local file images path
  static Widget buildImageWidget({
    String? imagePath,
    File? imageFile,
    required BoxFit fit,
    required IconData defaultIcon,
    Color defaultIconColor = Colors.white70,
  }) {
    // Debug logging
    if (kDebugMode) {
      print('### buildImageWidget called with:');
      print('### imagePath: $imagePath');
      print('### imageFile: ${imageFile?.path}');
    }

    // If both are null, return default icon
    if (imagePath == null && imageFile == null) {
      if (kDebugMode) {
        print("### No image path or file provided, using default icon");
      }
      return Icon(defaultIcon, color: defaultIconColor);
    }

    // Handle File first if provided
    if (imageFile != null) {
      try {
        if (imageFile.existsSync()) {
          if (kDebugMode) {
            print("### Loading image from file: ${imageFile.path}");
          }
          return Image.file(
            imageFile,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print("### Error loading file image: $error");
              }
              return Icon(defaultIcon, color: defaultIconColor);
            },
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("### Exception loading file: $e");
        }
      }
    }

    // Handle imagePath if provided
    if (imagePath != null) {
      // Check if it's a network URL
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        if (kDebugMode) {
          print("### Loading network image from URL: $imagePath");
        }
        return Image.network(
          imagePath,
          fit: fit,
          headers: {"Accept": "image/*"}, // Important for Gravatar
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print("### Error loading network image: $error");
            }
            return Icon(defaultIcon, color: defaultIconColor);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
              ),
            );
          },
        );
      }

      // Handle as local file path
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          if (kDebugMode) {
            print("### Loading image from local path: $imagePath");
          }
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print("### Error loading local image: $error");
              }
              return Icon(defaultIcon, color: defaultIconColor);
            },
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("### Exception loading local path: $e");
        }
      }
    }

    // Fallback to default icon
    if (kDebugMode) {
      print("### Falling back to default icon");
    }
    return Icon(defaultIcon, color: defaultIconColor);
  }

  // Build #1.0.189: Added global error message extraction utility
  static String extractErrorMessage(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return "Network error. Please check your connection.";
    }
    try {
      // Extract JSON part from error string
      final jsonMatch = RegExp(r'\{.*\}').firstMatch(error.toString());
      if (jsonMatch != null) {
        final errorJson = jsonDecode(jsonMatch.group(0)!);
        return errorJson['message']?.toString() ?? "Operation failed";
      }
      // Fallback to splitting error string
      return error.toString().split('message":"').last.split('","').first;
    } catch (_) {
      return "Operation failed";
    }
  }
}