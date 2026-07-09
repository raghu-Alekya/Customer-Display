// lib/Widgets/pay_later_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PayLaterWidget extends StatefulWidget {
  final Function(Map<String, dynamic>?)? onUserSelected;

  const PayLaterWidget({super.key, this.onUserSelected});

  @override
  State<PayLaterWidget> createState() => _PayLaterWidgetState();
}

class _PayLaterWidgetState extends State<PayLaterWidget> {
  List<dynamic> users = [];
  dynamic selectedUser;
  bool isLoading = true;
  String? errorMessage;

  final String apiUrl =
      "https://merchantretail.alektasolutions.com/wp-json/pinaka-pos/v1/assets/pay-later-users";

  final String token =
      "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvbWVyY2hhbnRyZXRhaWwuYWxla3Rhc29sdXRpb25zLmNvbSIsImlhdCI6MTc4MTU4OTYyOCwibmJmIjoxNzgxNTg5NjI4LCJleHAiOjE3ODQxODE2MjgsImRhdGEiOnsidXNlciI6eyJpZCI6MTA4fX19.jFhzjPWutKVZwJcmDmyI8hkgIk0CWcOZb3cXaCn4VyE";

  @override
  void initState() {
    super.initState();
    fetchPayLaterUsers();
  }

  Future<void> fetchPayLaterUsers() async {
    try {
      print("========== PAY LATER API REQUEST ==========");
      print("API URL: $apiUrl");
      print("TOKEN: $token");

      var request = http.Request('GET', Uri.parse(apiUrl));

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      print("REQUEST HEADERS: ${request.headers}");

      http.StreamedResponse response = await request.send();

      print("========== API RESPONSE ==========");
      print("STATUS CODE: ${response.statusCode}");
      print("REASON: ${response.reasonPhrase}");

      final responseBody = await response.stream.bytesToString();

      print("RAW RESPONSE:");
      print(responseBody);

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        print("DECODED JSON RESPONSE:");
        print(data);

        setState(() {
          users = data["users"] ?? [];
          isLoading = false;
        });

        print("TOTAL USERS: ${users.length}");

        for (var user in users) {
          print("--------------------------------");
          print("User ID: ${user["user_id"]}");
          print("Name: ${user["name"]}");
          print("Email: ${user["email"]}");
          print("Store: ${user["pay_later_user_store_name"]}");
        }

      } else {
        setState(() {
          errorMessage = response.reasonPhrase ?? 'Failed to load users';
          isLoading = false;
        });

        print("API FAILED");
        print("ERROR RESPONSE: $responseBody");
      }

    } catch (e, stackTrace) {
      print("========== API EXCEPTION ==========");
      print("ERROR: $e");
      print("STACK TRACE: $stackTrace");

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

    // Notify parent widget if callback is provided
    if (widget.onUserSelected != null) {
      widget.onUserSelected!(user as Map<String, dynamic>?);
    }

    print("Selected User ID: ${user["user_id"]}");
    print("Selected User Name: ${user["name"]}");
    print("Selected User Email: ${user["email"]}");
    print("Store Name: ${user["pay_later_user_store_name"]}");
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        DropdownButtonFormField<dynamic>(
          value: selectedUser,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hintText: "Select User",
          ),
          items: users.map((user) {
            return DropdownMenuItem<dynamic>(
              value: user,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user["name"] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Text(
                  //   user["email"] ?? 'No email',
                  //   style: const TextStyle(
                  //     fontSize: 12,
                  //   ),
                  // ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onUserSelected(value);
            }
          },
        ),
        // const SizedBox(height: 20),

      ],
    );
  }
}