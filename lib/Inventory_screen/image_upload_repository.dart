import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../Database/db_helper.dart';
import '../Helper/url_helper.dart';

class ImageUploadRepository {
  String get _uploadEndpoint {
    final base = UrlHelper.wooBaseUrl;
    // wooBaseUrl is typically: https://domain.com/wp-json/wc/v3/
    // We need:                 https://domain.com/wp-json/wp/v2/media
    final endpoint = base.replaceAll('/wc/v3/', '/wp/v2/media');

    if (kDebugMode) {
      print('╔══════════════════════════════════════════════════╗');
      print('║         IMAGE UPLOAD ENDPOINT RESOLVED           ║');
      print('╠══════════════════════════════════════════════════╣');
      print('║ wooBaseUrl  : $base');
      print('║ uploadEndpoint: $endpoint');
      print('╚══════════════════════════════════════════════════╝');
    }

    return endpoint;
  }

  Future<String?> uploadImage({
    required File imageFile,
    String? fileName,
  }) async {
    if (kDebugMode) {
      print('');
      print('┌─────────────────────────────────────────────────┐');
      print('│            uploadImage() CALLED                 │');
      print('├─────────────────────────────────────────────────┤');
      print('│ imageFile.path : ${imageFile.path}');
      print('│ fileName       : $fileName');
    }

    // ── 1. Check file actually exists on disk ─────────────────────
    final bool fileExists = imageFile.existsSync();
    final int fileSize   = fileExists ? imageFile.lengthSync() : 0;

    if (kDebugMode) {
      print('│ file exists    : $fileExists');
      print('│ file size      : $fileSize bytes');
    }

    if (!fileExists) {
      if (kDebugMode) print('│ ✗ FILE DOES NOT EXIST → aborting upload');
      print('└─────────────────────────────────────────────────┘');
      return null;
    }

    if (fileSize == 0) {
      if (kDebugMode) print('│ ✗ FILE IS EMPTY → aborting upload');
      print('└─────────────────────────────────────────────────┘');
      return null;
    }

    try {
      // ── 2. Get token ──────────────────────────────────────────────
      if (kDebugMode) print('│ Fetching JWT token from DB...');
      final String token = await _getTokenFromDb();

      // ── 3. Build endpoint ─────────────────────────────────────────
      final String endpoint = _uploadEndpoint;
      final String effectiveFileName =
          fileName ?? imageFile.path.split('/').last;

      if (kDebugMode) {
        print('│ effectiveFileName : $effectiveFileName');
        print('│ endpoint          : $endpoint');
        print('│ Sending multipart request...');
        print('└─────────────────────────────────────────────────┘');
      }

      // ── 4. Build multipart request ────────────────────────────────
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Disposition': 'attachment; filename="$effectiveFileName"',
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: effectiveFileName,
        ),
      );

      if (kDebugMode) {
        print('┌─────────────────────────────────────────────────┐');
        print('│ REQUEST HEADERS:');
        request.headers.forEach((k, v) {
          // mask token after first 20 chars
          final display = k == 'Authorization' && v.length > 27
              ? '${v.substring(0, 27)}...'
              : v;
          print('│   $k: $display');
        });
        print('│ FILES attached: ${request.files.length}');
        for (final f in request.files) {
          print('│   field="${f.field}" filename="${f.filename}" '
              'length=${f.length}');
        }
        print('└─────────────────────────────────────────────────┘');
      }

      // ── 5. Send ───────────────────────────────────────────────────
      final streamedResponse = await request.send();
      final int statusCode   = streamedResponse.statusCode;
      final String body      = await streamedResponse.stream.bytesToString();

      if (kDebugMode) {
        print('┌─────────────────────────────────────────────────┐');
        print('│ RESPONSE STATUS : $statusCode');
        print('│ RESPONSE BODY   : ${body.length > 300 ? body.substring(0, 300) + "…" : body}');
        print('└─────────────────────────────────────────────────┘');
      }

      // ── 6. Parse success ──────────────────────────────────────────
      if (statusCode == 200 || statusCode == 201) {
        final jsonData = jsonDecode(body) as Map<String, dynamic>;
        final String? imageUrl = jsonData['source_url'] as String?;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          if (kDebugMode) {
            print('╔══════════════════════════════════════════════════╗');
            print('║           IMAGE UPLOAD SUCCESS ✓                 ║');
            print('║  URL: $imageUrl');
            print('╚══════════════════════════════════════════════════╝');
          }
          return imageUrl;
        }

        // 201 but no source_url — log the full json keys to debug
        if (kDebugMode) {
          print('✗ Upload returned $statusCode but no source_url found.');
          print('  Available keys: ${jsonData.keys.toList()}');
        }
        return null;
      }

      // ── 7. Handle known error codes ───────────────────────────────
      if (kDebugMode) {
        if (statusCode == 401) {
          print('✗ 401 Unauthorized — JWT token is invalid or expired.');
        } else if (statusCode == 403) {
          print('✗ 403 Forbidden — User lacks media upload permissions.');
        } else if (statusCode == 413) {
          print('✗ 413 Payload Too Large — File exceeds server upload limit.');
        } else {
          print('✗ Upload failed with status $statusCode.');
        }
      }
      return null;

    } catch (e, stack) {
      if (kDebugMode) {
        print('╔══════════════════════════════════════════════════╗');
        print('║        IMAGE UPLOAD EXCEPTION ✗                  ║');
        print('╠══════════════════════════════════════════════════╣');
        print('║ $e');
        print('╚══════════════════════════════════════════════════╝');
        print(stack);
      }
      return null;
    }
  }

  Future<String> _getTokenFromDb() async {
    if (kDebugMode) print('│ _getTokenFromDb() → querying ${AppDBConst.userTable}...');

    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where:
      '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (kDebugMode) {
      print('│ DB rows returned : ${result.length}');
    }

    if (result.isEmpty) {
      throw Exception(
          'No active user token found in database — check ${AppDBConst.userTable}');
    }

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      final preview = token.length > 20 ? token.substring(0, 20) : token;
      print('│ Token preview    : $preview...');
    }

    return token;
  }
}