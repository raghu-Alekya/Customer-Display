import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Helper/offline_helper.dart';
import 'inventory_tag_model.dart';

abstract class Inventory_Tag_Remote_Data_Source {
  Future<List<Inventory_Tag_Model>> fetchInventoryTags();
}

class Inventory_Tag_Remote_Data_Source_Impl
    implements Inventory_Tag_Remote_Data_Source {
  final http.Client client;

  Inventory_Tag_Remote_Data_Source_Impl(this.client);

  @override


  Future<List<Inventory_Tag_Model>> fetchInventoryTags() async {
    if (!await OfflineHelper.isNetworkAvailable()) {
      if (kDebugMode) debugPrint('#### Offline: inventory tags served as empty local list');
      return [];
    }

    try {
      final db = await DBHelper.instance.database;

      final result = await db.query(
        AppDBConst.userTable,
        where:
        '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );

      if (result.isEmpty) {
        throw Exception('No active user token found');
      }

      final token = result.first[AppDBConst.userToken];

      final url =
          "${UrlHelper.wooBaseUrl}"
          "${UrlMethodConstants.products}"
          "${EndUrlConstants.gettags}";

      if (kDebugMode) {
        print("#### INVENTORY TAGS URL: $url");
      }

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List decoded = json.decode(response.body);
        return decoded
            .map((e) => Inventory_Tag_Model.fromJson(e))
            .toList();
      } else {
        if (kDebugMode) {
          print('#### API ERROR: ${response.statusCode}');
          print('#### BODY: ${response.body}');
        }
        throw Exception('Failed to load inventory tags');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('#### Inventory data unavailable: serving empty local list');
      return [];
    }
  }

}
