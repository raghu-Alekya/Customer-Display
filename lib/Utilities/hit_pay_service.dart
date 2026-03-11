import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class HitPayService { // Demo Code for implementation
  final String apiKey;
  final String redirectUrl;

  HitPayService({required this.apiKey, required this.redirectUrl});

  /// Create a Payment Request
  Future<String?> createPayment(double amount, String currency) async {
    final url = Uri.parse("https://api.hit-pay.com/v1/payment-requests");
    final headers = {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
    };
    final body = jsonEncode({
      "amount": amount.toStringAsFixed(2),
      "currency": currency,
      "redirect_url": redirectUrl,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url']; // Payment URL
      } else {
        print("Error creating payment: ${response.body}");
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception: $e");
      }
      return null;
    }
  }

  /// Redirect User to Payment Page
  Future<void> redirectToPayment(String url) async {
    if (await canLaunchUrl(url as Uri)) {
      await launchUrl(url as Uri);
    } else {
      throw "Could not launch $url";
    }
  }
}

/// TEST CLASS
class HitPay extends StatefulWidget {
  const HitPay ({super.key});

  @override
  State<HitPay> createState() => _HitPayState();
}

class _HitPayState extends State<HitPay> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

  final hitPay = HitPayService(
    apiKey: 'YOUR_HITPAY_API_KEY',
    redirectUrl: 'https://your-redirect-url.com',
  );

  Future<void> handleHitPayPayment() async {
    final paymentUrl = await hitPay.createPayment(10.0, "USD");

    if (paymentUrl != null) {
      await hitPay.redirectToPayment(paymentUrl);
    } else {
      if (kDebugMode) {
        print("Payment creation failed.");
      }
    }
  }
}
