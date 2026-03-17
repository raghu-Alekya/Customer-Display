import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late MqttServerClient client;

  List items = [];
  double total = 0;
  double subtotal = 0;
  double tax = 0;
  int? orderId;
  // NEW: store info coming from POS
  // String storeName = "STORE";       // default
  // String? storeLogoUrl;            // null = use local asset
  String merchantName = "MERCHANT";  // default fallback
  String? merchantLogoUrl;

  // Right column promo images (URLs loaded from server)
  List<String> promoImageUrls = [];

  late final PageController _promoPageController;
  Timer? _promoTimer;

  final now = DateTime.now();
  late String formattedDate;
  late String formattedTime;

  // Payment states driven by MQTT payload (paymentStatus)
  bool isPaymentProcessing = false; // SHOW processing overlay on left
  bool isPaymentSuccess = false;    // SHOW thank-you screen

  Future<void> connect() async {
    client = MqttServerClient('172.17.7.80', 'customer_display');

    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;
    client.logging(on: true);

    client.onConnected = () => print('DISPLAY: onConnected callback');
    client.onDisconnected = () => print('DISPLAY: onDisconnected callback');
    client.onSubscribed = (topic) => print('DISPLAY: subscribed to $topic');
    client.onSubscribeFail =
        (topic) => print('DISPLAY: FAILED to subscribe $topic');

    try {
      print('DISPLAY: connecting...');
      final connMess = MqttConnectMessage()
          .withClientIdentifier('customer_display')
          .startClean();
      client.connectionMessage = connMess;

      final status = await client.connect();
      print('DISPLAY: connection status = ${status?.state}');

      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        print('DISPLAY: ERROR – not connected, status: ${client.connectionStatus}');
        return;
      }

      client.subscribe('store/1001/pos/1/order', MqttQos.atLeastOnce);

      client.updates!.listen((events) {
        final recMess = events[0].payload as MqttPublishMessage;
        final payload =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        print('DISPLAY RECEIVED RAW: $payload');

        try {
          final data = jsonDecode(payload);
          setState(() {
            final event = (data['event'] ?? '').toString();

            // 1) store info from POS (sent after login/validation)
            if (event == 'store_info') {
              merchantName = (data['storeName'] ?? merchantName).toString();
              final logo = data['logoUrl'] as String?;
              merchantLogoUrl = (logo == null || logo.trim().isEmpty) ? null : logo;
            }

            // 2) order + totals (for cart updates / payment status)
            items    = (data['items'] as List? ?? []);
            subtotal = (data['subtotal'] ?? 0).toDouble();
            tax      = (data['tax'] ?? 0).toDouble();
            total    = (data['total'] ?? 0).toDouble();
            orderId  = data['orderId'] as int?;

            final status = (data['paymentStatus'] ?? '').toString().toUpperCase();
            isPaymentProcessing = status == 'PROCESSING';
            isPaymentSuccess    = status == 'PAID';

            if (isPaymentSuccess) {
              Future.delayed(const Duration(seconds: 5), () {
                if (!mounted) return;
                setState(() {
                  isPaymentSuccess = false;
                  isPaymentProcessing = false;
                  items = [];
                  subtotal = 0;
                  tax = 0;
                  total = 0;
                  orderId = null;
                });
              });
            }
          });
        } catch (e) {
          print('DISPLAY: JSON decode error: $e');
        }
      });
    } catch (e) {
      print('DISPLAY: connection EXCEPTION: $e');
      client.disconnect();
    }
  }

  /// Fetch promo image URLs from your WordPress API
  /// and store them in [promoImageUrls].
  Future<void> fetchPromoImages() async {
    try {
      final uri = Uri.parse(
          'https://merchantretail.alektasolutions.com/wp-content/plugins/pinaka-pos-wp/promotion_images.php');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final urls = <String>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final sizes = item['sizes'] as Map<String, dynamic>?;
              final full = sizes?['full'] as String? ?? item['url'] as String?;
              if (full != null && full.isNotEmpty) {
                urls.add(full);
              }
            }
          }
          if (urls.isNotEmpty) {
            setState(() {
              promoImageUrls = urls;
            });
            print('PROMO IMAGES: loaded ${urls.length} images');
          }
        }
      } else {
        debugPrint(
            'PROMO IMAGES: HTTP ${response.statusCode} – ${response.body}');
      }
    } catch (e) {
      debugPrint('PROMO IMAGES: error fetching images: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _promoPageController = PageController();
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted ||
          !_promoPageController.hasClients ||
          promoImageUrls.length <= 1) return;

      final currentPage = _promoPageController.page?.round() ?? 0;
      final nextPage = (currentPage + 1) % promoImageUrls.length;

      _promoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    final now = DateTime.now();
    formattedDate = DateFormat('dd MMMM, yyyy').format(now);
    formattedTime = DateFormat('hh:mm a').format(now);

    connect();
    fetchPromoImages();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoPageController.dispose();
    try {
      client.disconnect();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      body: SafeArea(
        child: Container(
          width: size.width,
          height: size.height,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // HEADER
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF044A80),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // LEFT: logo
                    Container(
                      width: 120,
                      height: 40,
                      alignment: Alignment.centerLeft,
                        child: _merchantLogo(),
                    ),
                    const SizedBox(width: 16),

                    // CENTER: store name
                    Expanded(
                      child: Text(
                        merchantName,// TODO: bind your store name
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // RIGHT: date + time
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$formattedDate | $formattedTime",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // MAIN CARD
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  // Three states:
                  // 1) Thank-you (isPaymentSuccess)
                  // 2) Welcome (no items)
                  // 3) Order (items present)
                  child: isPaymentSuccess
                      ? _buildThankYouLayout()
                      : items.isEmpty
                      ? _buildWelcomeLayout()
                      : _buildOrderLayout(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // THANK-YOU SCREEN
  Widget _buildThankYouLayout() {
    return Row(
      children: [
        // LEFT: full blue with logo
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF044A80),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
              ),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 220,
              height: 220,
              // use dynamic logo helper here
              child: _merchantLogo(), // or Image.asset(...) if you prefer
            ),
          ),
        ),

        // RIGHT: big "THANK YOU / VISIT AGAIN" (can also show storeName)
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "THANK YOU",
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "VISIT AGAIN",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Color(0xFF044A80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // WELCOME SCREEN
  Widget _buildWelcomeLayout() {
    return Row(
      children: [
        // LEFT: full blue with logo
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF044A80),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
              ),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 220,
              height: 220,
              // if you added _storeLogo(), use that instead of Image.asset
              child: _merchantLogo(), // or Image.asset('assets/logo.png', fit: BoxFit.contain)
            ),
          ),
        ),

        // RIGHT: white with big "WELCOME TO <STORE>"
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "WELCOME",
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "TO",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        merchantName.toUpperCase(), // dynamic store name
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ORDER + PROMO + PROCESSING OVERLAY
  Widget _buildOrderLayout() {
    return Row(
      children: [
        // LEFT: order details + optional processing overlay
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Order info row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFFF5F7FA),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Order ID: ",
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFE20000),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              orderId?.toString() ?? "-",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: const [
                            Text(
                              "Redeem Points: ",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFE5990B),
                              ),
                            ),
                            Text(
                              "250 Pts",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF007BFF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Guest row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: const [
                        Text(
                          "Guest:",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0052A8),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "guest@example.com",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Column headers
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    color: const Color(0xFF0069D9),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 64,
                          child: Text("#",
                              style:
                              TextStyle(color: Colors.white, fontSize: 20)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            "Order item",
                            style:
                            TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            "Price * qty",
                            textAlign: TextAlign.center,
                            style:
                            TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Total",
                            textAlign: TextAlign.end,
                            style:
                            TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Items list
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final String name =
                        (item["name"] ?? "").toString();
                        final num qty = (item["qty"] ?? 0) as num;
                        final num price = (item["price"] ?? 0) as num;
                        final double lineTotal =
                        (price * qty).toDouble();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "\$${price.toStringAsFixed(2)} × $qty",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "\$${lineTotal.toStringAsFixed(2)}",
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryRow(
                          label: "Gross Total",
                          value: subtotal,
                          bold: true,
                        ),
                        const SizedBox(height: 4),
                        _summaryRow(
                          label: "Discount",
                          value: 0,
                          labelColor: Colors.green,
                          valueColor: Colors.green,
                        ),
                        _summaryRow(
                          label: "Merchant Discount",
                          value: 0,
                          labelColor: Colors.blue,
                          valueColor: Colors.blue,
                        ),
                        _summaryRow(
                          label: "Surcharges",
                          value: 0,
                        ),
                        const SizedBox(height: 4),
                        _summaryRow(
                          label: "Net Total",
                          value: total - tax,
                          bold: true,
                        ),
                        const SizedBox(height: 4),
                        _summaryRow(
                          label: "Tax",
                          value: tax,
                          small: true,
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0ECFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Items : ${items.length}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "Total : \$${total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // PAYMENT PROCESSING OVERLAY
              if (isPaymentProcessing)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  child: Center(
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Processing your payment",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Please wait while we complete your transaction",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // RIGHT: promo slider
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: PageView.builder(
                controller: _promoPageController,
                itemCount: promoImageUrls.length,
                itemBuilder: (context, index) {
                  final url = promoImageUrls[index];
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required String label,
    required double value,
    Color? labelColor,
    Color? valueColor,
    bool bold = false,
    bool small = false,
  }) {
    final fontSize = small ? 12.0 : 14.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: labelColor ?? Colors.black87,
          ),
        ),
        Text(
          "\$${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
  Widget _merchantLogo() {
    if (merchantLogoUrl == null || merchantLogoUrl!.isEmpty) {
      return Image.asset('assets/logo.png', fit: BoxFit.contain);
    }
    return Image.network(
      merchantLogoUrl!,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }
}