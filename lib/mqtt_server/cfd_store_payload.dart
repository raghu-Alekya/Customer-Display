import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Preferences/pinaka_preferences.dart';

/// Loads store branding + banner URLs for MQTT CFD.
class CfdStorePayload {
  final String storeId;
  final String storeName;
  final String? storeLogoUrl;
  final String? storeBaseUrl;
  final List<String> slideshowUrls;

  const CfdStorePayload({
    required this.storeId,
    required this.storeName,
    this.storeLogoUrl,
    this.storeBaseUrl,
    this.slideshowUrls = const [],
  });

  // ---------------------------------------------------------------------------
  // FIX: Cache the loaded payload for a short window.
  //
  // load() used to be called on every single cart publish (every item add,
  // qty change, tab switch, etc.), which meant re-reading SharedPreferences
  // and re-parsing the banner list dozens of times per second during rapid
  // scanning. That added real latency to the "update the customer display"
  // path. Caching for a few seconds removes that cost while still picking
  // up store/banner changes quickly if they're edited elsewhere in the app.
  // ---------------------------------------------------------------------------

  static CfdStorePayload? _cached;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 10);

  /// Clears the cache so the next [load] call re-reads from preferences.
  /// Call this after store settings (logo/banners/name) are changed.
  static void invalidateCache() {
    _cached = null;
    _cachedAt = null;
  }

  static Future<CfdStorePayload> load({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    final result = await _loadFresh();

    _cached = result;
    _cachedAt = DateTime.now();

    return result;
  }

  static Future<CfdStorePayload> _loadFresh() async {
    final storeInfo = PinakaPreferences.getLoggedInStore();

    // ========== TEMPORARY DEBUG – paste the full output ==========
    if (kDebugMode) {
      print('🏪 [CFD] ========== FULL STORE INFO ==========');
      storeInfo.forEach((key, value) {
        print('   $key → ${value.runtimeType} = $value');
      });
      print('🏪 [CFD] =====================================');
    }
    // =============================================================

    final storeId = _str(storeInfo['storeId'] ?? storeInfo['store_id']);
    final storeName = _str(storeInfo['storeName'] ?? storeInfo['store_name']);
    final storeBaseUrl = _nonEmpty(
      storeInfo['storeBaseUrl'] ??
          storeInfo['store_base_url'] ??
          storeInfo['baseUrl'] ??
          storeInfo['base_url'],
    );
    final storeLogoUrl = _resolveUrl(
      _nonEmpty(
        storeInfo['storeLogoUrl'] ??
            storeInfo['store_logo_url'] ??
            storeInfo['logo'] ??
            storeInfo['logo_url'],
      ),
      storeBaseUrl,
    );

    // ------------------------------------------------------------------
    // Collect banners from every common shape / key
    // ------------------------------------------------------------------
    final List<String> rawUrls = [];

    void absorb(dynamic raw) {
      if (raw == null) return;

      // Already a List
      if (raw is List) {
        for (final e in raw) {
          if (e is String && e.trim().isNotEmpty) {
            rawUrls.add(e.trim());
          } else if (e is Map) {
            final u = e['url'] ??
                e['src'] ??
                e['image'] ??
                e['image_url'] ??
                e['banner_url'] ??
                e['bannerUrl'] ??
                e['path'] ??
                e['link'];
            if (u != null && u.toString().trim().isNotEmpty) {
              rawUrls.add(u.toString().trim());
            }
          }
        }
        return;
      }

      // String – could be a single URL, comma list, or JSON array/object
      if (raw is String) {
        final t = raw.trim();
        if (t.isEmpty) return;

        // Try proper JSON first
        if (t.startsWith('[') || t.startsWith('{')) {
          try {
            final decoded = jsonDecode(t);
            absorb(decoded); // recursive – will hit the List/Map branches
            return;
          } catch (_) {
            // fall through to simple parsing
          }
        }

        // Comma-separated plain URLs
        if (t.contains(',')) {
          rawUrls.addAll(
            t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
          );
        } else {
          rawUrls.add(t);
        }
        return;
      }

      // Map that itself contains a list
      if (raw is Map) {
        for (final key in [
          'banners',
          'slideshowUrls',
          'slideshow_urls',
          'slides',
          'images',
          'urls',
        ]) {
          if (raw.containsKey(key)) absorb(raw[key]);
        }
      }
    }

    // Top-level keys that are commonly used
    const possibleKeys = [
      'slideshowUrls',
      'slideshow_urls',
      'banners',
      'banner_urls',
      'bannerUrls',
      'storeBanners',
      'store_banners',
      'customer_display_banners',
      'customerDisplayBanners',
      'cfd_banners',
      'cfdBanners',
      'promo_images',
      'promoImages',
      'slides',
      'slider_images',
      'sliderImages',
      'banner',
      'banner_url',
      'bannerUrl',
    ];

    for (final key in possibleKeys) {
      absorb(storeInfo[key]);
    }

    // Nested under "store" / "storeInfo" / "data" / "settings"
    for (final nestKey in ['store', 'storeInfo', 'data', 'settings']) {
      final nested = storeInfo[nestKey];

      if (nested is Map) {
        // Explicit cast – works on all Dart versions
        final map = Map<dynamic, dynamic>.from(nested as Map);
        for (final key in possibleKeys) {
          absorb(map[key]);
        }
      }
    }
    // ------------------------------------------------------------------
    // Resolve relative → absolute + de-dupe
    // ------------------------------------------------------------------
    final resolved = <String>[];
    final seen = <String>{};

    for (final u in rawUrls) {
      final full = _resolveUrl(u, storeBaseUrl) ?? u;
      if (full.isEmpty) continue;
      if (seen.add(full)) resolved.add(full);
    }

    if (kDebugMode) {
      print('🏪 [CFD] storeName=$storeName logo=$storeLogoUrl');
      print('🏪 [CFD] banner count=${resolved.length}');
      for (var i = 0; i < resolved.length; i++) {
        print('   banner[$i]=${resolved[i]}');
      }
    }

    return CfdStorePayload(
      storeId: storeId,
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      storeBaseUrl: storeBaseUrl,
      slideshowUrls: resolved,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _resolveUrl(String? url, String? base) {
    if (url == null || url.isEmpty) return null;
    final u = url.trim();
    if (u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('file://') ||
        u.startsWith('data:')) {
      return u;
    }
    if (base == null || base.isEmpty) return u;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = u.startsWith('/') ? u : '/$u';
    return '$b$p';
  }
}