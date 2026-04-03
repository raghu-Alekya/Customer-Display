import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:keyos_app/cart_manger.dart';

Future<List<int>> buildReceiptBytes({
  required String orderType,
  required double subtotal,
  required double tax,
  required double total,
  required int? orderId,
}) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);

  final List<int> bytes = [];

  bytes.addAll(generator.text('My Store'));
  bytes.addAll(generator.text('Line 1'));
  bytes.addAll(generator.hr());

  for (final item in CartManager.cartItems) {
    final product = item['product'];
    final qty = (item['qty'] as num).toInt();
    final addons = (item['addons'] as List);

    final price = double.tryParse(product.price.replaceAll('₹', '')) ?? 0;
    final addonTotal =
    addons.fold<double>(0, (sum, a) => sum + (a.price as double));
    final lineTotal = (price + addonTotal) * qty;

    bytes.addAll(generator.row([
      PosColumn(text: '${product.name} x$qty', width: 8),
      PosColumn(
        text: lineTotal.toStringAsFixed(2),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    for (final a in addons) {
      bytes.addAll(
        generator.text(
          '  + ${a.name}',
          styles: const PosStyles(
            align: PosAlign.left,
            width: PosTextSize.size1,
          ),
        ),
      );
    }
  }

  bytes.addAll(generator.hr());
  bytes.addAll(generator.row([
    PosColumn(text: 'Sub Total', width: 8),
    PosColumn(
      text: subtotal.toStringAsFixed(2),
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]));
  bytes.addAll(generator.row([
    PosColumn(text: 'Tax', width: 8),
    PosColumn(
      text: tax.toStringAsFixed(2),
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]));
  bytes.addAll(generator.row([
    PosColumn(text: 'Net Payable', width: 8),
    PosColumn(
      text: total.toStringAsFixed(2),
      width: 4,
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
      ),
    ),
  ]));

  bytes.addAll(generator.hr(ch: '=', linesAfter: 1));
  bytes.addAll(
    generator.text(
      'Thank you!',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    ),
  );
  bytes.addAll(generator.feed(3));
  bytes.addAll(generator.cut());

  return bytes;
}