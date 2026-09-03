
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ============================================================================
// CONNECTION PAYLOAD
// ============================================================================

/// Data encoded inside the QR code shown on the POS (Settings screen) and
/// read by the Customer Display when it scans that QR code.
class CfdConnectionPayload {
  final String brokerIp;
  final int brokerPort;
  final String merchantId;
  final String storeId;
  final String terminalId;
  final String brokerUsername;
  final String brokerToken;

  const CfdConnectionPayload({
    required this.brokerIp,
    required this.brokerPort,
    required this.merchantId,
    required this.storeId,
    required this.terminalId,
    required this.brokerUsername,
    required this.brokerToken,
  });

  Map<String, dynamic> toJson() => {
    'type': 'pinaka_cfd_connect',
    'brokerIp': brokerIp,
    'brokerPort': brokerPort,
    'merchantId': merchantId,
    'storeId': storeId,
    'terminalId': terminalId,
    'brokerUsername': brokerUsername,
    'brokerToken': brokerToken,
  };

  String toQrData() => jsonEncode(toJson());

  /// Returns null (instead of throwing) if the scanned QR isn't a valid
  /// pinaka_cfd_connect payload — so scanning a random/unrelated QR code
  /// is silently ignored rather than crashing the CFD screen.
  static CfdConnectionPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['type'] != 'pinaka_cfd_connect') return null;

      return CfdConnectionPayload(
        brokerIp: (decoded['brokerIp'] ?? '').toString(),
        brokerPort: int.tryParse('${decoded['brokerPort'] ?? 1883}') ?? 1883,
        merchantId: (decoded['merchantId'] ?? '').toString(),
        storeId: (decoded['storeId'] ?? '').toString(),
        terminalId: (decoded['terminalId'] ?? '').toString(),
        brokerUsername: (decoded['brokerUsername'] ?? '').toString(),
        brokerToken: (decoded['brokerToken'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// RECONNECT + SCAN-QR ICON ROW  (goes under the store name on Welcome screen)
// ============================================================================

class WelcomeConnectionIcons extends StatelessWidget {
  final VoidCallback onReconnect;
  final VoidCallback onScanQr;
  final bool isReconnecting;

  const WelcomeConnectionIcons({
    super.key,
    required this.onReconnect,
    required this.onScanQr,
    this.isReconnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconButton(
          tooltip: 'Reconnect',
          onTap: isReconnecting ? null : onReconnect,
          child: isReconnecting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          )
              : const Icon(Icons.sync_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        _iconButton(
          tooltip: 'Scan QR to connect',
          onTap: onScanQr,
          child: const Icon(Icons.qr_code_scanner_rounded,
              color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _iconButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FULL-SCREEN QR SCANNER PAGE
// ============================================================================

class QrConnectScannerPage extends StatefulWidget {
  const QrConnectScannerPage({super.key});

  @override
  State<QrConnectScannerPage> createState() => _QrConnectScannerPageState();
}

class _QrConnectScannerPageState extends State<QrConnectScannerPage> {
  bool _handled = false;
  String? _lastError;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final payload = CfdConnectionPayload.tryParse(raw);
      if (payload != null) {
        _handled = true;
        Navigator.of(context).pop(payload);
        return;
      } else {
        setState(() {
          _lastError = 'That QR code is not a valid POS pairing code';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan POS QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          // Simple scan-target frame overlay.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Point the camera at the QR code shown on the '
                        'POS Settings screen',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}