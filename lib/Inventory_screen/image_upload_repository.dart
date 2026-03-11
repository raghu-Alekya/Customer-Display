import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../Database/db_helper.dart'; // for kDebugMode

class ImageUploadRepository {
  final String _baseUrl = 'https://merchantretail.alektasolutions.com/wp-json/wp/v2/media';

  Future<String?> uploadImage({
    required File imageFile,
    String? fileName,
  }) async {
    try {
      final token = await _getTokenFromDb();
      final String effectiveFileName = fileName ?? imageFile.path.split('/').last;

      // Prepare multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      // Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Disposition': 'attachment; filename="$effectiveFileName"',
      });

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: effectiveFileName,
        ),
      );

      // Optional: You can also add other fields if your backend expects them
      // request.fields['title'] = 'Product Image';
      // request.fields['alt_text'] = 'Product variant';

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 201 || streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final jsonData = jsonDecode(responseBody);

        final String? imageUrl = jsonData['source_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          if (kDebugMode) {
            print('Image uploaded successfully → $imageUrl');
          }
          return imageUrl;
        }

        if (kDebugMode) print('No source_url found in response');
        return null;
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        if (kDebugMode) {
          print('Image upload failed → ${streamedResponse.statusCode} $errorBody');
        }
        return null;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('Image upload exception: $e');
        print(stack);
      }
      return null;
    }
  }

  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('No active user token found in database');
    }

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print('Using JWT token: ${token.substring(0, 20)}...');
    return token;
  }
}