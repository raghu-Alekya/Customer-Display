// lib/Widgets/pay_later_widget.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';

class PayLaterWidget extends StatefulWidget {
  final Function(Map<String, dynamic>?)? onUserSelected;

  const PayLaterWidget({
    super.key,
    this.onUserSelected,
  });

  @override
  State<PayLaterWidget> createState() => _PayLaterWidgetState();
}

class _PayLaterWidgetState extends State<PayLaterWidget> {
  List<dynamic> users = [];
  dynamic selectedUser;
  bool isLoading = true;
  String? errorMessage;

  // ── THEME CONSTANTS (matched to reference design) ──────────────────────
  static const Color _titleColor = Color(0xFF1E1E1E);
  static const Color _subtitleColor = Color(0xFF9B9B9B);
  static const Color _labelColor = Color(0xFF1E1E1E);
  static const Color _borderColor = Color(0xFFE2E4E9);
  static const Color _hintColor = Color(0xFF9B9B9B);
  static const Color _dropdownIconColor = Color(0xFF11183D);
  static const Color _cancelBg = Color(0xFFF1F2F4);
  static const Color _cancelText = Color(0xFF44464B);
  static const Color _confirmBg = Color(0xFFFE5722);

  @override
  void initState() {
    super.initState();
    fetchPayLaterUsers();
  }

  /// Get token from SQLite DB
  Future<String> _getTokenFromDb() async {
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

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      print("Token From DB: $token");
    }

    return token;
  }

  /// Fetch Pay Later Users
  Future<void> fetchPayLaterUsers() async {
    try {
      final token = await _getTokenFromDb();

      final String apiUrl =
          '${UrlHelper.baseUrl}pinaka-pos/v1/assets/pay-later-users';

      if (kDebugMode) {
        print("========== PAY LATER API ==========");
        print("URL: $apiUrl");
        print("TOKEN: $token");
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("STATUS CODE: ${response.statusCode}");
        print("RAW RESPONSE:");
        print(response.body);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (kDebugMode) {
          print("Decoded Response:");
          print(data);
        }

        setState(() {
          users = data["users"] ?? [];
          isLoading = false;
        });

        if (kDebugMode) {
          print("Total Users: ${users.length}");

          for (var user in users) {
            print("---------------------------");
            print("User ID : ${user["user_id"]}");
            print("Name : ${user["name"]}");
            print("Email : ${user["email"]}");
            print("Store : ${user["pay_later_user_store_name"]}");
          }
        }
      } else {
        setState(() {
          errorMessage =
          "Failed (${response.statusCode}) ${response.reasonPhrase}";
          isLoading = false;
        });

        if (kDebugMode) {
          print("API Error:");
          print(response.body);
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("========== EXCEPTION ==========");
        print(e);
        print(stackTrace);
      }

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void onUserSelected(dynamic user) {
    setState(() {
      selectedUser = user;
    });

    if (widget.onUserSelected != null) {
      widget.onUserSelected!(user as Map<String, dynamic>?);
    }

    if (kDebugMode) {
      print("Selected User:");
      print("ID : ${user["user_id"]}");
      print("Name : ${user["name"]}");
      print("Email : ${user["email"]}");
      print("Store : ${user["pay_later_user_store_name"]}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      )
          : errorMessage != null
          ? SizedBox(
        height: 220,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── TITLE (centered) ─────────────────────────────
          const Text(
            "Assign Customer for Pay Later",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: _titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // ── SUBTITLE (centered) ──────────────────────────
          const Text(
            "Select a customer to save this bill as Pay Later. The "
                "payment can be collected later.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: _subtitleColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // ── CUSTOMER LABEL (left aligned) ────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Customer:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _labelColor,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── DROPDOWN ──────────────────────────────────────
          Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<dynamic>(
                value: selectedUser,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _dropdownIconColor,
                  size: 26,
                ),
                // ⭐ FIX: isCollapsed removes the InputDecorator's implicit
                // vertical padding so the hint/value text and the dropdown
                // icon both sit on the exact same center line as the box.
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: "Select User",
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: _hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _titleColor,
                ),
                alignment: AlignmentDirectional.centerStart,
                items: users.map((user) {
                  return DropdownMenuItem<dynamic>(
                    value: user,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      user["name"] ?? "Unknown",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onUserSelected(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── BUTTONS ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: _cancelBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: _cancelText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: selectedUser != null
                        ? () => Navigator.of(context).pop(selectedUser)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _confirmBg,
                      disabledBackgroundColor:
                      _confirmBg.withOpacity(0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Confirm",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}