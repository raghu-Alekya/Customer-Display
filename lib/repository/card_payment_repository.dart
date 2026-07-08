import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CardPaymentRepository {
  Future<Map<String, dynamic>> createCardPayment({
    required int orderId,
    required double amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    /// Get token from SharedPreferences
    final token = prefs.getString("token");

    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final url = Uri.parse(
      "https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/payments/create-payment",
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "order_id": orderId,
        "amount": amount,
        "payment_method": "card",
      }),
    );

    print("Payment Status => ${response.statusCode}");
    print("Payment Response => ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return decoded;
    }

    throw Exception(
      decoded["message"] ?? "Payment failed",
    );
  }
}