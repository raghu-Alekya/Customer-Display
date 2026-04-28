import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import 'inventory_categories_bloc/inventory_categories_bloc.dart';
import 'inventory_categories_bloc/inventory_categories_event.dart';
import 'inventory_categories_bloc/inventory_categories_state.dart';
import 'inventory_categories_model.dart'; // only for subcategory parsing

class InventoryCategoriesDropdown extends StatefulWidget {
  final dynamic selectedCategory;
  final Function(dynamic value)? onCategorySelected;

  const InventoryCategoriesDropdown({
    super.key,
    this.onCategorySelected,
    this.selectedCategory,
  });

  @override
  State<InventoryCategoriesDropdown> createState() =>
      _InventoryCategoriesDropdownState();
}

class _InventoryCategoriesDropdownState
    extends State<InventoryCategoriesDropdown> {
  dynamic selectedCategory;
  dynamic selectedSubCategory;

  List<InventoryCategoriesModel> subCategories = [];
  bool isSubLoading = false;

  Map<int, List<InventoryCategoriesModel>> subCategoryCache = {};

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.selectedCategory;

    context
        .read<InventoryCategoriesBloc>()
        .add(InventoryCategoriesFetchEvent());
  }

  Future<void> fetchSubCategories(int categoryId) async {
    try {
      //  cache check
      if (subCategoryCache[categoryId]?.isNotEmpty == true) {
        setState(() {
          subCategories = subCategoryCache[categoryId]!;
          isSubLoading = false;
        });
        return;
      }

      setState(() {
        isSubLoading = true;
      });

      final db = await DBHelper.instance.database;

      final result = await db.query(
        AppDBConst.userTable,
        where:
        '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );

      if (result.isEmpty) throw Exception("No token found");

      final token = result.first[AppDBConst.userToken] as String;

      final Uri url = Uri.parse(
        "${UrlHelper.baseUrl}pinaka-pos/v1/inventories/show-category-sublist",
      ).replace(queryParameters: {
        'category_id': categoryId.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        final List categoriesJson = decoded['categories'] ?? [];

        final list = categoriesJson
            .map((e) => InventoryCategoriesModel.fromJson(e))
            .toList();

        setState(() {
          subCategories = list;
          subCategoryCache[categoryId] = list;
        });
      }
    } catch (e) {
      debugPrint("SUBCATEGORY ERROR: $e");
    } finally {
      setState(() {
        isSubLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Row(
      children: [
        ///  CATEGORY DROPDOWN (ENTITY FIXED)
        Expanded(
          flex: 2,
          child: BlocBuilder<InventoryCategoriesBloc,
              InventoryCategoriesState>(
            builder: (context, state) {
              List categories = [];
              bool isLoading = false;

              if (state is InventoryCategoriesLoading) {
                isLoading = true;
              } else if (state is InventoryCategoriesLoaded) {
                categories = state.categories; //  ENTITY LIST
              } else if (state is InventoryCategoriesError) {
                return Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                );
              }

              return DropdownButtonFormField<dynamic>(
                isExpanded: true,
                value: selectedCategory,
                hint: Text(
                  isLoading ? "Loading..." : "Category",
                  style: TextStyle(color: textColor),
                ),

                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: Colors.grey, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),

                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      "${cat.name} (${cat.count})",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                  );
                }).toList(),

                onChanged: isLoading
                    ? null
                    : (value) {
                  setState(() {
                    selectedCategory = value;
                    selectedSubCategory = null;
                    subCategories = [];
                  });

                  if (value != null) {
                    fetchSubCategories(value.id);
                  }

                  widget.onCategorySelected?.call(value);
                },
              );
            },
          ),
        ),

        const SizedBox(width: 6),

        ///  SUBCATEGORY DROPDOWN
        Expanded(
          flex: 2,
          child: isSubLoading
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<dynamic>(
            isExpanded: true,
            value: selectedSubCategory,
            hint: const Text("Subcategory"),

            items: subCategories.map((sub) {
              return DropdownMenuItem(
                value: sub,
                child: Text(
                  sub.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),

            onChanged: (selectedCategory == null)
                ? null
                : (value) {
              setState(() {
                selectedSubCategory = value;
              });

              if (value != null && selectedCategory != null) {
                widget.onCategorySelected?.call({
                  "category_id": selectedCategory.id,   // ← this is an int
                  "sub_category_id": value.id,
                });
              }
            },

            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                const BorderSide(color: Colors.grey, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}