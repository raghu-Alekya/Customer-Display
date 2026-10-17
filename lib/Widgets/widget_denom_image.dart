import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a denomination image from the bootstrap API or a bundled asset.
/// Supports inline data URIs (data:image/svg+xml;base64,... and raster
/// data:image/png|jpeg;base64,...), http(s) URLs and asset paths.
class DenomImage extends StatelessWidget {
  final String? source;
  final double width;
  final double height;
  final String fallbackAsset;

  const DenomImage({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.fallbackAsset = 'assets/svg/1.svg',
  });

  // Decoded data URIs, so list rebuilds don't re-decode base64 every frame.
  static final Map<String, Uint8List> _bytesCache = {};

  @override
  Widget build(BuildContext context) {
    final src = source?.trim() ?? '';
    if (src.isEmpty) return _fallback();

    if (src.startsWith('data:image/')) {
      final bytes = _decodeDataUri(src);
      if (bytes == null) return _fallback();
      if (src.startsWith('data:image/svg')) {
        return SvgPicture.memory(bytes,
            width: width, height: height, fit: BoxFit.contain,
            placeholderBuilder: (_) => _fallback());
      }
      return Image.memory(bytes,
          width: width, height: height, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback());
    }

    if (src.startsWith('http')) {
      if (Uri.tryParse(src)?.path.toLowerCase().endsWith('.svg') ?? false) {
        return SvgPicture.network(src,
            width: width, height: height, fit: BoxFit.contain,
            placeholderBuilder: (_) => _fallback());
      }
      return Image.network(src,
          width: width, height: height, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback());
    }

    if (src.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(src, width: width, height: height, fit: BoxFit.contain);
    }
    return Image.asset(src,
        width: width, height: height, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback());
  }

  Widget _fallback() =>
      SvgPicture.asset(fallbackAsset, width: width, height: height, fit: BoxFit.contain);

  static Uint8List? _decodeDataUri(String uri) {
    final cached = _bytesCache[uri];
    if (cached != null) return cached;
    try {
      final data = UriData.parse(uri);
      final bytes = data.contentAsBytes();
      _bytesCache[uri] = bytes;
      return bytes;
    } catch (e) {
      if (kDebugMode) print("#### DenomImage: failed to decode data URI: $e");
      return null;
    }
  }
}
