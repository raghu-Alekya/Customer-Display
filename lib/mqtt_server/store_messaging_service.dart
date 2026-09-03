// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:typed_data/typed_data.dart';
// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:mqtt_server/mqtt_server.dart';
// import 'package:nsd/nsd.dart';
//
// import 'cart_state.dart';
// // ⬇️ Make sure this import points to where CfdStorePayload lives
// import 'cfd_store_payload.dart'; // <-- adjust path if needed
//
// class StoreMessagingService {
//   final String merchantId;
//   final String storeId;
//   final String terminalId;
//   final String brokerUsername;
//   final String brokerToken;
//
//   MqttBroker? _broker;
//   MqttServerClient? _publisherClient;
//
//   int _sequence = 0;
//   bool _isReady = false;
//
//   Registration? _mdnsRegistration;
//
//   // ---------------------------------------------------------------------------
//   // MQTT PAYLOAD LIMITS
//   // ---------------------------------------------------------------------------
//   static const int _maxSinglePublishBytes = 1024;
//   static const int _maxChunkPublishBytes = 1024;
//   static const int _initialChunkDataSize = 900;
//   static const Duration _publishDelay = Duration(milliseconds: 30);
//
//   final Map<String, int> _lastChunkCountByTopic = {};
//   final Map<String, int> _lastSequenceByTopic = {};
//
//   // 🔑 NEW — remembers the last published payload (content only, no
//   // sequence) per topic so identical back-to-back states are never
//   // re-sent. This stops publish floods (e.g. many redundant IDLE
//   // publishes firing within milliseconds of each other from multiple
//   // call-sites) from corrupting the embedded broker's packet framing.
//   final Map<String, String> _lastPublishedFingerprint = {};
//
//   Future<void> _publishQueue = Future.value();
//
//   StoreMessagingService({
//     required this.merchantId,
//     required this.storeId,
//     required this.terminalId,
//     required this.brokerUsername,
//     required this.brokerToken,
//   });
//
//   // ---------------------------------------------------------------------------
//   // TOPIC
//   // ---------------------------------------------------------------------------
//
//   String get _topicPrefix =>
//       'pinaka/$merchantId/$storeId/$terminalId/cfd';
//
//   bool get isReady => _isReady;
//
//   // ---------------------------------------------------------------------------
//   // BROKER
//   // ---------------------------------------------------------------------------
//
//   Future<void> startBroker() async {
//     try {
//       final config = MqttBrokerConfig(
//         port: 1883,
//         allowAnonymous: true,
//       );
//
//       _broker = MqttBroker(config);
//       _broker!.addCredentials(brokerUsername, brokerToken);
//       await _broker!.start();
//
//       print('✅ MQTT Broker started on port 1883');
//       await Future.delayed(const Duration(milliseconds: 1500));
//       print('🔍 Broker warm-up delay complete');
//     } catch (e, st) {
//       print('❌ Failed to start MQTT broker: $e');
//       print(st);
//       rethrow;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // mDNS ADVERTISEMENT
//   // ---------------------------------------------------------------------------
//
//   Future<void> startMdnsAdvertisement() async {
//     try {
//       if (_mdnsRegistration != null) {
//         await unregister(_mdnsRegistration!);
//         _mdnsRegistration = null;
//       }
//
//       final txt = <String, Uint8List?>{
//         'terminal': Uint8List.fromList(utf8.encode(terminalId)),
//         'store': Uint8List.fromList(utf8.encode(storeId)),
//         'merchant': Uint8List.fromList(utf8.encode(merchantId)),
//       };
//
//       _mdnsRegistration = await register(
//         Service(
//           name: 'PINAKA-$terminalId',
//           type: '_pinaka-pos._tcp',
//           port: 1883,
//           txt: txt,
//         ),
//       );
//
//       print(
//         '📡 mDNS advertised: PINAKA-$terminalId '
//             '(_pinaka-pos._tcp :1883) '
//             'terminal=$terminalId store=$storeId merchant=$merchantId',
//       );
//     } catch (e, st) {
//       print('❌ mDNS advertisement failed: $e');
//       print(st);
//     }
//   }
//
//   Future<void> stopMdnsAdvertisement() async {
//     if (_mdnsRegistration == null) return;
//     try {
//       await unregister(_mdnsRegistration!);
//       print('📡 mDNS unregistered');
//     } catch (e) {
//       print('⚠️ mDNS unregister failed: $e');
//     }
//     _mdnsRegistration = null;
//   }
//
//   // ---------------------------------------------------------------------------
//   // LOCAL IP
//   // ---------------------------------------------------------------------------
//
//   Future<String?> getDeviceLocalIp() async {
//     try {
//       final interfaces = await NetworkInterface.list(
//         type: InternetAddressType.IPv4,
//         includeLinkLocal: false,
//       );
//
//       for (final interface in interfaces) {
//         for (final address in interface.addresses) {
//           final ip = address.address;
//           if (ip.startsWith('192.168.') ||
//               ip.startsWith('10.') ||
//               ip.startsWith('172.')) {
//             return ip;
//           }
//         }
//       }
//
//       for (final interface in interfaces) {
//         for (final address in interface.addresses) {
//           if (!address.isLoopback) return address.address;
//         }
//       }
//     } catch (e) {
//       print('❌ Failed to get local IP: $e');
//     }
//     return null;
//   }
//
//   // ---------------------------------------------------------------------------
//   // PUBLISHER
//   // ---------------------------------------------------------------------------
//
//   Future<void> startPublisher() async {
//     await Future.delayed(const Duration(milliseconds: 500));
//
//     final lanIp = await getDeviceLocalIp();
//     final brokerIps = <String>[
//       '127.0.0.1',
//       if (lanIp != null && lanIp != '127.0.0.1') lanIp,
//     ];
//
//     for (final brokerIp in brokerIps) {
//       print('🔌 Trying MQTT broker: $brokerIp:1883');
//
//       final client = MqttServerClient.withPort(
//         brokerIp,
//         'POS-$terminalId-publisher',
//         1883,
//       );
//
//       client.setProtocolV311();
//       client.logging(on: true);
//       client.keepAlivePeriod = 20;
//       client.connectTimeoutPeriod = 5000;
//       client.autoReconnect = true;
//       client.resubscribeOnAutoReconnect = true;
//
//       final connMessage = MqttConnectMessage()
//           .withClientIdentifier('POS-$terminalId-publisher')
//           .startClean();
//
//       client.connectionMessage = connMessage;
//
//       try {
//         await client.connect();
//
//         if (client.connectionStatus?.state == MqttConnectionState.connected) {
//           _publisherClient = client;
//           _isReady = true;
//           print('✅ POS publisher connected to $brokerIp:1883');
//           return;
//         }
//
//         print('❌ Broker $brokerIp rejected connection');
//         client.disconnect();
//       } catch (e) {
//         print('❌ Failed to connect to $brokerIp:1883 — $e');
//         try {
//           client.disconnect();
//         } catch (_) {}
//       }
//     }
//
//     _isReady = false;
//     print('❌ POS publisher could not connect to any broker');
//     throw Exception('MQTT publisher failed to connect to any broker host');
//   }
//
//   // ---------------------------------------------------------------------------
//   // UTF-8 HELPERS
//   // ---------------------------------------------------------------------------
//
//   List<int> _utf8Bytes(String value) => utf8.encode(value);
//
//   // ---------------------------------------------------------------------------
//   // SAFE CHUNK SPLITTING
//   // ---------------------------------------------------------------------------
//
//   List<String> _splitPayloadSafely(String payload) {
//     final chunks = <String>[];
//     var start = 0;
//
//     while (start < payload.length) {
//       var end = start + _initialChunkDataSize;
//       if (end > payload.length) end = payload.length;
//
//       String? acceptedPiece;
//
//       while (end > start) {
//         final piece = payload.substring(start, end);
//         final bytes = utf8.encode(piece).length;
//
//         if (bytes <= _maxChunkPublishBytes) {
//           acceptedPiece = piece;
//           break;
//         }
//
//         end -= 8;
//         if (end < start) end = start;
//       }
//
//       if (acceptedPiece == null) {
//         throw Exception(
//           'Unable to create safe MQTT chunk at position $start',
//         );
//       }
//
//       chunks.add(acceptedPiece);
//       start += acceptedPiece.length;
//     }
//
//     return chunks;
//   }
//
//   // ---------------------------------------------------------------------------
//   // PUBLISH RAW
//   // ---------------------------------------------------------------------------
//
//   // Future<void> _publishRaw(
//   //     String topic,
//   //     String payload, {
//   //       bool retain = true,
//   //     }) async {
//   //   final client = _publisherClient;
//   //
//   //   if (client == null ||
//   //       client.connectionStatus?.state != MqttConnectionState.connected) {
//   //     throw Exception('MQTT publisher is not connected');
//   //   }
//   //
//   //   final bytes = _utf8Bytes(payload);
//   //   final buffer = MqttClientPayloadBuilder();
//   //   buffer.addBuffer(Uint8Buffer()..addAll(bytes));
//   //
//   //   print('📤 RAW MQTT publish topic=$topic bytes=${buffer.payload!.length}');
//   //
//   //   client.publishMessage(
//   //     topic,
//   //     MqttQos.atLeastOnce,
//   //     buffer.payload!,
//   //     retain: retain,
//   //   );
//   //
//   //   await Future.delayed(_publishDelay);
//   // }
//
//   Future<void> _publishRaw(
//       String topic,
//       String payload, {
//         bool retain = false,
//       }) async {
//     if (_publisherClient == null) return;
//
//     final bytes = utf8.encode(payload);
//     final builder = MqttClientPayloadBuilder()
//       ..addBuffer(Uint8Buffer()..addAll(bytes));
//
//     _publisherClient!.publishMessage(
//       topic,
//       MqttQos.atLeastOnce,
//       builder.payload!,
//       retain: retain,
//     );
//
//     print('📤 RAW MQTT publish topic=$topic bytes=${bytes.length}');
//   }
//
//   // ---------------------------------------------------------------------------
//   // CLEAR HELPERS
//   // ---------------------------------------------------------------------------
//
//   // Future<void> _clearSequenceChunks(
//   //     String baseTopic,
//   //     int sequence,
//   //     int maxIndex,
//   //     ) async {
//   //   for (var i = 0; i <= maxIndex; i++) {
//   //     try {
//   //       final topic = '$baseTopic/chunk/$sequence/$i';
//   //       final emptyBuilder = MqttClientPayloadBuilder();
//   //       _publisherClient!.publishMessage(
//   //         topic,
//   //         MqttQos.atLeastOnce,
//   //         Uint8Buffer()..addAll(emptyBuilder.payload ?? []),
//   //         retain: true,
//   //       );
//   //       await Future.delayed(const Duration(milliseconds: 15));
//   //     } catch (_) {}
//   //   }
//   // }
//
//   Future<void> _clearSequenceChunks(
//       String baseTopic,
//       int sequence,
//       int maxIndex,
//       ) async {
//     // Only clear a reasonable number, and NEVER retain
//     final clearUpTo = maxIndex.clamp(0, 6); // safety limit
//
//     for (var i = 0; i <= clearUpTo; i++) {
//       try {
//         final topic = '$baseTopic/chunk/$sequence/$i';
//
//         final clearBytes = utf8.encode('{}');
//         final builder = MqttClientPayloadBuilder()
//           ..addBuffer(Uint8Buffer()..addAll(clearBytes));
//
//         _publisherClient!.publishMessage(
//           topic,
//           MqttQos.atMostOnce,   // QoS 0 is safer for clears
//           builder.payload!,
//           retain: false,        // ← CRITICAL: do not retain
//         );
//
//         await Future.delayed(const Duration(milliseconds: 8));
//       } catch (_) {}
//     }
//   }
//
//   // Future<void> _clearStaleChunks(
//   //     String baseTopic,
//   //     int sequence,
//   //     int newChunkCount,
//   //     ) async {
//   //   final previousCount = _lastChunkCountByTopic[baseTopic] ?? 0;
//   //   final previousSequence = _lastSequenceByTopic[baseTopic];
//   //
//   //   if (previousSequence != null && previousSequence != sequence) {
//   //     for (var i = 0; i < previousCount + 3; i++) {
//   //       try {
//   //         final topic = '$baseTopic/chunk/$previousSequence/$i';
//   //         final emptyBuilder = MqttClientPayloadBuilder();
//   //         _publisherClient!.publishMessage(
//   //           topic,
//   //           MqttQos.atLeastOnce,
//   //           Uint8Buffer()..addAll(emptyBuilder.payload ?? []),
//   //           retain: true,
//   //         );
//   //         print('🧹 Cleared stale retained chunk $topic');
//   //         await Future.delayed(_publishDelay);
//   //       } catch (e) {
//   //         print('⚠️ Failed clearing stale chunk index=$i — $e');
//   //       }
//   //     }
//   //   }
//   //
//   //   _lastChunkCountByTopic[baseTopic] = newChunkCount;
//   //   _lastSequenceByTopic[baseTopic] = sequence;
//   // }
//
//   Future<void> _clearStaleChunks(
//       String baseTopic,
//       int sequence,
//       int newChunkCount,
//       ) async {
//     final previousCount = _lastChunkCountByTopic[baseTopic] ?? 0;
//     final previousSequence = _lastSequenceByTopic[baseTopic];
//
//     if (previousSequence != null && previousSequence != sequence) {
//       // Only clear a few extra slots, never more than 6
//       final clearUpTo = (previousCount + 2).clamp(0, 6);
//
//       for (var i = 0; i < clearUpTo; i++) {
//         try {
//           final topic = '$baseTopic/chunk/$previousSequence/$i';
//
//           final clearBytes = utf8.encode('{}');
//           final builder = MqttClientPayloadBuilder()
//             ..addBuffer(Uint8Buffer()..addAll(clearBytes));
//
//           _publisherClient!.publishMessage(
//             topic,
//             MqttQos.atMostOnce,   // QoS 0
//             builder.payload!,
//             retain: false,        // ← CRITICAL
//           );
//
//           print('🧹 Cleared stale chunk $topic (non-retained)');
//           await Future.delayed(const Duration(milliseconds: 8));
//         } catch (e) {
//           print('⚠️ Failed clearing stale chunk index=$i — $e');
//         }
//       }
//     }
//
//     _lastChunkCountByTopic[baseTopic] = newChunkCount;
//     _lastSequenceByTopic[baseTopic] = sequence;
//   }
//
//   // ---------------------------------------------------------------------------
//   // FINGERPRINT HELPER (for dedupe)
//   // ---------------------------------------------------------------------------
//
//   String _fingerprint(Map<String, dynamic> data) {
//     // Exclude sequence from the fingerprint — only the actual content
//     // matters for deciding whether this is a "real" change or a
//     // redundant re-publish of the same state.
//     final copy = Map<String, dynamic>.from(data)..remove('sequence');
//     return jsonEncode(copy);
//   }
//
//   // ---------------------------------------------------------------------------
//   // INTERNAL PUBLISH
//   // ---------------------------------------------------------------------------
//
//   // Future<void> _publishJsonInternal(
//   //     String baseTopic,
//   //     Map<String, dynamic> data,
//   //     ) async {
//   //   if (!_isReady ||
//   //       _publisherClient?.connectionStatus?.state !=
//   //           MqttConnectionState.connected) {
//   //     print('⚠️ MQTT not ready – skip publish to $baseTopic');
//   //     return;
//   //   }
//   //
//   //   // 🔑 NEW — dedupe identical consecutive publishes on this topic.
//   //   // A content-identical publish (e.g. repeated IDLE states fired from
//   //   // multiple call-sites within milliseconds of each other) is skipped
//   //   // so we stop flooding the embedded broker with redundant packets,
//   //   // which was corrupting packet framing and breaking the CFD's live
//   //   // connection.
//   //   final fingerprint = _fingerprint(data);
//   //   if (_lastPublishedFingerprint[baseTopic] == fingerprint) {
//   //     print('⏭️ [MQTT] Skipped duplicate publish to $baseTopic (unchanged content)');
//   //     return;
//   //   }
//   //   _lastPublishedFingerprint[baseTopic] = fingerprint;
//   //
//   //   final payload = jsonEncode(data);
//   //   final payloadBytes = _utf8Bytes(payload);
//   //   final sequence = _parseSequence(data['sequence']);
//   //
//   //   print('');
//   //   print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   //   print('📦 [MQTT] Preparing payload');
//   //   print('📦 [MQTT] Topic: $baseTopic');
//   //   print('📦 [MQTT] Sequence: $sequence');
//   //   print('📦 [MQTT] JSON bytes: ${payloadBytes.length}');
//   //   print('📦 [MQTT] JSON chars: ${payload.length}');
//   //   print('📦 [MQTT] JSON: $payload');
//   //
//   //   // -------------------------------------------------------------------------
//   //   // SMALL PAYLOAD (direct)
//   //   // -------------------------------------------------------------------------
//   //   if (payloadBytes.length <= _maxSinglePublishBytes) {
//   //     try {
//   //       await _publishRaw(baseTopic, payload, retain: true);
//   //       await _clearStaleChunks(baseTopic, sequence, 0);
//   //       print('✅ [MQTT] Direct publish complete');
//   //     } catch (e, st) {
//   //       print('❌ [MQTT] Direct publish failed: $e');
//   //       print(st);
//   //     }
//   //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   //     return;
//   //   }
//   //
//   //   // -------------------------------------------------------------------------
//   //   // CHUNKED PAYLOAD
//   //   // -------------------------------------------------------------------------
//   //   final chunks = _splitPayloadSafely(payload);
//   //
//   //   print('📦 [MQTT] Payload requires chunking');
//   //   print('📦 [MQTT] Total bytes: ${payloadBytes.length}');
//   //   print('📦 [MQTT] Chunk count: ${chunks.length}');
//   //
//   //   // Clear any old retained messages for THIS sequence (restart safety)
//   //   await _clearSequenceChunks(baseTopic, sequence, chunks.length + 2);
//   //
//   //   // META
//   //   final metaPayload = jsonEncode({
//   //     'sequence': sequence,
//   //     'chunkCount': chunks.length,
//   //     'version': 2,
//   //   });
//   //
//   //   print('📤 [MQTT] META: $metaPayload');
//   //   await _publishRaw('$baseTopic/meta', metaPayload, retain: true);
//   //
//   //   // CHUNKS
//   //   for (var i = 0; i < chunks.length; i++) {
//   //     final chunk = chunks[i];
//   //     final chunkBytes = _utf8Bytes(chunk);
//   //
//   //     if (chunkBytes.length > _maxChunkPublishBytes) {
//   //       throw Exception(
//   //         'MQTT chunk $i exceeds $_maxChunkPublishBytes bytes',
//   //       );
//   //     }
//   //
//   //     final topic = '$baseTopic/chunk/$sequence/$i';
//   //
//   //     print('📤 [MQTT] CHUNK $i/${chunks.length - 1}');
//   //     print('📤 [MQTT] Chunk topic: $topic');
//   //     print('📤 [MQTT] Chunk bytes: ${chunkBytes.length}');
//   //     print('📤 [MQTT] Chunk data: $chunk');
//   //
//   //     await _publishRaw(topic, chunk, retain: true);
//   //   }
//   //
//   //   await _clearStaleChunks(baseTopic, sequence, chunks.length);
//   //
//   //   print('✅ [MQTT] Chunked publish complete');
//   //   print('📦 [MQTT] Original bytes: ${payloadBytes.length}');
//   //   print('📦 [MQTT] Chunks: ${chunks.length}');
//   //   print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   // }
//
//
//   Future<void> _publishJsonInternal(
//       String baseTopic,
//       Map<String, dynamic> data,
//       ) async {
//     if (!_isReady ||
//         _publisherClient?.connectionStatus?.state !=
//             MqttConnectionState.connected) {
//       print('⚠️ MQTT not ready – skip publish to $baseTopic');
//       return;
//     }
//
//     // Fingerprint without sequence
//     final fingerprint = _fingerprint(data);
//
//     // Always force publish when cart is empty so CFD gets 0-items update
//     final isEmptyCart = (data['items'] is List && (data['items'] as List).isEmpty) ||
//         (data['totalItems'] == 0);
//
//     if (!isEmptyCart &&
//         _lastPublishedFingerprint[baseTopic] == fingerprint) {
//       print('⏭️ [MQTT] Skipped duplicate publish to $baseTopic');
//       return;
//     }
//     _lastPublishedFingerprint[baseTopic] = fingerprint;
//
//     final payload = jsonEncode(data);
//     final payloadBytes = _utf8Bytes(payload);
//     final sequence = _parseSequence(data['sequence']);
//
//     print('');
//     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//     print('📦 [MQTT] Preparing payload');
//     print('📦 [MQTT] Topic: $baseTopic');
//     print('📦 [MQTT] Sequence: $sequence');
//     print('📦 [MQTT] JSON bytes: ${payloadBytes.length}');
//     print('📦 [MQTT] JSON chars: ${payload.length}');
//     print('📦 [MQTT] JSON: $payload');
//
//     // -------------------------------------------------------------------------
//     // SMALL PAYLOAD → direct publish
//     // -------------------------------------------------------------------------
//     if (payloadBytes.length <= _maxSinglePublishBytes) {
//       try {
//         // Use retain: false temporarily to stop RangeError
//         await _publishRaw(baseTopic, payload, retain: false);
//         print('✅ [MQTT] Direct publish complete');
//       } catch (e, st) {
//         print('❌ [MQTT] Direct publish failed: $e');
//         print(st);
//       }
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       return;
//     }
//
//     // -------------------------------------------------------------------------
//     // CHUNKED PAYLOAD
//     // -------------------------------------------------------------------------
//     final chunks = _splitPayloadSafely(payload);
//
//     print('📦 [MQTT] Payload requires chunking');
//     print('📦 [MQTT] Total bytes: ${payloadBytes.length}');
//     print('📦 [MQTT] Chunk count: ${chunks.length}');
//
//     // META (retain: false)
//     final metaPayload = jsonEncode({
//       'sequence': sequence,
//       'chunkCount': chunks.length,
//       'version': 2,
//     });
//
//     print('📤 [MQTT] META: $metaPayload');
//     await _publishRaw('$baseTopic/meta', metaPayload, retain: false);
//
//     // CHUNKS (retain: false)
//     for (var i = 0; i < chunks.length; i++) {
//       final chunk = chunks[i];
//       final chunkBytes = _utf8Bytes(chunk);
//
//       if (chunkBytes.length > _maxChunkPublishBytes) {
//         throw Exception(
//           'MQTT chunk $i exceeds $_maxChunkPublishBytes bytes',
//         );
//       }
//
//       final topic = '$baseTopic/chunk/$sequence/$i';
//
//       print('📤 [MQTT] CHUNK $i/${chunks.length - 1}');
//       print('📤 [MQTT] Chunk topic: $topic');
//       print('📤 [MQTT] Chunk bytes: ${chunkBytes.length}');
//
//       await _publishRaw(topic, chunk, retain: false);
//       await Future.delayed(const Duration(milliseconds: 50));
//
//     }
//
//     // Only update bookkeeping – NO actual clear publishes
//     await _clearStaleChunks(baseTopic, sequence, chunks.length);
//
//     print('✅ [MQTT] Chunked publish complete');
//     print('📦 [MQTT] Original bytes: ${payloadBytes.length}');
//     print('📦 [MQTT] Chunks: ${chunks.length}');
//     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   }
//
//   // ---------------------------------------------------------------------------
//   // SERIALIZED PUBLISH QUEUE
//   // ---------------------------------------------------------------------------
//
//   Future<void> _publishJson(
//       String baseTopic,
//       Map<String, dynamic> data,
//       ) {
//     final next = _publishQueue.then(
//           (_) => _publishJsonInternal(baseTopic, data),
//     );
//
//     _publishQueue = next.catchError((Object error, StackTrace stack) {
//       print('❌ [MQTT] Publish queue error: $error');
//       print(stack);
//     });
//
//     return next;
//   }
//
//   // ---------------------------------------------------------------------------
//   // 🔑 BRANDING HELPER – always attach store name / logo / banners
//   // ---------------------------------------------------------------------------
//
//   Future<Map<String, dynamic>> _withStoreBranding(
//       Map<String, dynamic> data,
//       ) async {
//     try {
//       final store = await CfdStorePayload.load();
//       return {
//         ...data,
//         // Always overwrite with current store branding so WELCOME/IDLE
//         // and screen-only publishes get the name/logo/banners.
//         'storeId': store.storeId,
//         'storeName': store.storeName,
//         'storeLogoUrl': store.storeLogoUrl,
//         'storeBaseUrl': store.storeBaseUrl,
//         'slideshowUrls': store.slideshowUrls,
//       };
//     } catch (e, st) {
//       print('⚠️ CFD branding load failed – publishing without store fields: $e');
//       print(st);
//       return data;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // PUBLIC API
//   // ---------------------------------------------------------------------------
//
//   Future<void> publishState(CartState state) async {
//     // Never trust an incoming sequence blindly — only adopt it if it's
//     // actually newer than what we've already sent. Otherwise always bump
//     // by 1. This guarantees every publish has a unique, increasing
//     // sequence number so the CFD's duplicate-suppression logic can never
//     // silently swallow a real update (which is what was happening with
//     // custom items / payouts).
//     if (state.sequence > _sequence) {
//       _sequence = state.sequence;
//     } else {
//       _sequence++;
//     }
//
//     final data = <String, dynamic>{
//       ...state.toJson(),
//       'sequence': _sequence,
//       'screen': state.screen,
//     };
//
//     final withBranding = await _withStoreBranding(data);
//
//     // 🔑 NEW — a non-idle publish invalidates the idle-clear marker set
//     // by publishIdleClear(), so the next real IDLE transition is
//     // allowed through again instead of being wrongly skipped.
//     if (state.screen != 'IDLE') {
//       _lastPublishedFingerprint.remove('$_topicPrefix/state');
//     }
//
//     print(
//       '🛒 Publishing cart state sequence=$_sequence '
//           'screen=${withBranding['screen']} store=${withBranding['storeName']}',
//     );
//
//     await _publishJson('$_topicPrefix/state', withBranding);
//   }
//
//   Future<void> publishScreen(
//       String screen, {
//         String? message,
//         double? total,
//       }) async {
//     _sequence++;
//     final data = <String, dynamic>{
//       'schemaVersion': 1,
//       'sequence': _sequence,
//       'screen': screen,
//       if (message != null) 'message': message,
//       if (total != null) 'total': total,
//       'items': <dynamic>[],
//       'orderId': null,
//       'summaryEnabled': false,
//     };
//
//     final withBranding = await _withStoreBranding(data);
//
//     if (screen != 'IDLE') {
//       _lastPublishedFingerprint.remove('$_topicPrefix/state');
//     }
//
//     print(
//       '🖥️ Publishing screen sequence=$_sequence screen=$screen '
//           'store=${withBranding['storeName']}',
//     );
//
//     await _publishJson('$_topicPrefix/state', withBranding);
//   }
//
//
//   /// Publish IDLE / Welcome — minimal payload, NO chunk clearing
//   Future<void> publishIdleClear() async {
//     if (!_isReady ||
//         _publisherClient?.connectionStatus?.state !=
//             MqttConnectionState.connected) {
//       print('⚠️ MQTT not ready – skip publishIdleClear');
//       return;
//     }
//
//     // 🔑 NEW — if the last thing published on this topic was already
//     // this exact idle-clear marker, skip republishing it. This is what
//     // prevents the ~15 duplicate IDLE publishes (fetchOrdersData,
//     // _getOrderTabs, showNextActiveOrder callback, etc. all firing
//     // near-simultaneously) that were flooding the broker and corrupting
//     // packet framing, which in turn dropped the CFD's connection right
//     // when the real CART state for a newly created order needed to
//     // arrive.
//     final stateTopic = '$_topicPrefix/state';
//     if (_lastPublishedFingerprint[stateTopic] == '__IDLE_CLEAR__') {
//       print('⏭️ [MQTT] Skipped duplicate publishIdleClear (already idle)');
//       return;
//     }
//     _lastPublishedFingerprint[stateTopic] = '__IDLE_CLEAR__';
//
//     _sequence++;
//     final store = await CfdStorePayload.load();
//
//     final data = <String, dynamic>{
//       'schemaVersion': 1,
//       'sequence': _sequence,
//       'screen': 'IDLE',
//       'items': <dynamic>[],
//       'orderId': null,
//       'summaryEnabled': false,
//       'storeId': store.storeId,
//       'storeName': store.storeName,
//       'storeLogoUrl': store.storeLogoUrl,
//       'storeBaseUrl': store.storeBaseUrl,
//       'slideshowUrls': store.slideshowUrls,
//     };
//
//     await _publishRaw('$_topicPrefix/state', jsonEncode(data), retain: true);
//
//     final cmd = jsonEncode({
//       'action': 'IDLE',
//       'sequence': _sequence,
//     });
//     await _publishRaw('$_topicPrefix/cmd', cmd, retain: true);
//
//     print('🧹 publishIdleClear seq=$_sequence (state + cmd)');
//   }
//
//   void listenToDisplayStatus(
//       void Function(Map<String, dynamic>) onStatus,
//       ) {
//     if (!_isReady) {
//       print('⚠️ MQTT not ready – cannot listen for CFD status');
//       return;
//     }
//
//     final client = _publisherClient;
//     if (client == null) return;
//
//     final statusTopic = '$_topicPrefix/status';
//     client.subscribe(statusTopic, MqttQos.atLeastOnce);
//     print('👂 Listening for CFD status on $statusTopic');
//
//     client.updates?.listen(
//           (events) {
//         for (final event in events) {
//           try {
//             final message = event.payload as MqttPublishMessage;
//             final rawBytes = message.payload.message;
//             final topic = message.variableHeader?.topicName ?? '';
//
//             print('📥 CFD status topic=$topic bytes=${rawBytes.length}');
//
//             final payload =
//             MqttPublishPayload.bytesToStringAsString(rawBytes);
//             print('📥 CFD status payload: $payload');
//
//             final decoded = jsonDecode(payload);
//             if (decoded is Map<String, dynamic>) {
//               onStatus(decoded);
//             } else {
//               print('⚠️ CFD status is not a JSON object');
//             }
//           } catch (e, st) {
//             print('❌ Bad CFD status payload: $e');
//             print(st);
//           }
//         }
//       },
//       onError: (error) {
//         print('❌ CFD MQTT status listener error: $error');
//       },
//     );
//   }
//
//   int _parseSequence(dynamic value) {
//     if (value is int) return value;
//     if (value is num) return value.toInt();
//     return int.tryParse(value?.toString() ?? '') ?? 0;
//   }
//
//   // ---------------------------------------------------------------------------
//   // DISPOSE
//   // ---------------------------------------------------------------------------
//
//   Future<void> dispose() async {
//     await stopMdnsAdvertisement();
//
//     try {
//       _publisherClient?.disconnect();
//     } catch (e) {
//       print('⚠️ MQTT publisher disconnect failed: $e');
//     }
//
//     try {
//       await _broker?.stop();
//     } catch (e) {
//       print('⚠️ MQTT broker stop failed: $e');
//     }
//
//     _publisherClient = null;
//     _broker = null;
//     _isReady = false;
//     print('🛑 StoreMessagingService disposed');
//   }
// }
//
//
// class CfdSequence {
//   static int _seq = 0;
//   static int next() => ++_seq;
// }


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:typed_data/typed_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_server/mqtt_server.dart';
import 'package:nsd/nsd.dart';

import 'cart_state.dart';
import 'cfd_store_payload.dart';

class StoreMessagingService {
  final String merchantId;
  final String storeId;
  final String terminalId;
  final String brokerUsername;
  final String brokerToken;

  MqttBroker? _broker;
  MqttServerClient? _publisherClient;

  int _sequence = 0;
  bool _isReady = false;

  Registration? _mdnsRegistration;

  // ---------------------------------------------------------------------------
  // MQTT PAYLOAD LIMITS (aggressively reduced)
  // ---------------------------------------------------------------------------
  static const int _maxSinglePublishBytes = 700;
  static const int _maxChunkPublishBytes = 700;
  static const int _initialChunkDataSize = 600;
  static const Duration _publishDelay = Duration(milliseconds: 30);

  final Map<String, int> _lastChunkCountByTopic = {};
  final Map<String, int> _lastSequenceByTopic = {};

  final Map<String, String> _lastPublishedFingerprint = {};

  Future<void> _publishQueue = Future.value();

  StoreMessagingService({
    required this.merchantId,
    required this.storeId,
    required this.terminalId,
    required this.brokerUsername,
    required this.brokerToken,
  });

  String get _topicPrefix => 'pinaka/$merchantId/$storeId/$terminalId/cfd';

  bool get isReady => _isReady;

  // ---------------------------------------------------------------------------
  // BROKER
  // ---------------------------------------------------------------------------

  // Future<void> startBroker() async {
  //   try {
  //     final config = MqttBrokerConfig(
  //       port: 1883,
  //       allowAnonymous: true,
  //     );
  //
  //     _broker = MqttBroker(config);
  //     _broker!.addCredentials(brokerUsername, brokerToken);
  //     await _broker!.start();
  //
  //     print('✅ MQTT Broker started on port 1883');
  //
  //     // Clear retained messages only once
  //     await _clearRetainedMessages();
  //
  //     await Future.delayed(const Duration(milliseconds: 1500));
  //     print('🔍 Broker warm-up delay complete');
  //   } catch (e, st) {
  //     print('❌ Failed to start MQTT broker: $e');
  //     print(st);
  //     rethrow;
  //   }
  // }
  Future<void> startBroker() async {
    try {
      final config = MqttBrokerConfig(
        port: 1883,
        allowAnonymous: true,
      );

      _broker = MqttBroker(config);
      _broker!.addCredentials(brokerUsername, brokerToken);
      await _broker!.start();

      print('✅ MQTT Broker started on port 1883');

      // _clearRetainedMessages() removed from here — it never ran anyway
      // since _publisherClient didn't exist yet. Now called from startPublisher().

      await Future.delayed(const Duration(milliseconds: 1500));
      print('🔍 Broker warm-up delay complete');
    } catch (e, st) {
      print('❌ Failed to start MQTT broker: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> _clearRetainedMessages() async {
    if (_publisherClient == null) return;
    final topics = [
      '$_topicPrefix/state',
      '$_topicPrefix/state/meta',
      '$_topicPrefix/cmd',
    ];
    for (final topic in topics) {
      try {
        final builder = MqttClientPayloadBuilder()..addString('');
        _publisherClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
          retain: true,
        );
        print('🧹 Cleared retained message on $topic');
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        print('⚠️ Failed to clear retained $topic: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // mDNS ADVERTISEMENT
  // ---------------------------------------------------------------------------

  Future<void> startMdnsAdvertisement() async {
    try {
      if (_mdnsRegistration != null) {
        await unregister(_mdnsRegistration!);
        _mdnsRegistration = null;
      }

      final txt = <String, Uint8List?>{
        'terminal': Uint8List.fromList(utf8.encode(terminalId)),
        'store': Uint8List.fromList(utf8.encode(storeId)),
        'merchant': Uint8List.fromList(utf8.encode(merchantId)),
      };

      _mdnsRegistration = await register(
        Service(
          name: 'PINAKA-$terminalId',
          type: '_pinaka-pos._tcp',
          port: 1883,
          txt: txt,
        ),
      );

      print(
        '📡 mDNS advertised: PINAKA-$terminalId '
            '(_pinaka-pos._tcp :1883) '
            'terminal=$terminalId store=$storeId merchant=$merchantId',
      );
    } catch (e, st) {
      print('❌ mDNS advertisement failed: $e');
      print(st);
    }
  }

  Future<void> stopMdnsAdvertisement() async {
    if (_mdnsRegistration == null) return;
    try {
      await unregister(_mdnsRegistration!);
      print('📡 mDNS unregistered');
    } catch (e) {
      print('⚠️ mDNS unregister failed: $e');
    }
    _mdnsRegistration = null;
  }

  // ---------------------------------------------------------------------------
  // LOCAL IP
  // ---------------------------------------------------------------------------

  Future<String?> getDeviceLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Names of virtual adapters that should NEVER be advertised —
      // Hyper-V / WSL / VPN clients often show up as 172.x.x.x or
      // 10.x.x.x and get picked first on Windows, which is why the
      // Android CFD couldn't reach the "LAN" IP that was printed.
      bool isVirtual(String name) {
        final n = name.toLowerCase();
        return n.contains('vethernet') ||
            n.contains('virtual') ||
            n.contains('hyper-v') ||
            n.contains('wsl') ||
            n.contains('vmware') ||
            n.contains('virtualbox') ||
            n.contains('loopback') ||
            n.contains('tap') ||
            n.contains('tun');
      }

      // Pass 1: real adapters only, common private ranges
      for (final interface in interfaces) {
        if (isVirtual(interface.name)) continue;
        for (final address in interface.addresses) {
          final ip = address.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            print('🌐 Selected LAN IP $ip from adapter "${interface.name}"');
            return ip;
          }
        }
      }

      // Pass 2: fallback, still skipping virtual adapters
      for (final interface in interfaces) {
        if (isVirtual(interface.name)) continue;
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            print('🌐 Fallback LAN IP ${address.address} from adapter "${interface.name}"');
            return address.address;
          }
        }
      }

      // Debug aid: log every adapter seen so a bad pick is easy to diagnose
      for (final interface in interfaces) {
        print('🔎 Adapter seen: ${interface.name} -> ${interface.addresses.map((a) => a.address).toList()}');
      }
    } catch (e) {
      print('❌ Failed to get local IP: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PUBLISHER
  // ---------------------------------------------------------------------------

  // Future<void> startPublisher() async {
  //   await Future.delayed(const Duration(milliseconds: 500));
  //
  //   final lanIp = await getDeviceLocalIp();
  //   final brokerIps = <String>[
  //     '127.0.0.1',
  //     if (lanIp != null && lanIp != '127.0.0.1') lanIp,
  //   ];
  //
  //   for (final brokerIp in brokerIps) {
  //     print('🔌 Trying MQTT broker: $brokerIp:1883');
  //
  //     final client = MqttServerClient.withPort(
  //       brokerIp,
  //       'POS-$terminalId-publisher',
  //       1883,
  //     );
  //
  //     client.setProtocolV311();
  //     client.logging(on: true);
  //     client.keepAlivePeriod = 20;
  //     client.connectTimeoutPeriod = 5000;
  //     client.autoReconnect = true;
  //     client.resubscribeOnAutoReconnect = true;
  //
  //     final connMessage = MqttConnectMessage()
  //         .withClientIdentifier('POS-$terminalId-publisher')
  //         .startClean();
  //
  //     client.connectionMessage = connMessage;
  //
  //     try {
  //       await client.connect();
  //
  //       if (client.connectionStatus?.state == MqttConnectionState.connected) {
  //         _publisherClient = client;
  //         _isReady = true;
  //         print('✅ POS publisher connected to $brokerIp:1883');
  //         return;
  //       }
  //
  //       print('❌ Broker $brokerIp rejected connection');
  //       client.disconnect();
  //     } catch (e) {
  //       print('❌ Failed to connect to $brokerIp:1883 — $e');
  //       try {
  //         client.disconnect();
  //       } catch (_) {}
  //     }
  //   }
  //
  //   _isReady = false;
  //   print('❌ POS publisher could not connect to any broker');
  //   throw Exception('MQTT publisher failed to connect to any broker host');
  // }
  Future<void> startPublisher() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final lanIp = await getDeviceLocalIp();
    final brokerIps = <String>[
      '127.0.0.1',
      if (lanIp != null && lanIp != '127.0.0.1') lanIp,
    ];

    for (final brokerIp in brokerIps) {
      print('🔌 Trying MQTT broker: $brokerIp:1883');

      final client = MqttServerClient.withPort(
        brokerIp,
        'POS-$terminalId-publisher',
        1883,
      );

      client.setProtocolV311();
      client.logging(on: false); // was: true — verbose logging isn't needed in production and adds overhead during bursts
      client.keepAlivePeriod = 20;
      client.connectTimeoutPeriod = 5000;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;

      // NEW: lifecycle hooks so a lost/desynced connection resets cleanly
      client.onDisconnected = () {
        print('⚠️ MQTT publisher disconnected');
        _isReady = false;
      };
      client.onConnected = () {
        print('✅ MQTT publisher (re)connected');
        _isReady = true;
      };
      client.onAutoReconnect = () {
        print('🔁 MQTT publisher auto-reconnecting — resetting fingerprint cache');
        _lastPublishedFingerprint.clear(); // avoid skipping a publish because of a stale fingerprint from before the drop
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('POS-$terminalId-publisher')
          .startClean();

      client.connectionMessage = connMessage;

      try {
        await client.connect();

        if (client.connectionStatus?.state == MqttConnectionState.connected) {
          _publisherClient = client;
          _isReady = true;
          print('✅ POS publisher connected to $brokerIp:1883');

          // MOVED HERE from startBroker(): _publisherClient now actually exists
          await _clearRetainedMessages();

          return;
        }

        print('❌ Broker $brokerIp rejected connection');
        client.disconnect();
      } catch (e) {
        print('❌ Failed to connect to $brokerIp:1883 — $e');
        try {
          client.disconnect();
        } catch (_) {}
      }
    }

    _isReady = false;
    print('❌ POS publisher could not connect to any broker');
    throw Exception('MQTT publisher failed to connect to any broker host');
  }

  // ---------------------------------------------------------------------------
  // UTF-8 HELPERS
  // ---------------------------------------------------------------------------

  List<int> _utf8Bytes(String value) => utf8.encode(value);

  // ---------------------------------------------------------------------------
  // SAFE CHUNK SPLITTING
  // ---------------------------------------------------------------------------

  List<String> _splitPayloadSafely(String payload) {
    final chunks = <String>[];
    var start = 0;

    while (start < payload.length) {
      var end = start + _initialChunkDataSize;
      if (end > payload.length) end = payload.length;

      String? acceptedPiece;
      while (end > start) {
        final piece = payload.substring(start, end);
        final bytes = utf8.encode(piece).length;
        if (bytes <= _maxChunkPublishBytes) {
          acceptedPiece = piece;
          break;
        }
        end -= 8;
        if (end < start) end = start;
      }

      if (acceptedPiece == null) {
        throw Exception('Unable to create safe MQTT chunk at position $start');
      }

      chunks.add(acceptedPiece);
      start += acceptedPiece.length;
    }

    // Merge a tiny trailing chunk back into the previous one if it still
    // fits, so we never publish a 1-4 char final chunk.
    if (chunks.length > 1 && utf8.encode(chunks.last).length < 10) {
      final tail = chunks.removeLast();
      final prev = chunks.removeLast();
      final merged = prev + tail;
      if (utf8.encode(merged).length <= _maxChunkPublishBytes) {
        chunks.add(merged);
      } else {
        chunks.add(prev);
        chunks.add(tail);
      }
    }

    return chunks;
  }
  // ---------------------------------------------------------------------------
  // PUBLISH RAW (QoS 0 for all state/chunk/meta)
  // ---------------------------------------------------------------------------

  Future<void> _publishRaw(
      String topic,
      String payload, {
        bool retain = false,
      }) async {
    if (_publisherClient == null) return;

    final bytes = utf8.encode(payload);
    final builder = MqttClientPayloadBuilder()
      ..addBuffer(Uint8Buffer()..addAll(bytes));

    _publisherClient!.publishMessage(
      topic,
      MqttQos.atMostOnce, // ⬅️ QoS 0 to reduce overhead
      builder.payload!,
      retain: retain,
    );

    print('📤 RAW MQTT publish topic=$topic bytes=${bytes.length}');
  }

  // ---------------------------------------------------------------------------
  // CLEAR HELPERS - DISABLED to avoid sending {} chunks
  // ---------------------------------------------------------------------------

  Future<void> _clearSequenceChunks(
      String baseTopic,
      int sequence,
      int maxIndex,
      ) async {
    // No-op: we don't need to clear; sequence numbers handle staleness.
    return;
  }

  Future<void> _clearStaleChunks(
      String baseTopic,
      int sequence,
      int newChunkCount,
      ) async {
    // No-op: clearing is not necessary.
    return;
  }

  // ---------------------------------------------------------------------------
  // FINGERPRINT HELPER
  // ---------------------------------------------------------------------------

  String _fingerprint(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data)..remove('sequence');
    final sortedKeys = copy.keys.toList()..sort();
    final sortedForHash = {for (final k in sortedKeys) k: copy[k]};
    return jsonEncode(sortedForHash);
  }

  // ---------------------------------------------------------------------------
  // INTERNAL PUBLISH
  // ---------------------------------------------------------------------------

  Future<void> _publishJsonInternal(
      String baseTopic,
      Map<String, dynamic> data,
      ) async {
    if (!_isReady ||
        _publisherClient?.connectionStatus?.state !=
            MqttConnectionState.connected) {
      print('⚠️ MQTT not ready – skip publish to $baseTopic');
      return;
    }

    final fingerprint = _fingerprint(data);

    final isEmptyCart = (data['items'] is List && (data['items'] as List).isEmpty) ||
        (data['totalItems'] == 0);

    if (!isEmptyCart &&
        _lastPublishedFingerprint[baseTopic] == fingerprint) {
      print('⏭️ [MQTT] Skipped duplicate publish to $baseTopic');
      return;
    }
    _lastPublishedFingerprint[baseTopic] = fingerprint;

    final payload = jsonEncode(data);
    final payloadBytes = _utf8Bytes(payload);
    final sequence = _parseSequence(data['sequence']);

    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📦 [MQTT] Preparing payload');
    print('📦 [MQTT] Topic: $baseTopic');
    print('📦 [MQTT] Sequence: $sequence');
    print('📦 [MQTT] JSON bytes: ${payloadBytes.length}');
    print('📦 [MQTT] JSON chars: ${payload.length}');
    print('📦 [MQTT] JSON: $payload');

    // SMALL PAYLOAD → direct publish (unchanged, kept for compatibility)
    if (payloadBytes.length <= _maxSinglePublishBytes) {
      try {
        await _publishRaw(baseTopic, payload, retain: false);
        print('✅ [MQTT] Direct publish complete');

        // NEW: also mirror through the meta+chunk protocol as a single chunk.
        // This is the actual fix for "empty cart never shows on the display" —
        // small payloads (like an empty cart) were skipping the meta/chunk
        // topics entirely, and the receiver only rebuilds its screen from
        // those topics. Without this, the receiver never learns a new
        // sequence exists when the cart is small.
        final metaPayload = jsonEncode({
          'sequence': sequence,
          'chunkCount': 1,
          'version': 2,
        });
        print('📤 [MQTT] META (single-chunk mirror): $metaPayload');
        await _publishRaw('$baseTopic/meta', metaPayload, retain: false);
        await _publishRaw('$baseTopic/chunk/$sequence/0', payload, retain: false);
        print('✅ [MQTT] Single-chunk mirror publish complete');
      } catch (e, st) {
        print(' [MQTT] Direct publish failed: $e');
        print(st);
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    // CHUNKED PAYLOAD
    final chunks = _splitPayloadSafely(payload);

    print('📦 [MQTT] Payload requires chunking');
    print('📦 [MQTT] Total bytes: ${payloadBytes.length}');
    print('📦 [MQTT] Chunk count: ${chunks.length}');

    // META (retain: false)
    final metaPayload = jsonEncode({
      'sequence': sequence,
      'chunkCount': chunks.length,
      'version': 2,
    });

    print('📤 [MQTT] META: $metaPayload');
    await _publishRaw('$baseTopic/meta', metaPayload, retain: false);

    // CHUNKS (retain: false, with delay)
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkBytes = _utf8Bytes(chunk);

      if (chunkBytes.length > _maxChunkPublishBytes) {
        throw Exception(
          'MQTT chunk $i exceeds $_maxChunkPublishBytes bytes',
        );
      }

      final topic = '$baseTopic/chunk/$sequence/$i';

      print('📤 [MQTT] CHUNK $i/${chunks.length - 1}');
      print('📤 [MQTT] Chunk topic: $topic');
      print('📤 [MQTT] Chunk bytes: ${chunkBytes.length}');

      await _publishRaw(topic, chunk, retain: false);
      await Future.delayed(const Duration(milliseconds: 180)); // ⬅️ increased delay
    }

    // No clear needed
    print('✅ [MQTT] Chunked publish complete');
    print('📦 [MQTT] Original bytes: ${payloadBytes.length}');
    print('📦 [MQTT] Chunks: ${chunks.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ---------------------------------------------------------------------------
  // SERIALIZED PUBLISH QUEUE
  // ---------------------------------------------------------------------------

  Future<void> _publishJson(
      String baseTopic,
      Map<String, dynamic> data,
      ) {
    final next = _publishQueue.then(
          (_) => _publishJsonInternal(baseTopic, data),
    );

    _publishQueue = next.catchError((Object error, StackTrace stack) {
      print('❌ [MQTT] Publish queue error: $error');
      print(stack);
    });

    return next;
  }

  // ---------------------------------------------------------------------------
  // BRANDING HELPER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _withStoreBranding(
      Map<String, dynamic> data,
      ) async {
    try {
      final store = await CfdStorePayload.load();
      return {
        ...data,
        'storeId': store.storeId,
        'storeName': store.storeName,
        'storeLogoUrl': store.storeLogoUrl,
        'storeBaseUrl': store.storeBaseUrl,
        'slideshowUrls': store.slideshowUrls,
      };
    } catch (e, st) {
      print('⚠️ CFD branding load failed – publishing without store fields: $e');
      print(st);
      return data;
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  Future<void> publishState(CartState state) async {
    if (state.sequence > _sequence) {
      _sequence = state.sequence;
    } else {
      _sequence++;
    }

    final data = <String, dynamic>{
      ...state.toJson(),
      'sequence': _sequence,
      'screen': state.screen,
    };

    final withBranding = await _withStoreBranding(data);

    if (state.screen != 'IDLE') {
      _lastPublishedFingerprint.remove('$_topicPrefix/state');
    }

    print(
      '🛒 Publishing cart state sequence=$_sequence '
          'screen=${withBranding['screen']} store=${withBranding['storeName']}',
    );

    await _publishJson('$_topicPrefix/state', withBranding);
  }

  Future<void> publishScreen(
      String screen, {
        String? message,
        double? total,
      }) async {
    _sequence++;
    final data = <String, dynamic>{
      'schemaVersion': 1,
      'sequence': _sequence,
      'screen': screen,
      if (message != null) 'message': message,
      if (total != null) 'total': total,
      'items': <dynamic>[],
      'orderId': null,
      'summaryEnabled': false,
    };

    final withBranding = await _withStoreBranding(data);

    if (screen != 'IDLE') {
      _lastPublishedFingerprint.remove('$_topicPrefix/state');
    }

    print(
      '🖥️ Publishing screen sequence=$_sequence screen=$screen '
          'store=${withBranding['storeName']}',
    );

    await _publishJson('$_topicPrefix/state', withBranding);
  }

  // Future<void> publishIdleClear() async {
  //   if (!_isReady ||
  //       _publisherClient?.connectionStatus?.state !=
  //           MqttConnectionState.connected) {
  //     print('⚠️ MQTT not ready – skip publishIdleClear');
  //     return;
  //   }
  //
  //   final stateTopic = '$_topicPrefix/state';
  //   if (_lastPublishedFingerprint[stateTopic] == '__IDLE_CLEAR__') {
  //     print('⏭️ [MQTT] Skipped duplicate publishIdleClear (already idle)');
  //     return;
  //   }
  //   _lastPublishedFingerprint[stateTopic] = '__IDLE_CLEAR__';
  //
  //   _sequence++;
  //   final store = await CfdStorePayload.load();
  //
  //   final data = <String, dynamic>{
  //     'schemaVersion': 1,
  //     'sequence': _sequence,
  //     'screen': 'IDLE',
  //     'items': <dynamic>[],
  //     'orderId': null,
  //     'summaryEnabled': false,
  //     'storeId': store.storeId,
  //     'storeName': store.storeName,
  //     'storeLogoUrl': store.storeLogoUrl,
  //     'storeBaseUrl': store.storeBaseUrl,
  //     'slideshowUrls': store.slideshowUrls,
  //   };
  //
  //   await _publishRaw('$_topicPrefix/state', jsonEncode(data), retain: true);
  //
  //   final cmd = jsonEncode({
  //     'action': 'IDLE',
  //     'sequence': _sequence,
  //   });
  //   await _publishRaw('$_topicPrefix/cmd', cmd, retain: true);
  //
  //   print('🧹 publishIdleClear seq=$_sequence (state + cmd)');
  // }

  Future<void> publishIdleClear() async {
    if (!_isReady ||
        _publisherClient?.connectionStatus?.state !=
            MqttConnectionState.connected) {
      print('⚠️ MQTT not ready – skip publishIdleClear');
      return;
    }

    final stateTopic = '$_topicPrefix/state';
    if (_lastPublishedFingerprint[stateTopic] == '__IDLE_CLEAR__') {
      print('⏭️ [MQTT] Skipped duplicate publishIdleClear (already idle)');
      return;
    }
    _lastPublishedFingerprint[stateTopic] = '__IDLE_CLEAR__';

    _sequence++;
    final store = await CfdStorePayload.load();

    final data = <String, dynamic>{
      'schemaVersion': 1,
      'sequence': _sequence,
      'screen': 'IDLE',
      'items': <dynamic>[],
      'orderId': null,
      'summaryEnabled': false,
      'storeId': store.storeId,
      'storeName': store.storeName,
      'storeLogoUrl': store.storeLogoUrl,
      'storeBaseUrl': store.storeBaseUrl,
      'slideshowUrls': store.slideshowUrls,
    };

    // CHANGED: wait for the queue instead of firing immediately,
    // so this can't land ahead of/inside an in-flight chunked publish.
    await _publishQueue;
    await _publishRaw('$_topicPrefix/state', jsonEncode(data), retain: true);

    final cmd = jsonEncode({
      'action': 'IDLE',
      'sequence': _sequence,
    });
    await _publishRaw('$_topicPrefix/cmd', cmd, retain: true);

    print('🧹 publishIdleClear seq=$_sequence (state + cmd)');
  }

  // Add this method to StoreMessagingService
  Future<void> publishEmptyCart(String orderId) async {
    if (!_isReady) return;

    _sequence++;
    final store = await CfdStorePayload.load();

    final data = <String, dynamic>{
      'schemaVersion': 1,
      'sequence': _sequence,
      'screen': 'CART',
      'items': <dynamic>[],
      'orderId': orderId,
      'summaryEnabled': false,
      'subtotal': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'total': 0.0,
      'netTotal': 0.0,
      'merchantDiscount': 0.0,
      'cashbackFee': 0.0,
      'redeemedAmount': 0.0,
      'orderDate': DateTime.now().toIso8601String().split('T').first,
      'orderTime': DateTime.now().toIso8601String().split('T').last.substring(0, 8),
      'storeId': store.storeId,
      'storeName': store.storeName,
      'storeLogoUrl': store.storeLogoUrl,
      'storeBaseUrl': store.storeBaseUrl,
      'slideshowUrls': store.slideshowUrls,
    };

    // CHANGED: run through the same serialized queue as every other publish,
    // instead of calling _publishJsonInternal directly (which could race
    // ahead of an in-flight chunked publish for a bigger cart).
    await _publishJson('$_topicPrefix/state', data);
    print('🧹 Published empty cart for order $orderId');
  }

  void listenToDisplayStatus(
      void Function(Map<String, dynamic>) onStatus,
      ) {
    if (!_isReady) {
      print('⚠️ MQTT not ready – cannot listen for CFD status');
      return;
    }

    final client = _publisherClient;
    if (client == null) return;

    final statusTopic = '$_topicPrefix/status';
    client.subscribe(statusTopic, MqttQos.atLeastOnce);
    print('👂 Listening for CFD status on $statusTopic');

    client.updates?.listen(
          (events) {
        for (final event in events) {
          try {
            final message = event.payload as MqttPublishMessage;
            final rawBytes = message.payload.message;
            final topic = message.variableHeader?.topicName ?? '';

            print('📥 CFD status topic=$topic bytes=${rawBytes.length}');

            final payload =
            MqttPublishPayload.bytesToStringAsString(rawBytes);
            print('📥 CFD status payload: $payload');

            final decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) {
              onStatus(decoded);
            } else {
              print('⚠️ CFD status is not a JSON object');
            }
          } catch (e, st) {
            print('❌ Bad CFD status payload: $e');
            print(st);
          }
        }
      },
      onError: (error) {
        print('❌ CFD MQTT status listener error: $error');
      },
    );
  }

  int _parseSequence(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await stopMdnsAdvertisement();

    try {
      _publisherClient?.disconnect();
    } catch (e) {
      print('⚠️ MQTT publisher disconnect failed: $e');
    }

    try {
      await _broker?.stop();
    } catch (e) {
      print('⚠️ MQTT broker stop failed: $e');
    }

    _publisherClient = null;
    _broker = null;
    _isReady = false;
    print('🛑 StoreMessagingService disposed');
  }
}

class CfdSequence {
  static int _seq = 0;
  static int next() => ++_seq;
}