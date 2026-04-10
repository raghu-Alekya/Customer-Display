import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';
import 'package:usb_serial/usb_serial.dart';

import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/isar_cache_entry.dart';
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_search_model.dart';
import '../Models/Search/product_variation_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Category/category_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/responsive_layout.dart';
import '../Utilities/svg_images_utility.dart';
import 'ManualPriceDialog.dart';
import 'OrderPopupHelper.dart';

import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;

// ══════════════════════════════════════════════════════════════════════════════
// SCALE DEVICE TABLE — Datalogic / Magellan + common serial chips
// ══════════════════════════════════════════════════════════════════════════════

/// All known VID/PID combos for scales and USB-Serial adapters used with
/// Datalogic Magellan scanner/scales (and other retail scale brands).
const _knownScaleVidPids = [
  // ── Datalogic / Magellan native ─────────────────────────────────────
  {'vid': 0x05F9, 'pid': 0x1100},
  {'vid': 0x05F9, 'pid': 0x1101},
  {'vid': 0x05F9, 'pid': 0x1102},
  {'vid': 0x05F9, 'pid': 0x1103},
  {'vid': 0x05F9, 'pid': 0x1104}, // Magellan 800i / 1100i / 9800i
  {'vid': 0x05F9, 'pid': 0x2202}, // Magellan 9800i / Digimarc
  {'vid': 0x05F9, 'pid': 0x4204},
  // ── FTDI FT232R / FT231X (most common Magellan USB-Serial cable) ─────
  {'vid': 0x0403, 'pid': 0x6001}, // FT232R        (dec: vid=1027, pid=24577)
  {'vid': 0x0403, 'pid': 0x6010},
  {'vid': 0x0403, 'pid': 0x6011},
  {'vid': 0x0403, 'pid': 0xB0C4}, // your detected (dec: vid=1027, pid=45249)
  // ── Prolific PL2303 ──────────────────────────────────────────────────
  {'vid': 0x067B, 'pid': 0x2303},
  {'vid': 0x067B, 'pid': 0x2304},
  // ── Silicon Labs CP210x ──────────────────────────────────────────────
  {'vid': 0x10C4, 'pid': 0xEA60},
  {'vid': 0x10C4, 'pid': 0xEA70},
  // ── WinChipHead CH340 / CH341 ────────────────────────────────────────
  {'vid': 0x1A86, 'pid': 0x7523},
  {'vid': 0x1A86, 'pid': 0x5523},
];

/// Name keywords that suggest a device is a scale or serial adapter.
const _scaleKeywords = [
  'magellan', 'datalogic', 'digimarc', 'scale', 'scanner',
  'serial', 'converter', 'uart', 'ftdi', 'prolific', 'silabs', 'ch340',
];

/// Baud rates to try — 9600 is the Magellan/retail standard.
const _scaleBaudRates = [9600, 4800, 19200, 38400];

/// Hard timeout per open() / create() call so we never hang on a bad port.
const _connectTimeout = Duration(seconds: 5);

/// How long to wait for the first byte to confirm the correct baud rate.
/// Prevents locking onto the wrong port in a USB hub with many devices.
const _dataWaitTimeout = Duration(seconds: 3);

// ══════════════════════════════════════════════════════════════════════════════
// 7-SEGMENT LCD DISPLAY  — no font file needed, pure CustomPainter
// ══════════════════════════════════════════════════════════════════════════════

class _SegmentPainter extends CustomPainter {
  final String char;
  final Color onColor;
  final Color offColor;
  final double strokeW;

  _SegmentPainter({
    required this.char,
    required this.onColor,
    required this.offColor,
    this.strokeW = 3.0,
  });

  static const Map<String, List<bool>> _segments = {
    '0': [true,  true,  true,  true,  true,  true,  false],
    '1': [false, true,  true,  false, false, false, false],
    '2': [true,  true,  false, true,  true,  false, true ],
    '3': [true,  true,  true,  true,  false, false, true ],
    '4': [false, true,  true,  false, false, true,  true ],
    '5': [true,  false, true,  true,  false, true,  true ],
    '6': [true,  false, true,  true,  true,  true,  true ],
    '7': [true,  true,  true,  false, false, false, false],
    '8': [true,  true,  true,  true,  true,  true,  true ],
    '9': [true,  true,  true,  true,  false, true,  true ],
    '.': [false, false, false, false, false, false, false],
    '-': [false, false, false, false, false, false, true ],
    ' ': [false, false, false, false, false, false, false],
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (char == '.') {
      final dotR = strokeW * 1.1;
      canvas.drawCircle(
        Offset(size.width / 2, size.height - dotR),
        dotR,
        Paint()..color = onColor,
      );
      return;
    }

    final segs = _segments[char] ?? _segments[' ']!;
    final w = size.width;
    final h = size.height;
    final s = strokeW;
    final gap = s * 0.55;

    void seg(bool on, Offset p1, Offset p2) {
      canvas.drawLine(
        p1, p2,
        Paint()
          ..color       = on ? onColor : offColor
          ..strokeWidth = s
          ..strokeCap   = StrokeCap.round
          ..style       = PaintingStyle.stroke,
      );
    }

    final mid = h / 2;
    seg(segs[0], Offset(gap + s * 0.5, s * 0.5),         Offset(w - gap - s * 0.5, s * 0.5));
    seg(segs[1], Offset(w - s * 0.5, gap + s * 0.5),     Offset(w - s * 0.5, mid - gap));
    seg(segs[2], Offset(w - s * 0.5, mid + gap),          Offset(w - s * 0.5, h - gap - s * 0.5));
    seg(segs[3], Offset(gap + s * 0.5, h - s * 0.5),      Offset(w - gap - s * 0.5, h - s * 0.5));
    seg(segs[4], Offset(s * 0.5, mid + gap),               Offset(s * 0.5, h - gap - s * 0.5));
    seg(segs[5], Offset(s * 0.5, gap + s * 0.5),          Offset(s * 0.5, mid - gap));
    seg(segs[6], Offset(gap + s * 0.5, mid),               Offset(w - gap - s * 0.5, mid));
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.char != char || old.onColor != onColor;
}

class SevenSegmentDisplay extends StatelessWidget {
  final String text;
  final double digitHeight;
  final Color  onColor;
  final Color  offColor;
  final double spacing;

  const SevenSegmentDisplay({
    super.key,
    required this.text,
    this.digitHeight = 34,
    this.onColor     = const Color(0xFF1A1A1A),
    this.offColor    = const Color(0xFFD8D8D8),
    this.spacing     = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: text.split('').map((ch) {
        final isDot = ch == '.';
        final w     = isDot ? digitHeight * 0.22 : digitHeight * 0.60;
        return Padding(
          padding: EdgeInsets.only(right: isDot ? 1 : spacing),
          child: SizedBox(
            width:  w,
            height: digitHeight,
            child: CustomPaint(
              painter: _SegmentPainter(
                char:     ch,
                onColor:  onColor,
                offColor: offColor,
                strokeW:  digitHeight * 0.088,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

enum Screen { FASTKEY, CATEGORY, ADD, ORDERS, APPS, SHIFT, SAFE, EDIT }

class _PinBoxField extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;

  const _PinBoxField({required this.controller, required this.hasError});

  @override
  State<_PinBoxField> createState() => _PinBoxFieldState();
}

class _PinBoxFieldState extends State<_PinBoxField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: widget.controller,
        maxLength: 6,
        autofocus: true,
        keyboardType: TextInputType.text,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          letterSpacing: 14,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: isDark ? const Color(0xFF40424F) : const Color(0xFFF2F4F8),
          suffixIcon: IconButton(
            splashRadius: 13,
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: widget.hasError ? Colors.red : Colors.transparent,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: widget.hasError ? Colors.red : Colors.redAccent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatefulWidget {
  final Function() onModeChanged;
  final Function(ProductResponse)? onProductSelected;
  final Screen screen;

  const TopBar({
    required this.screen,
    required this.onModeChanged,
    this.onProductSelected,
    super.key,
  });

  static void clearUserCache() {
    _TopBarState.clearUserDataCache();
  }

  /// Backward-compatible helper used by order summary merge flow.
  /// Returns a de-duplicated list of cached products from Isar + Hive fallback.
  static Future<List<Map<String, dynamic>>> mergedCachedProductsForSearch() async {
    final uniqueById = <int, Map<String, dynamic>>{};
    final uniqueBySku = <String, Map<String, dynamic>>{};
    final ordered = <Map<String, dynamic>>[];

    void upsert(dynamic raw) {
      if (raw is! Map) return;
      final product = Map<String, dynamic>.from(raw);
      final idRaw = product['fast_key_product_id'] ?? product['product_id'] ?? product['id'];
      final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
      final sku = (product['sku'] ?? '').toString().trim().toLowerCase();

      Map<String, dynamic>? existing;
      if (id != null && id > 0) {
        existing = uniqueById[id];
      } else if (sku.isNotEmpty) {
        existing = uniqueBySku[sku];
      }

      if (existing != null) {
        existing.addAll(product);
        return;
      }

      ordered.add(product);
      if (id != null && id > 0) uniqueById[id] = product;
      if (sku.isNotEmpty) uniqueBySku[sku] = product;
    }

    try {
      final fromIsar = await CategoryRepository().getAllCachedProducts();
      for (final p in fromIsar) {
        upsert(p);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("TopBar merged cache (Isar) failed: $e");
    }

    try {
      final allProducts = await StorageProvider.productCache.get("all_products_list");
      if (allProducts is List) {
        for (final p in allProducts) {
          if (p is Map && p['products'] is List) {
            final nested = p['products'] as List;
            for (final n in nested) {
              upsert(n);
            }
          } else {
            upsert(p);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("TopBar merged cache (Hive) failed: $e");
    }

    return ordered;
  }

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late BuildContext _context;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  final _searchFieldKey = GlobalKey();

  final orderHelper = OrderHelper();
  late OrderBloc _orderBloc;

  bool isAddingItemLoading = false;
  int? userId;
  String? userRole;
  String? userDisplayName;
  bool isLoading = false;

  bool _isSearchEnabled = true;
  var _printerSettings = PrinterSettings();

  List<dynamic> _cachedProducts = [];
  bool _cacheLoaded = false;
  final ProductBloc productBloc = ProductBloc(ProductRepository());

  bool _dialogOpen = false;

  // ── SCALE CONNECTION ────────────────────────────────────────────────────────
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _scaleBuffer = <int>[];

  bool _isConnecting = false;
  String _scaleStatus = 'Disconnected';   // for internal logging / debug
  String _connectedDeviceName = '';

  /// Cached WeightProvider — safe to use from dispose() and async gaps
  /// (never call Provider.of after an await gap).
  WeightProvider? _weightProvider;

  // ── CACHED USER DATA ────────────────────────────────────────────────────────
  static Map<String, dynamic>? _cachedUserData;
  static bool _isUserDataLoaded = false;
  static Future<Map<String, dynamic>?>? _initialUserFuture;

  static void clearUserDataCache() {
    _cachedUserData = null;
    _isUserDataLoaded = false;
    _initialUserFuture = null;
    if (kDebugMode) print("🧹 TopBar user data cache cleared");
  }

  // ── LIFECYCLE ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _orderBloc = OrderBloc(OrderRepository());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _isSearchEnabled =
        widget.screen != Screen.ORDERS && widget.screen != Screen.APPS;

    _loadCachedProducts();

    // Defer Provider access until after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _weightProvider = Provider.of<WeightProvider>(context, listen: false);
      _connectToScale();
    });

    if (!_isUserDataLoaded) {
      _initialUserFuture = UserDbHelper().getUserData();
      _initialUserFuture!.then((userData) {
        _cachedUserData    = userData;
        _isUserDataLoaded  = true;
        if (userData != null) {
          userId          = userData[AppDBConst.userId] as int?;
          userDisplayName = userData[AppDBConst.userDisplayName] as String?;
          userRole        = userData[AppDBConst.userRole] as String?;
        }
        if (mounted) setState(() {});
      });
    } else {
      if (_cachedUserData != null) {
        userId          = _cachedUserData![AppDBConst.userId] as int?;
        userDisplayName = _cachedUserData![AppDBConst.userDisplayName] as String?;
        userRole        = _cachedUserData![AppDBConst.userRole] as String?;
      }
    }
  }
  static void clearUserCache() {
    _cachedUserData = null;
    _isUserDataLoaded = false;
    _initialUserFuture = null;
    if (kDebugMode) print("🧹 TopBar user data cache cleared");
  }

  // @override
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _orderBloc.dispose();
    _removeOverlay();
    _disconnectScaleSafe(); // safe: uses cached _weightProvider, not context
    super.dispose();
    TopBar.clearUserCache();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SCALE — CONNECTION
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _connectToScale() async {
    if (_isConnecting || _port != null) return;
    if (mounted) setState(() {
      _isConnecting = true;
      _scaleStatus  = 'Scanning devices...';
    });

    try {
      final devices = await UsbSerial.listDevices();
      _scaleLog('🔍 Found ${devices.length} USB device(s)');
      for (final d in devices) {
        _scaleLog('  • ${d.productName ?? "unknown"}'
            '  VID:0x${d.vid?.toRadixString(16).toUpperCase().padLeft(4, "0")}'
            '  PID:0x${d.pid?.toRadixString(16).toUpperCase().padLeft(4, "0")}');
      }

      if (devices.isEmpty) {
        _scaleLog('❌ No USB devices found.');
        if (mounted) setState(() {
          _scaleStatus  = 'No USB devices';
          _isConnecting = false;
        });
        return;
      }

      // ── Rank devices into 3 priority buckets ─────────────────────────────
      // P1 = exact VID/PID match  (most reliable)
      // P2 = product-name keyword match
      // P3 = everything else on the hub (last-resort brute-force)

      final p1 = <UsbDevice>[];
      final p2 = <UsbDevice>[];
      final p3 = <UsbDevice>[];

      for (final d in devices) {
        final isKnown = _knownScaleVidPids
            .any((e) => e['vid'] == d.vid && e['pid'] == d.pid);
        final name      = (d.productName ?? '').toLowerCase();
        final nameMatch = _scaleKeywords.any(name.contains);

        if (isKnown)       p1.add(d);
        else if (nameMatch) p2.add(d);
        else                p3.add(d);
      }

      _scaleLog('📋 Priority — P1:${p1.length} P2:${p2.length} P3(fallback):${p3.length}');

      // ── Try in priority order; stop at first success ──────────────────────
      for (final d in [...p1, ...p2, ...p3]) {
        // Unknown devices (P3) only try 9600 to keep scan fast on hubs
        final bauds = p3.contains(d) ? [9600] : _scaleBaudRates;
        for (final baud in bauds) {
          final ok = await _tryConnectDevice(d, baud);
          if (ok) return; // ✅ connected
        }
      }

      _scaleLog('❌ Could not connect to any device.');
      if (mounted) setState(() => _scaleStatus = 'Not connected');

    } catch (e, st) {
      _scaleLog('❌ Scan error: $e');
      debugPrint('$st');
      if (mounted) setState(() => _scaleStatus = 'Scan error: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }
  // bool isLoading = false; // 👈 Make sure this exists

  Future<void> refreshProducts() async {
    try {
      setState(() => isLoading = true);

      final isar = await IsarService.instance;

      await isar.writeTxn(() async {
        await isar.isarCacheEntrys
            .filter()
            .keyStartsWith("sku_")   // ✅ ONLY SKU CACHE
            .deleteAll();
      });

      print("🗑 Only SKU cache cleared (sku_*)");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SKU products refreshed successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print("❌ SKU Refresh error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  /// Try opening [device] at [baud].
  /// Waits up to [_dataWaitTimeout] for actual bytes before committing.
  /// Returns true only when data starts flowing (confirms correct device/baud).
  Future<bool> _tryConnectDevice(UsbDevice device, int baud) async {
    final label = '${device.productName ?? "device"} @ $baud';
    _scaleLog('🔌 Trying $label...');

    UsbPort? port;
    try {
      // ── Create port ──────────────────────────────────────────────────────
      port = await device.create().timeout(
        _connectTimeout,
        onTimeout: () { _scaleLog('  ⏱ Timeout creating port'); return null; },
      );
      if (port == null) { _scaleLog('  ❌ create() returned null'); return false; }

      // ── Open port ────────────────────────────────────────────────────────
      final opened = await port.open().timeout(
        _connectTimeout,
        onTimeout: () { _scaleLog('  ⏱ Timeout opening port'); return false; },
      );
      if (!opened) {
        _scaleLog('  ❌ open() returned false');
        await _safeClosePort(port);
        return false;
      }

      // ── Configure serial params ──────────────────────────────────────────
      await port.setPortParameters(
        baud,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      ).timeout(_connectTimeout);

      // DTR + RTS required by many Magellan models to start sending weight data
      await port.setDTR(true);
      await port.setRTS(true);

      _scaleBuffer.clear();

      // ── Wait for first byte — confirms correct device + baud ─────────────
      // This is the key fix for USB hubs: we don't commit until data flows.
      final dataCompleter = Completer<bool>();
      final probeSub = port.inputStream?.listen((data) {
        if (!dataCompleter.isCompleted && data.isNotEmpty) {
          dataCompleter.complete(true);
        }
      });

      final gotData = await dataCompleter.future
          .timeout(_dataWaitTimeout, onTimeout: () => false);

      await probeSub?.cancel();

      if (!gotData) {
        _scaleLog('  ⚠️ No data at $baud baud — skipping.');
        await _safeClosePort(port);
        return false;
      }

      // ── Confirmed — set up real subscription ─────────────────────────────
      await _subscription?.cancel();
      _scaleBuffer.clear();

      _subscription = port.inputStream?.listen(
        _onScaleData,
        onError: (e) {
          _scaleLog('❌ Stream error: $e');
          _weightProvider?.setConnected(false);
          if (mounted) setState(() => _scaleStatus = 'Stream error');
        },
        onDone: () {
          _scaleLog('⚠️ Stream closed.');
          _weightProvider?.setConnected(false);
          if (mounted) setState(() => _scaleStatus = 'Disconnected');
        },
        cancelOnError: false,
      );

      _port                = port;
      _connectedDeviceName = device.productName ?? 'Scale';
      _weightProvider?.setConnected(true);

      if (mounted) setState(() => _scaleStatus = 'Connected: $_connectedDeviceName');
      _scaleLog('✅ Connected: $label');
      return true;

    } on TimeoutException {
      _scaleLog('  ⏱ Connection timed out: $label');
      await _safeClosePort(port);
      if (_port == port) _port = null;
      return false;
    } catch (e) {
      _scaleLog('  ❌ Exception: $e');
      await _safeClosePort(port);
      if (_port == port) _port = null;
      return false;
    }
  }

  Future<void> _safeClosePort(UsbPort? port) async {
    try { await port?.close(); } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SCALE — DATA PARSING
  // ══════════════════════════════════════════════════════════════════════════════

  void _onScaleData(Uint8List data) {
    _scaleBuffer.addAll(data);

    // ── Newline-terminated frames (standard RS-232 scale protocol) ───────────
    while (true) {
      final idx = _scaleBuffer.indexOf(0x0A); // LF
      if (idx == -1) break;
      final frame = _scaleBuffer.sublist(0, idx + 1);
      _scaleBuffer.removeRange(0, idx + 1);
      final line = String.fromCharCodes(frame).trim();
      if (line.isNotEmpty) {
        _scaleLog('📦 $line');
        _parseAndUpdateWeight(line);
      }
    }

    // ── Fixed-width frames without LF (some Magellan firmware versions) ──────
    if (_scaleBuffer.length > 64) {
      final line = String.fromCharCodes(_scaleBuffer).trim();
      _scaleBuffer.clear();
      if (line.isNotEmpty) {
        _scaleLog('📦 (raw) $line');
        _parseAndUpdateWeight(line);
      }
    }
  }

  void _parseAndUpdateWeight(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'\s+'), ' ');

    // ── "1.234 kg" / "2.50 lb" / "12.0 oz" ──────────────────────────────────
    final unitMatch = RegExp(
      r'([+-]?\d*\.?\d+)\s*(kg|g|lb|oz)',
      caseSensitive: false,
    ).firstMatch(clean);

    if (unitMatch != null) {
      final value = double.tryParse(unitMatch.group(1) ?? '');
      final unit  = unitMatch.group(2)?.toLowerCase() ?? 'kg';
      if (value != null) {
        final kg          = _convertToKg(value, unit);
        final lb          = kg * 2.20462;
        final displayText = '${lb.toStringAsFixed(3)} lb';
        _scaleLog('✅ $value $unit → $kg kg → $displayText');
        _weightProvider?.updateWeight(kg, displayText: displayText);
        return;
      }
    }

    // ── Bare number (Magellan SASI/OSD): "  2.500" — assume kg ──────────────
    final numMatch = RegExp(r'([+-]?\d*\.?\d+)').firstMatch(clean);
    if (numMatch != null) {
      final value = double.tryParse(numMatch.group(1) ?? '');
      if (value != null && value >= 0) {
        final lb          = value * 2.20462;
        final displayText = '${lb.toStringAsFixed(3)} lb';
        _scaleLog('⚠️ No unit — assuming kg: $value → $displayText');
        _weightProvider?.updateWeight(value, displayText: displayText);
        return;
      }
    }

    _scaleLog('❌ Cannot parse: "$clean"');
  }

  double _convertToKg(double value, String unit) {
    switch (unit) {
      case 'g':  return value / 1000;
      case 'lb': return value * 0.453592;
      case 'oz': return value * 0.0283495;
      case 'kg':
      default:   return value;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SCALE — CONNECT / DISCONNECT HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  void _scaleLog(String msg) {
    if (kDebugMode) print(msg);
  }

  /// Fully safe disconnect — uses cached [_weightProvider], never touches context.
  /// Call from dispose() or after async gaps.
  Future<void> _disconnectScaleSafe() async {
    await _subscription?.cancel();
    _subscription = null;
    await _safeClosePort(_port);
    _port = null;
    _weightProvider?.setConnected(false);
    _weightProvider?.updateWeight(0.0);
  }

  /// Full disconnect + state update. Use for reconnect flows.
  Future<void> _disconnectScale() async {
    await _disconnectScaleSafe();
    _connectedDeviceName = '';
    if (mounted) setState(() => _scaleStatus = 'Disconnected');
  }

  Future<void> _reconnectScale() async {
    await _disconnectScale();
    await _connectToScale();
  }



  Future<void> _loadCachedProducts() async {
    try {
      final repo     = CategoryRepository();
      final products = await repo.getAllCachedProducts();
      setState(() {
        _cachedProducts = products;
        _cacheLoaded    = true;
      });
    } catch (e) {
      debugPrint("Failed to load cached products: $e");
    }
  }

  String _getProductImage(dynamic product) {
    try {
      if (product.images != null && product.images!.isNotEmpty) {
        final img = product.images!.first;
        if (img is String && img.isNotEmpty) return img;
        if (img is Map && img["src"] != null) return img["src"].toString();
      }
    } catch (_) {}
    return "";
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus &&
        _searchController.text.isNotEmpty &&
        _overlayEntry == null) {
      _showSearchResultsOverlay();
    } else if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      _removeOverlay();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) { _removeOverlay(); setState(() {}); return; }
      if (_overlayEntry == null) _showSearchResultsOverlay();
      else _overlayEntry?.markNeedsBuild();
      setState(() {});
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _removeOverlay();
    _searchFocusNode.unfocus();
    setState(() {});
  }

  void _showSearchResultsOverlay() {
    if (_overlayEntry != null || _dialogOpen) return;
    final box = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size   = box.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Provider.of<ThemeNotifier>(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () { _removeOverlay(); _searchFocusNode.unfocus(); },
              ),
            ),
            Positioned(
              width: size.width,
              left:  offset.dx,
              top:   offset.dy + size.height,
              child: Material(
                elevation: 6,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(
                    color: theme.themeMode == ThemeMode.dark
                        ? ThemeNotifier.secondaryBackground
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft:  Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildLocalResultsList(),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildLocalResultsList() {
    final query = _searchController.text.toLowerCase();
    if (!_cacheLoaded) return const Center(child: CircularProgressIndicator());
    if (_cachedProducts.isEmpty) return const Center(child: Text("No products in cache"));

    final Map<String, dynamic> unique = {};
    for (final p in _cachedProducts) {
      final name = (p["fast_key_item_name"] ?? "").toString().trim().toLowerCase();
      if (name.isEmpty || !name.contains(query)) continue;
      unique[name] = p;
    }

    final list = unique.values.toList()
      ..sort((a, b) {
        final na = (a["fast_key_item_name"] ?? "").toString().toLowerCase();
        final nb = (b["fast_key_item_name"] ?? "").toString().toLowerCase();
        final sa = na.startsWith(query);
        final sb = nb.startsWith(query);
        if (sa && !sb) return -1;
        if (!sa && sb) return 1;
        return na.compareTo(nb);
      });

    if (list.isEmpty) return const Center(child: Text("No items found"));

    return ListView.builder(
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p     = list[i];
        final name  = p["fast_key_item_name"]?.toString() ?? "Unknown";
        final price = p["fast_key_item_price"]?.toString() ?? "0.00";

        String? imageUrl;
        final imagesRaw = p["images"];
        if (imagesRaw != null) {
          if (imagesRaw is String && imagesRaw.isNotEmpty) {
            imageUrl = imagesRaw;
          } else if (imagesRaw is List && imagesRaw.isNotEmpty) {
            final first = imagesRaw.first;
            if (first is String) imageUrl = first;
            else if (first is Map && first["src"] != null) {
              imageUrl = first["src"].toString();
            }
          }
        }
        imageUrl ??= p["fast_key_item_image"]?.toString();

        return ListTile(
          leading: SizedBox(
            width: 50,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
              )
                  : const Icon(Icons.image, size: 40),
            ),
          ),
          title:    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text("\$$price"),
          onTap: () async {
            ProductResponse fullProduct = ProductResponse(
              id:     int.tryParse(p["fast_key_product_id"]?.toString() ?? "0") ?? 0,
              name:   name,
              price:  price,
              sku:    p["sku"]?.toString(),
              images: imageUrl != null ? [imageUrl] : [],
            );

            try {
              final isar    = await IsarService.instance;
              final entries = await isar.isarCacheEntrys
                  .where()
                  .filter()
                  .keyStartsWith("products_")
                  .findAll();

              for (final entry in entries) {
                final List<dynamic> cached = jsonDecode(entry.json);
                final match = cached.firstWhere(
                      (item) => item["fast_key_product_id"]?.toString() ==
                      p["fast_key_product_id"]?.toString(),
                  orElse: () => null,
                );
                if (match != null) {
                  final rawTags = match["tags"];
                  if (rawTags is List) {
                    fullProduct.tags = rawTags.map((t) => SKU.Tags(
                      id: t["id"], name: t["name"], slug: t["slug"],
                    )).toList();
                  }
                  break;
                }
              }
            } catch (e) {
              debugPrint("Enrich product failed: $e");
            }

            _handleProductTap(fullProduct);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getVariantsFromCache(int productId) async {
    final isar    = await IsarService.instance;
    final entries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith("products_")
        .findAll();

    for (final entry in entries) {
      final List<dynamic> products = jsonDecode(entry.json);
      final match = products.firstWhere(
            (p) => p["fast_key_product_id"]?.toString() == productId.toString(),
        orElse: () => null,
      );
      if (match == null) continue;

      final rawVariations = match["variations"];
      if (rawVariations is! List || rawVariations.isEmpty) continue;

      final List<Map<String, dynamic>> variants = [];
      for (final v in rawVariations) {
        if (v is Map<String, dynamic>) {
          variants.add({
            "id":    v["id"],
            "name":  v["name"] ?? (v["attributes"] as List?)?.map((a) => a["option"]).join(" - "),
            "price": v["regular_price"] ?? v["price"] ?? "0",
            "image": v["image"]?["src"],
            "sku":   v["sku"],
          });
        } else if (v is int) {
          variants.add({
            "id": v, "name": "Variant",
            "price": match["price"] ?? "0",
            "image": match["image"], "sku": match["sku"],
          });
        }
      }
      if (variants.isNotEmpty) return variants;
    }
    return [];
  }

  Future<void> _handleProductTap(ProductResponse product) async {
    try {
      _searchFocusNode.unfocus();
      _removeOverlay();

      var screen = widget.screen;
      if (screen != Screen.FASTKEY && screen != Screen.CATEGORY && screen != Screen.ADD) {
        if (kDebugMode) print("TopBar - return from product selection (invalid screen)");
        return;
      }

      final ensuredOrderId = await orderHelper.ensureOrderExists();
      if (ensuredOrderId == null) {
        if (kDebugMode) print("Failed to create or restore order");
        return;
      }

      final offlineBox    = StorageProvider.offlineOrders;
      final activeOrderId = ensuredOrderId.toString();
      final raw           = await offlineBox.get(activeOrderId);
      final Map<String, dynamic> rawOrder =
      Map<String, dynamic>.from(raw is Map ? raw : {});

      List<dynamic> lineItems = List.from(rawOrder['line_items'] ?? []);

      // ── Age verification ────────────────────────────────────────────────────
      final tags = product.tags ?? [];
      final bool hasAgeRestriction =
      tags.any((t) => t.name == TextConstants.age_restricted);

      SKU.Tags? ageRestrictedTag;
      if (hasAgeRestriction) {
        ageRestrictedTag = tags.firstWhere((t) => t.name == TextConstants.age_restricted);
      }

      final dynamic hiveAge      = rawOrder["age_verified"];
      final bool alreadyVerified = hiveAge == true ||
          hiveAge == 1 ||
          hiveAge?.toString().toLowerCase() == "true";

      if (hasAgeRestriction && !alreadyVerified) {
        final int minAge = int.tryParse(ageRestrictedTag?.slug?.toString() ?? "0") ?? 0;
        print("🔞 Showing Age Verification Popup (SEARCH)");
        _dialogOpen = true;
        _searchFocusNode.unfocus();
        _removeOverlay();
        await WidgetsBinding.instance.endOfFrame;

        final prov = AgeVerificationProvider();
        final ok   = await prov.verifyAge(context, minAge: minAge);
        _dialogOpen = false;

        if (!ok) { print("❌ Age verification failed"); return; }
        rawOrder["age_verified"] = true;
        await offlineBox.put(activeOrderId.toString(), rawOrder);
      }

      // ── EBT eligibility ─────────────────────────────────────────────────────
      bool isEbtEligible = false;
      try {
        final isar         = await IsarService.instance;
        final cachedEntries = await isar.isarCacheEntrys
            .where()
            .filter()
            .keyStartsWith("products_")
            .findAll();
        for (final entry in cachedEntries) {
          final List<dynamic> products = jsonDecode(entry.json);
          final match = products.firstWhere(
                (p) => p["fast_key_product_id"]?.toString() == product.id.toString(),
            orElse: () => null,
          );
          if (match != null) {
            isEbtEligible = match["is_ebt_eligible"] == true;
            if (kDebugMode) print("🥗 EBT → ${match["fast_key_item_name"]} | $isEbtEligible");
            break;
          }
        }
      } catch (e) {
        if (kDebugMode) print("⚠️ EBT resolve error: $e");
      }

      // ── Produce → Auto Weight Popup ─────────────────────────────────────────
      final bool hasProduceTag = tags.any((t) =>
      t.slug?.toLowerCase() == "produce" || t.name?.toLowerCase() == "produce");

      if (hasProduceTag) {
        print("🌿 Produce detected → AutoWeightPriceDialog");
        _removeOverlay();
        await Future.delayed(const Duration(milliseconds: 40));

        final double unitPrice = (product.price is num)
            ? (product.price as num).toDouble()
            : double.tryParse(product.price?.toString() ?? "0") ?? 0.0;

        _dialogOpen = true;
        _searchFocusNode.unfocus();
        _removeOverlay();

        final result = await showDialog(
          context: _context,
          barrierDismissible: false,
          builder: (_) => AutoWeightPriceDialog(
            productName: product.name ?? "Product",
            unitPrice:   unitPrice,
          ),
        );
        _dialogOpen = false;

        if (result == null) { print("⚠️ Auto weight cancelled"); return; }

        final double finalPrice = result["finalPrice"];
        final double weight     = result["weight"];

        setState(() => isAddingItemLoading = true);
        await orderHelper.addItemToOrder(
          product.id!, product.name ?? 'Unknown',
          product.images?.isNotEmpty == true ? product.images!.first : '',
          finalPrice, 1, product.sku ?? '',
          int.parse(activeOrderId),
          type: "weighted", productId: product.id, variationId: -1,
          unitPrice: unitPrice, salesPrice: finalPrice, regularPrice: unitPrice,
          combo: null, isEbtEligible: isEbtEligible,
          onItemAdded: () {
            _removeOverlay(); _clearSearch();
            setState(() => isAddingItemLoading = false);
            widget.onProductSelected?.call(product);
          },
        );
        return;
      }

      // ── Variants / Variable price ────────────────────────────────────────────
      final double productPrice = (product.price is num)
          ? (product.price as num).toDouble()
          : double.tryParse(product.price?.toString() ?? "") ?? 0.0;

      double finalPrice = productPrice;

      final bool hasVariablePriceTag = tags.any((t) =>
      t.slug?.toLowerCase() == "variable-product" ||
          t.slug?.toLowerCase() == "variable" ||
          t.name?.toLowerCase() == "variable product" ||
          t.name?.toLowerCase() == "variable");

      final String variableKey   = "variable_price_added_${product.id}";
      final String savedPriceKey = "selected_price_${product.id}";
      final bool popupAlreadyShown = rawOrder[variableKey] == true;

      if (popupAlreadyShown) {
        final savedPrice = rawOrder[savedPriceKey] ?? productPrice;
        finalPrice = double.tryParse(savedPrice.toString()) ?? productPrice;
      }

      final cachedVariants = await _getVariantsFromCache(product.id!);
      bool hasVariants = cachedVariants.isNotEmpty;

      if (!hasVariants) {
        productBloc.fetchProductVariations(product.id!);
        final response = await productBloc.variationStream
            .firstWhere((r) => r.status == Status.COMPLETED);
        hasVariants = response.data != null && response.data!.isNotEmpty;
      }

      if (hasVariants) {
        productBloc.fetchProductVariations(product.id!);
        final response = await productBloc.variationStream
            .firstWhere((r) => r.status == Status.COMPLETED);

        List<Map<String, dynamic>> variants = [];
        if (response.data != null && response.data!.isNotEmpty) {
          variants = response.data!.map((v) => {
            "id": v.id, "name": v.name ?? "Variant",
            "price": v.price ?? "0", "image": v.image?.src ?? "", "sku": v.sku ?? "",
          }).toList();
        } else {
          variants = cachedVariants;
        }
        if (variants.isEmpty) return;

        _removeOverlay();
        await Future.delayed(const Duration(milliseconds: 40));
        _removeOverlay();

        await showDialog(
          context: _context,
          barrierDismissible: false,
          builder: (_) => VariantsDialog(
            title:      product.name ?? "Select Variant",
            variations: variants,
            onAddVariant: (selected, qty) async {
              final price = double.tryParse(selected["price"].toString()) ?? 0;
              await orderHelper.addItemToOrder(
                selected["id"], selected["name"], selected["image"], price, qty,
                selected["sku"], int.parse(activeOrderId),
                type: 'variant', productId: product.id, variationId: selected["id"],
                isEbtEligible: isEbtEligible,
                onItemAdded: () {
                  _removeOverlay(); _clearSearch();
                  if (mounted) setState(() => isAddingItemLoading = false);
                  widget.onProductSelected?.call(product);
                },
              );
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        );

        _removeOverlay();
        _clearSearch();
        setState(() => isAddingItemLoading = false);
        return;
      }

      if (hasVariablePriceTag && !popupAlreadyShown) {
        _removeOverlay();
        await Future.delayed(const Duration(milliseconds: 40));
        _removeOverlay();

        final enteredPrice = await ManualPriceDialog.show(
          _context,
          productName:  product.name ?? "Product",
          productImage: _getProductImage(product),
          minPrice:     productPrice,
        );
        if (enteredPrice == null) return;

        finalPrice             = enteredPrice;
        rawOrder[variableKey]  = true;
        rawOrder[savedPriceKey] = finalPrice;
        await offlineBox.put(activeOrderId.toString(), rawOrder);
      }

      setState(() => isAddingItemLoading = true);

      try {
        await orderHelper.addItemToOrder(
          product.id!, product.name ?? 'Unknown',
          product.images?.isNotEmpty == true ? product.images!.first : '',
          finalPrice, 1, product.sku ?? '',
          int.tryParse(activeOrderId) ?? 0,
          type: "simple", productId: product.id!, variationId: -1,
          variationName: null, variationCount: 0, combo: null,
          salesPrice: finalPrice, regularPrice: finalPrice, unitPrice: finalPrice,
          isEbtEligible: isEbtEligible,
          onItemAdded: () {
            _removeOverlay(); _clearSearch();
            setState(() => isAddingItemLoading = false);
            widget.onProductSelected?.call(product);
          },
        );
      } catch (e, s) {
        print("❌ Simple product add error: $e\n$s");
        _removeOverlay();
        setState(() => isAddingItemLoading = false);
      }
    } catch (e, s) {
      if (kDebugMode) print("TopBar onTap Exception: $e\n$s");
      _removeOverlay();
      setState(() => isAddingItemLoading = false);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _fetchUserId() async {
    if (_isUserDataLoaded && _cachedUserData != null) {
      final userData = _cachedUserData;
      if (userData != null && userData[AppDBConst.userId] != null) {
        setState(() {
          userId          = userData[AppDBConst.userId] as int;
          userDisplayName = userData[AppDBConst.userDisplayName];
          userRole        = userData[AppDBConst.userRole];
        });
      }
      return;
    }
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId          = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        userRole        = userData[AppDBConst.userRole];
      });
    }
  }

  Future<bool> _showCashDrawerPinPopup(BuildContext context) async {
    final TextEditingController pinController = TextEditingController();
    bool isError = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: isDark
                    ? const Color(0xFF2F3241)
                    : Colors.white,
                child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔐 Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "Authentication Required ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Enter PIN to open cash drawer",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Inter',
                            color: isDark
                                ? Colors.white60
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 18),

                        // 🔢 PIN BOXES
                        _PinBoxField(
                          controller: pinController,
                          hasError: isError,
                        ),

                        if (isError) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "You are not authorized to access this feature.",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 🔘 ACTION BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFF50535F)
                                      : const Color(0xFFE0E0E0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final pin = pinController.text.trim();

                                  if (pin.length != 6) {
                                    setState(() => isError = true);
                                    return;
                                  }

                                  setState(() => isError = false);

                                  try {
                                    final response =
                                    await OrderRepository().validateLoginPin(pin); // ✅ positional

                                    final decoded = json.decode(response);

                                    if (decoded["success"] == true) {
                                      Navigator.pop(ctx, true);
                                    } else {
                                      setState(() => isError = true);
                                      pinController.clear();
                                    }
                                  } catch (e) {
                                    setState(() => isError = true);
                                    pinController.clear();
                                  }
                                },


                                child: const Text(
                                  "Confirm",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ));
          },
        );
      },
    ) ??
        false;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _context = context;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.primaryBackground
          : Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Logo ──────────────────────────────────────────────────────────
          SvgPicture.asset(
            themeHelper.themeMode == ThemeMode.dark
                ? 'assets/svg/app_logo.svg'
                : 'assets/svg/app_icon.svg',
            height: 40, width: 40,
          ),
          const SizedBox(width: 80),

          // ── Search bar ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFEDEBEB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF605F5F)
                        : Colors.grey.withOpacity(0.1),
                    blurRadius:   2,
                    spreadRadius: themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              height: 46,
              key: _searchFieldKey,
              child: TextField(
                enabled:    _isSearchEnabled,
                controller: _searchController,
                focusNode:  _searchFocusNode,
                decoration: InputDecoration(
                  hintText:   TextConstants.searchHint,
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color),
                    onPressed: _clearSearch,
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled:    true,
                  fillColor: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.searchBarBackground
                      : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 50),

          // ── Scale weight display ──────────────────────────────────────────
          // Consumer<WeightProvider>(
          //   builder: (context, weightProvider, _) {
          //     final bool connected = weightProvider.isConnected;
          //     final isDark = themeHelper.themeMode == ThemeMode.dark;
          //
          //     final parts    = weightProvider.weightText.trim().split(' ');
          //     final numPart  = parts.isNotEmpty ? parts[0] : '0.00';
          //     final unitPart = parts.length > 1  ? parts[1] : 'lb';
          //
          //     return GestureDetector(
          //       onLongPress: _reconnectScale, // long-press to force reconnect
          //       child: Row(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           if (connected) ...[
          //             // Grey pill: 7-segment number
          //             Container(
          //               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          //               decoration: BoxDecoration(
          //                 color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEAEAEA),
          //                 borderRadius: BorderRadius.circular(8),
          //               ),
          //               child: SevenSegmentDisplay(
          //                 text:        numPart,
          //                 digitHeight: 28,
          //                 onColor:  isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A),
          //                 offColor: isDark ? const Color(0xFF444444) : const Color(0xFFD0D0D0),
          //                 spacing: 3,
          //               ),
          //             ),
          //             const SizedBox(width: 6),
          //             // Dark pill: unit label
          //             Container(
          //               padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          //               decoration: BoxDecoration(
          //                 color: isDark ? const Color(0xFF444444) : const Color(0xFF3A3A3A),
          //                 borderRadius: BorderRadius.circular(8),
          //               ),
          //               child: Text(
          //                 unitPart,
          //                 style: const TextStyle(
          //                   fontSize: 15, fontWeight: FontWeight.w600,
          //                   color: Colors.white, letterSpacing: 0.5, height: 1.0,
          //                 ),
          //               ),
          //             ),
          //           ] else ...[
          //             // Disconnected / Connecting state
          //             GestureDetector(
          //               onTap: _isConnecting ? null : _reconnectScale,
          //               child: Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //                 decoration: BoxDecoration(
          //                   color: isDark
          //                       ? ThemeNotifier.secondaryBackground
          //                       : Colors.grey.shade100,
          //                   borderRadius: BorderRadius.circular(8),
          //                 ),
          //                 child: Row(
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     if (_isConnecting)
          //                       SizedBox(
          //                         width: 14, height: 14,
          //                         child: CircularProgressIndicator(
          //                           strokeWidth: 1.5,
          //                           color: Colors.grey.shade400,
          //                         ),
          //                       )
          //                     else
          //                       Icon(Icons.scale, size: 16, color: Colors.grey.shade400),
          //                     const SizedBox(width: 6),
          //                     Text(
          //                       _isConnecting ? 'Connecting...' : 'Scale disconnected',
          //                       style: TextStyle(
          //                         fontSize: 13, fontWeight: FontWeight.w500,
          //                         color: Colors.grey.shade500,
          //                       ),
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //             ),
          //           ],
          //         ],
          //       ),
          //     );
          //   },
          // ),
          const SizedBox(width: 16),

          // ── Cash drawer ───────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final isAuthorized = await _showCashDrawerPinPopup(context);
              if (!isAuthorized) return;
              await PrinterSettings.openDrawer(context: context);
              List<int> bytes  = [];
              final ticket     = await _printerSettings.getTicket();
              bytes           += ticket.feed(1);
              await _printerSettings.printTicket(bytes, ticket);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.cashDrawerIcon,
                width: 26, height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Mode toggle ───────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onModeChanged,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.changeModeIcon,
                width: 26, height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Theme toggle ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              themeHelper.setThemeMode(
                themeHelper.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF605F5F)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.themeIcon,
                width: 26, height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Notifications ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? const Color(0xFF3B3939)
                    : const Color(0xFFF1F1F3),
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.notifications, size: 24,
                color: themeHelper.themeMode == ThemeMode.dark
                    ? Colors.white
                    : Colors.black54),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : refreshProducts,
          ),

          // ── User chip ─────────────────────────────────────────────────────
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? const Color(0xFF3B3939)
                    : const Color(0xFFF1F1F3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    (userDisplayName ?? "Unknown").substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userDisplayName ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : ThemeNotifier.textLight,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      userRole ?? "Unknown",
                      style: const TextStyle(color: Color(0xFFE09696), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}