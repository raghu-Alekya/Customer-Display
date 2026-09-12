import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Helper/offline_helper.dart';
import 'inventory_categories_model.dart';

abstract class InventoryCategoriesRemoteDataSource {
  Future<List<InventoryCategoriesModel>> getCategories();
}

class InventoryCategoriesRemoteDataSourceImpl implements InventoryCategoriesRemoteDataSource {
  final http.Client client;

  InventoryCategoriesRemoteDataSourceImpl({required this.client});

  // Helper function to get token from DB
  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      if (kDebugMode) print("#### No active user found in database");
      throw Exception('No active user token found');
    }

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print("#### TOKEN FROM DBbbb: $token");
    return token;
  }


  @override
  Future<List<InventoryCategoriesModel>> getCategories() async {
    try {
      if (!await OfflineHelper.isNetworkAvailable()) {
        if (kDebugMode) debugPrint('#### Offline: inventory categories served as empty local list');
        return [];
      }
      final token = await _getTokenFromDb();

      final String fullUrl =
          "${UrlHelper.wooBaseUrl}products/categories";

      final Uri url = Uri.parse(fullUrl).replace(queryParameters: {
        'page': '1',
        'per_page': '100',
        'parent':'0',
      });

      if (kDebugMode) {
        debugPrint("#### FULL REQUEST URL: $url");
      }

      final response = await client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        debugPrint("#### STATUS CODE: ${response.statusCode}");
        debugPrint("#### RESPONSE BODY: ${response.body}");
      }

      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);

        return decoded
            .map((e) => InventoryCategoriesModel.fromJson(e))
            .toList();
      } else {
        throw Exception(
          'API Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('#### GET CATEGORIES ERROR: $e');
      debugPrint('#### STACK TRACE:\n$stackTrace');

      // Network/DNS failure is a normal offline condition. Keep the UI usable
      // instead of putting the raw ClientException into the dropdown.
      return [];
    }
  }

// Future<void> fetchSubCategories(int categoryId) async {
//   try {
//     final db = await DBHelper.instance.database;
//
//     final result = await db.query(
//       AppDBConst.userTable,
//       where:
//       '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
//       orderBy: '${AppDBConst.userId} DESC',
//       limit: 1,
//     );
//
//     if (result.isEmpty) throw Exception("No token found");
//
//     final token = result.first[AppDBConst.userToken] as String;
//
//     final Uri url = Uri.parse(
//       "${UrlHelper.wooBaseUrl}inventories/show-category-sublist",
//     ).replace(queryParameters: {
//       'category_id': categoryId.toString(),
//     });
//
//     final response = await http.get(
//       url,
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//       },
//     );
//
//     if (response.statusCode == 200) {
//       final List decoded = json.decode(response.body);
//
//       setState(() {
//         subCategories = decoded
//             .map((e) => InventoryCategoriesModel.fromJson(e))
//             .toList();
//       });
//     } else {
//       throw Exception("Subcategory API failed");
//     }
//   } catch (e) {
//     debugPrint("SUBCATEGORY ERROR: $e");
//   }
// }

}