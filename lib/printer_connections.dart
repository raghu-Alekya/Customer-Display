// import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
//
// Future<void> printToBluetooth(List<int> bytes) async {
//   final manager = PrinterManager.instance;
//
//   // 1) scan / list devices and let the user pick (or store a saved one)
//   final devices = await manager.discover(type: PrinterType.bluetooth);
//   // pick one device from list (saved MAC or first matching name)
//   final device = devices.first; // replace with your selection logic
//
//   await manager.connect(
//     type: PrinterType.bluetooth,
//     model: BluetoothPrinterInput(name: device.name, address: device.address),
//   );
//
//   await manager.send(type: PrinterType.bluetooth, bytes: bytes);
//   await manager.disconnect(type: PrinterType.bluetooth);
// }
//
// Future<void> printToUsb(List<int> bytes) async {
//   final manager = PrinterManager.instance;
//
//   final devices = await manager.discover(type: PrinterType.usb);
//   final device = devices.first; // choose by vendorId/productId, etc.
//
//   await manager.connect(
//     type: PrinterType.usb,
//     model: UsbPrinterInput(
//       vendorId: device.vendorId,
//       productId: device.productId,
//     ),
//   );
//
//   await manager.send(type: PrinterType.usb, bytes: bytes);
//   await manager.disconnect(type: PrinterType.usb);
// }