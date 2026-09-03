// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
//
// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:nsd/nsd.dart';
//
// import '../models/display_state.dart';
//
// class MqttCustomerDisplayService {
//   static const String _mdnsServiceType = '_pinaka-pos._tcp';
//
//   final int brokerPort;
//   final String displayId;
//   final String username;
//   final String token;
//   final String? brokerHost;
//   final String? terminalId;
//   final String? merchantId;
//   final String? storeId;
//   final String? topicPrefix;
//
//   MqttServerClient? _client;
//
//   String? _activeBrokerHost;
//   int? _activeBrokerPort;
//
//   String? _discoveredMerchantId;
//   String? _discoveredStoreId;
//   String? _discoveredTerminalId;
//
//   Discovery? _discovery;
//
//   int _lastSequenceSeen = -1;
//
//   Timer? _heartbeatTimer;
//
//   final _stateController = StreamController<DisplayState>.broadcast();
//
//   Stream<DisplayState> get stateStream => _stateController.stream;
//
//   // Store the most recent state for quick access
//   DisplayState? _latestState;
//
//   // ---------------------------------------------------------------------------
//   // CHUNK STATE
//   // ---------------------------------------------------------------------------
//
//   final Map<int, int> _expectedChunkCount = {};
//   final Map<int, Map<int, String>> _chunkBuffers = {};
//
//   StreamSubscription? _updatesSubscription;
//
//   bool _isDisposed = false;
//
//   // ---------------------------------------------------------------------------
//   // CONSTRUCTOR
//   // ---------------------------------------------------------------------------
//
//   MqttCustomerDisplayService({
//     required this.brokerPort,
//     required this.displayId,
//     required this.username,
//     required this.token,
//     this.brokerHost,
//     this.terminalId,
//     this.merchantId,
//     this.storeId,
//     this.topicPrefix,
//   });
//
//   // ---------------------------------------------------------------------------
//   // GETTERS
//   // ---------------------------------------------------------------------------
//
//   String? get activeBrokerHost => _activeBrokerHost;
//   int? get activeBrokerPort => _activeBrokerPort;
//   String? get discoveredMerchantId => _discoveredMerchantId;
//   String? get discoveredStoreId => _discoveredStoreId;
//   String? get discoveredTerminalId => _discoveredTerminalId;
//
//   String? get activeTopicPrefix {
//     if (topicPrefix != null && topicPrefix!.isNotEmpty) {
//       return topicPrefix;
//     }
//
//     if (_discoveredMerchantId == null ||
//         _discoveredStoreId == null ||
//         _discoveredTerminalId == null) {
//       return null;
//     }
//
//     return 'pinaka/'
//         '$_discoveredMerchantId/'
//         '$_discoveredStoreId/'
//         '$_discoveredTerminalId/'
//         'cfd';
//   }
//
//   // ---------------------------------------------------------------------------
//   // CONNECT
//   // ---------------------------------------------------------------------------
//
//   Future<bool> connect() async {
//     if (_isDisposed) {
//       print('❌ CFD service already disposed');
//       return false;
//     }
//
//     if (brokerHost != null && brokerHost!.trim().isNotEmpty) {
//       print(
//         '🔌 CFD using configured broker $brokerHost:$brokerPort',
//       );
//       return _connectDirect(brokerHost!.trim(), brokerPort);
//     }
//
//     print('🔍 CFD searching for POS via mDNS $_mdnsServiceType...');
//
//     final service = await _discoverPosService();
//     if (service == null) {
//       print('❌ CFD could not find POS');
//       return false;
//     }
//
//     return _connectToDiscoveredService(service);
//   }
//
//   // ---------------------------------------------------------------------------
//   // DIRECT CONNECTION
//   // ---------------------------------------------------------------------------
//
//   Future<bool> _connectDirect(String host, int port) async {
//     if (_isDisposed) return false;
//
//     final topic = activeTopicPrefix;
//     if (topic == null || topic.isEmpty) {
//       print('❌ CFD MQTT topic is not configured');
//       return false;
//     }
//
//     _activeBrokerHost = host;
//     _activeBrokerPort = port;
//
//     final client = MqttServerClient(host, displayId);
//     client.port = port;
//     client.keepAlivePeriod = 15;
//     client.connectTimeoutPeriod = 5000;
//     client.setProtocolV311();
//     client.logging(on: true);
//     client.autoReconnect = true;
//     client.resubscribeOnAutoReconnect = true;
//
//     client.onAutoReconnect = () {
//       print('🔄 CFD reconnecting to $host:$port');
//     };
//
//     client.onConnected = () {
//       _activeBrokerHost = host;
//       _activeBrokerPort = port;
//       _onConnected();
//     };
//
//     final connMessage = MqttConnectMessage()
//         .withClientIdentifier(displayId)
//         .authenticateAs(username, token)
//         .withWillTopic('$topic/status')
//         .withWillMessage('offline')
//         .withWillQos(MqttQos.atLeastOnce)
//         .withWillRetain()
//         .startClean();
//
//     client.connectionMessage = connMessage;
//     _client = client;
//
//     try {
//       print('⏳ CFD connecting to MQTT $host:$port');
//       await client.connect();
//
//       if (client.connectionStatus?.state == MqttConnectionState.connected) {
//         print('✅ CFD connected successfully to $host:$port');
//         return true;
//       }
//
//       client.disconnect();
//     } catch (e, st) {
//       print('❌ CFD connection failed: $e');
//       print(st);
//       try {
//         client.disconnect();
//       } catch (_) {}
//     }
//
//     _client = null;
//     _activeBrokerHost = null;
//     _activeBrokerPort = null;
//     return false;
//   }
//
//   // ---------------------------------------------------------------------------
//   // mDNS DISCOVERY
//   // ---------------------------------------------------------------------------
//
//   Future<Service?> _discoverPosService() async {
//     Discovery? discovery;
//
//     try {
//       discovery = await startDiscovery(
//         _mdnsServiceType,
//         autoResolve: true,
//         ipLookupType: IpLookupType.any,
//       );
//       _discovery = discovery;
//
//       print('📡 CFD mDNS discovery started: $_mdnsServiceType');
//
//       final completer = Completer<Service>();
//       late Timer timer;
//
//       discovery.addServiceListener((service, status) {
//         if (status != ServiceStatus.found) return;
//
//         print(
//           '🔎 CFD found mDNS service: '
//               'name=${service.name}, host=${service.host}, port=${service.port}',
//         );
//
//         if (_serviceMatches(service) && !completer.isCompleted) {
//           completer.complete(service);
//         }
//       });
//
//       timer = Timer(const Duration(seconds: 8), () {
//         if (!completer.isCompleted) {
//           completer.completeError(
//             TimeoutException('mDNS discovery timeout'),
//           );
//         }
//       });
//
//       try {
//         final service = await completer.future;
//         timer.cancel();
//         return service;
//       } catch (e) {
//         timer.cancel();
//         print('❌ mDNS discovery failed: $e');
//         return null;
//       }
//     } catch (e, st) {
//       print('❌ Failed to start mDNS: $e');
//       print(st);
//       return null;
//     } finally {
//       if (discovery != null) {
//         try {
//           await stopDiscovery(discovery);
//         } catch (_) {}
//         if (identical(_discovery, discovery)) {
//           _discovery = null;
//         }
//       }
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // SERVICE MATCH
//   // ---------------------------------------------------------------------------
//
//   bool _serviceMatches(Service service) {
//     final terminal = _readTxt(service.txt, 'terminal');
//     final store = _readTxt(service.txt, 'store');
//     final merchant = _readTxt(service.txt, 'merchant');
//
//     print(
//       '📋 CFD mDNS TXT: terminal=$terminal store=$store merchant=$merchant',
//     );
//
//     if (merchantId != null && merchant != null && merchant != merchantId) {
//       return false;
//     }
//     if (storeId != null && store != null && store != storeId) {
//       return false;
//     }
//     if (terminalId != null) {
//       if (terminal != null) return terminal == terminalId;
//       return service.name == 'PINAKA-$terminalId';
//     }
//     return true;
//   }
//
//   // ---------------------------------------------------------------------------
//   // READ TXT
//   // ---------------------------------------------------------------------------
//
//   String? _readTxt(Map<String, Uint8List?>? txt, String key) {
//     if (txt == null) return null;
//     final value = txt[key];
//     if (value == null) return null;
//     return utf8.decode(value, allowMalformed: true);
//   }
//
//   // ---------------------------------------------------------------------------
//   // DISCOVERED CONNECTION
//   // ---------------------------------------------------------------------------
//
//   Future<bool> _connectToDiscoveredService(Service service) async {
//     final host = service.host;
//     if (host == null || host.isEmpty) return false;
//
//     final port = service.port ?? brokerPort;
//
//     _activeBrokerHost = host;
//     _activeBrokerPort = port;
//     _discoveredTerminalId = _readTxt(service.txt, 'terminal');
//     _discoveredStoreId = _readTxt(service.txt, 'store');
//     _discoveredMerchantId = _readTxt(service.txt, 'merchant');
//
//     final topic = activeTopicPrefix;
//     if (topic == null) {
//       print('❌ CFD cannot determine topic');
//       return false;
//     }
//
//     print('🔌 CFD connecting to discovered POS $host:$port');
//     print('📡 CFD topic: $topic');
//
//     final client = MqttServerClient(host, displayId);
//     client.port = port;
//     client.keepAlivePeriod = 15;
//     client.connectTimeoutPeriod = 5000;
//     client.setProtocolV311();
//     client.logging(on: true);
//     client.autoReconnect = true;
//     client.resubscribeOnAutoReconnect = true;
//
//     client.onAutoReconnect = () {
//       print('🔄 CFD reconnecting...');
//     };
//
//     client.onConnected = () {
//       _activeBrokerHost = host;
//       _activeBrokerPort = port;
//       _onConnected();
//     };
//
//     final connMessage = MqttConnectMessage()
//         .withClientIdentifier(displayId)
//         .authenticateAs(username, token)
//         .withWillTopic('$topic/status')
//         .withWillMessage('offline')
//         .withWillQos(MqttQos.atLeastOnce)
//         .withWillRetain()
//         .startClean();
//
//     client.connectionMessage = connMessage;
//     _client = client;
//
//     try {
//       await client.connect();
//
//       if (client.connectionStatus?.state == MqttConnectionState.connected) {
//         print('✅ CFD connected successfully to $host:$port');
//         return true;
//       }
//
//       client.disconnect();
//     } catch (e, st) {
//       print('❌ CFD connection failed: $e');
//       print(st);
//       try {
//         client.disconnect();
//       } catch (_) {}
//     }
//
//     _client = null;
//     return false;
//   }
//
//   // ---------------------------------------------------------------------------
//   // CONNECTED
//   // ---------------------------------------------------------------------------
//
//   void _onConnected() {
//     final client = _client;
//     final topic = activeTopicPrefix;
//     if (client == null || topic == null) return;
//
//     print(
//       '✅ CFD connected to $_activeBrokerHost:$_activeBrokerPort',
//     );
//
//     client.subscribe('$topic/state', MqttQos.atLeastOnce);
//     client.subscribe('$topic/state/meta', MqttQos.atLeastOnce);
//     client.subscribe('$topic/state/chunk/#', MqttQos.atLeastOnce);
//     client.subscribe('$topic/cmd', MqttQos.atLeastOnce);
//
//     print(
//       '📡 CFD subscribed to $topic/state (+meta, +chunk/#, +cmd)',
//     );
//
//     _updatesSubscription?.cancel();
//
//     final updates = client.updates;
//     if (updates == null) {
//       print('❌ CFD updates stream is null');
//       return;
//     }
//
//     _updatesSubscription = updates.listen(
//           (events) {
//         for (final event in events) {
//           _processMqttEvent(event);
//         }
//       },
//       onError: (error, stack) {
//         print('❌ CFD MQTT updates error: $error');
//         print(stack);
//       },
//       cancelOnError: false,
//     );
//
//     _publishOnlineStatus();
//
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(
//       const Duration(seconds: 20),
//           (_) => _publishOnlineStatus(),
//     );
//   }
//
//   // ---------------------------------------------------------------------------
//   // MQTT EVENT
//   // ---------------------------------------------------------------------------
//
//   void _processMqttEvent(MqttReceivedMessage<MqttMessage> event) {
//     try {
//       final message = event.payload as MqttPublishMessage;
//       final topic = message.variableHeader?.topicName ?? '';
//       final bytes = message.payload.message;
//       final payload =
//       MqttPublishPayload.bytesToStringAsString(bytes);
//
//       print('📥 CFD MQTT topic=$topic bytes=${bytes.length}');
//
//       final currentTopic = activeTopicPrefix;
//       if (currentTopic == null) return;
//
//       final stateTopic = '$currentTopic/state';
//       final metaTopic = '$currentTopic/state/meta';
//       final chunkPrefix = '$currentTopic/state/chunk/';
//       final cmdTopic = '$currentTopic/cmd';
//
//       // ── CMD: only force IDLE if we don't have an active order ──
//       if (topic == cmdTopic) {
//         print('📥 CFD CMD payload=$payload');
//         try {
//           final map = jsonDecode(payload);
//           if (map is Map &&
//               (map['action']?.toString().toUpperCase() == 'IDLE')) {
//             // If we already have an active order (non-empty orderId),
//             // ignore this IDLE command to keep the cart visible.
//             final currentOrderId = _latestState?.orderId ?? '';
//             if (currentOrderId.isNotEmpty && currentOrderId != '0') {
//               print('⏭️ CFD ignored IDLE cmd – active order present');
//               return;
//             }
//             print('🧹 CFD CMD → force IDLE/Welcome (no active order)');
//             final seq = map['sequence'] ??
//                 DateTime.now().millisecondsSinceEpoch;
//             _handleIncoming(jsonEncode({
//               'sequence': seq,
//               'screen': 'IDLE',
//               'items': <dynamic>[],
//               'orderId': null,
//               'summaryEnabled': false,
//             }));
//           }
//         } catch (e) {
//           print('⚠️ CFD cmd parse error: $e');
//         }
//         return;
//       }
//
//       // ── Full state ────────────────────────────────────────────────
//       if (topic == stateTopic) {
//         print('📥 CFD FULL STATE: $payload');
//         _handleIncoming(payload);
//         return;
//       }
//
//       // ── Meta ──────────────────────────────────────────────────────
//       if (topic == metaTopic) {
//         _handleMeta(payload);
//         return;
//       }
//
//       // ── Chunks ────────────────────────────────────────────────────
//       if (topic.startsWith(chunkPrefix)) {
//         _handleChunk(payload, topic: topic);
//         return;
//       }
//     } catch (e, st) {
//       print('❌ CFD MQTT event error: $e');
//       print(st);
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // META
//   // ---------------------------------------------------------------------------
//
//   void _handleMeta(String payload) {
//     if (payload.trim().isEmpty) return;
//     try {
//       final decoded = jsonDecode(payload);
//       if (decoded is! Map<String, dynamic>) throw const FormatException('META is not an object');
//
//       final actualSequence = _parseInt(decoded['s']) ?? _parseInt(decoded['sequence']);
//       final actualCount = _parseInt(decoded['n']) ?? _parseInt(decoded['chunkCount']);
//
//       if (actualSequence == null || actualCount == null || actualCount <= 0) {
//         throw const FormatException('Invalid META values');
//       }
//
//       _expectedChunkCount[actualSequence] = actualCount;
//
//       // Drop any older, still-incomplete sequences — a lost chunk shouldn't
//       // permanently wedge reassembly once a newer state has started arriving.
//       final stale = _expectedChunkCount.keys.where((s) => s < actualSequence).toList();
//       for (final oldSeq in stale) {
//         _chunkBuffers.remove(oldSeq);
//         _expectedChunkCount.remove(oldSeq);
//       }
//
//       print('📋 CFD META seq=$actualSequence chunks=$actualCount');
//       _tryAssemble(actualSequence);
//     } catch (e) {
//       print('❌ CFD invalid META: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // CHUNK
//   // ---------------------------------------------------------------------------
//
//   void _handleChunk(String payload, {required String topic}) {
//     if (payload.isEmpty) {
//       print('⚠️ CFD empty chunk ignored topic=$topic');
//       return;
//     }
//
//     try {
//       final parts = topic.split('/');
//       final chunkPos = parts.lastIndexWhere((p) => p == 'chunk');
//
//       if (chunkPos < 0 || chunkPos + 2 >= parts.length) {
//         print('⚠️ CFD bad chunk topic: $topic');
//         return;
//       }
//
//       final sequence = int.tryParse(parts[chunkPos + 1]);
//       final index = int.tryParse(parts[chunkPos + 2]);
//
//       if (sequence == null || index == null || index < 0) {
//         print('⚠️ CFD bad chunk seq/index on $topic');
//         return;
//       }
//
//       final trimmed = payload.trim();
//
//       if (trimmed.startsWith('{')) {
//         try {
//           final decoded = jsonDecode(payload);
//           if (decoded is Map<String, dynamic>) {
//             final encodedData = decoded['d'];
//             if (encodedData is String) {
//               final bytes = base64Decode(encodedData);
//               final data = utf8.decode(bytes, allowMalformed: false);
//               _storeChunk(sequence, index, data);
//               return;
//             }
//
//             final oldData = decoded['data'];
//             if (oldData is String) {
//               print(
//                 '⚠️ CFD legacy chunk format seq=$sequence index=$index',
//               );
//               _storeChunk(sequence, index, oldData);
//               return;
//             }
//           }
//         } catch (_) {
//           // Not a wrapper — treat as raw fragment below
//         }
//       }
//
//       _storeChunk(sequence, index, payload);
//     } catch (e) {
//       print('⚠️ CFD chunk error topic=$topic error=$e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // STORE CHUNK
//   // ---------------------------------------------------------------------------
//
//   void _storeChunk(int sequence, int index, String data) {
//     if (data.isEmpty) {
//       print('⚠️ CFD empty chunk ignored seq=$sequence index=$index');
//       return;
//     }
//
//     // Publisher no longer sends legacy "{}" clear-chunks (see
//     // _clearSequenceChunks/_clearStaleChunks, both no-ops now), so a short
//     // trailing fragment is a legitimate part of a real payload (e.g. the
//     // tail "]}" of an empty-cart JSON) — do NOT drop it based on length.
//     _chunkBuffers.putIfAbsent(sequence, () => <int, String>{});
//     _chunkBuffers[sequence]![index] = data;
//
//     final received = _chunkBuffers[sequence]!.length;
//     final expected = _expectedChunkCount[sequence];
//
//     final preview = data.length > 60 ? '${data.substring(0, 60)}…' : data;
//     print(
//       '🧩 CFD CHUNK seq=$sequence index=$index $received/${expected ?? "?"} '
//           'len=${data.length} >>>$preview<<<',
//     );
//
//     _tryAssemble(sequence);
//   }
//
//   // ---------------------------------------------------------------------------
//   // JSON REPAIR
//   // ---------------------------------------------------------------------------
//
//   String _repairJson(String raw) {
//     var s = raw.trim();
//
//     if (!s.endsWith('}')) {
//       s = '$s}';
//     }
//
//     s = s.replaceAllMapped(
//       RegExp(r'"(\w+):"'),
//           (m) => '"${m[1]}":"',
//     );
//
//     s = s.replaceAllMapped(
//       RegExp(r'"(\w+)"(\d+\.?\d*)'),
//           (m) => '"${m[1]}":${m[2]}',
//     );
//
//     s = s.replaceAllMapped(
//       RegExp(r',(\w+)":'),
//           (m) => ',"${m[1]}":',
//     );
//
//     s = s.replaceAllMapped(
//       RegExp(r'"(\w+)""'),
//           (m) => '"${m[1]}":"',
//     );
//
//     s = s.replaceAll('"iscount"', '"discount"');
//     s = s.replaceAll('"ubtotal"', '"subtotal"');
//     s = s.replaceAll('"etTotal"', '"netTotal"');
//     s = s.replaceAll('"rossTotal"', '"grossTotal"');
//
//     return s;
//   }
//
//   // ---------------------------------------------------------------------------
//   // ASSEMBLE
//   // ---------------------------------------------------------------------------
//
//   void _tryAssemble(int sequence) {
//     final expected = _expectedChunkCount[sequence];
//     final buffer = _chunkBuffers[sequence];
//
//     if (expected == null || buffer == null || expected <= 0) return;
//     if (buffer.length < expected) return;
//
//     final builder = StringBuffer();
//     for (var i = 0; i < expected; i++) {
//       final chunk = buffer[i];
//       if (chunk == null) {
//         print('⏳ Missing chunk seq=$sequence index=$i');
//         return;
//       }
//       builder.write(chunk);
//     }
//
//     final completePayload = builder.toString();
//
//     print(
//       '🧩 CFD REASSEMBLED seq=$sequence '
//           'chunks=$expected chars=${completePayload.length}',
//     );
//
//     String toParse = completePayload;
//
//     try {
//       final decoded = jsonDecode(toParse);
//       if (decoded is! Map<String, dynamic>) {
//         throw const FormatException('Reassembled state is not an object');
//       }
//     } catch (e) {
//       final repaired = _repairJson(completePayload);
//       try {
//         final decoded = jsonDecode(repaired);
//         if (decoded is! Map<String, dynamic>) {
//           throw const FormatException('Repaired state is not an object');
//         }
//         print('🛠️ CFD JSON repaired successfully for seq=$sequence');
//         toParse = repaired;
//       } catch (e2) {
//         print(
//           '⚠️ CFD skipped bad reassembly seq=$sequence '
//               '(${completePayload.length} chars) – waiting for next state',
//         );
//         return;
//       }
//     }
//
//     _handleIncoming(toParse);
//
//     _expectedChunkCount.remove(sequence);
//     _chunkBuffers.remove(sequence);
//
//     final stale = _chunkBuffers.keys
//         .where((value) => value < sequence - 1)
//         .toList();
//     for (final oldSequence in stale) {
//       _chunkBuffers.remove(oldSequence);
//       _expectedChunkCount.remove(oldSequence);
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // COMPLETE STATE
//   // ---------------------------------------------------------------------------
//
//   void _handleIncoming(String payload) {
//     if (payload.trim().isEmpty) return;
//     if (!payload.trim().endsWith('}')) {
//       print('⚠️ CFD skipped incomplete state (${payload.length}B)');
//       return;
//     }
//
//     try {
//       final decoded = jsonDecode(payload);
//       if (decoded is! Map<String, dynamic>) return;
//
//       final sequence = _parseInt(decoded['sequence']) ?? 0;
//       final screenUpper =
//       (decoded['screen'] ?? '').toString().toUpperCase().trim();
//       final isIdle =
//           screenUpper == 'IDLE' || screenUpper == 'WELCOME';
//
//       if (!isIdle) {
//         if (sequence < _lastSequenceSeen) {
//           print(
//             '⏭️ CFD ignored old seq=$sequence last=$_lastSequenceSeen',
//           );
//           return;
//         }
//         if (sequence == _lastSequenceSeen) {
//           print('🔁 CFD duplicate seq=$sequence');
//           return;
//         }
//       }
//
//       final state = DisplayState.fromJson(decoded);
//       _lastSequenceSeen = sequence;
//       _latestState = state; // Store the latest state
//
//       if (!_stateController.isClosed) {
//         _stateController.add(state);
//       }
//
//       print(
//         '⚡ CFD state applied seq=$sequence screen=${state.screen} '
//             'items=${state.items.length}',
//       );
//     } catch (e, st) {
//       print('❌ CFD invalid MQTT message: $e');
//       print(st);
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // ONLINE STATUS
//   // ---------------------------------------------------------------------------
//
//   void _publishOnlineStatus() {
//     final client = _client;
//     final topic = activeTopicPrefix;
//
//     if (client == null ||
//         topic == null ||
//         client.connectionStatus?.state != MqttConnectionState.connected) {
//       return;
//     }
//
//     final payload = jsonEncode({
//       'displayId': displayId,
//       'status': 'online',
//       'appVersion': '1.2.0',
//       'broker': _activeBrokerHost,
//       'port': _activeBrokerPort,
//       'merchant': _discoveredMerchantId,
//       'store': _discoveredStoreId,
//       'terminal': _discoveredTerminalId,
//     });
//
//     final builder = MqttClientPayloadBuilder()..addString(payload);
//     client.publishMessage(
//       '$topic/status',
//       MqttQos.atLeastOnce,
//       builder.payload!,
//       retain: true,
//     );
//
//     print('💓 CFD online status published');
//   }
//
//   // ---------------------------------------------------------------------------
//   // PARSE INT
//   // ---------------------------------------------------------------------------
//
//   int? _parseInt(dynamic value) {
//     if (value is int) return value;
//     if (value is num) return value.toInt();
//     return int.tryParse(value?.toString() ?? '');
//   }
//
//   // ---------------------------------------------------------------------------
//   // DISCONNECT
//   // ---------------------------------------------------------------------------
//
//   void disconnect() {
//     print('🛑 CFD disconnect requested');
//
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = null;
//
//     _updatesSubscription?.cancel();
//     _updatesSubscription = null;
//
//     try {
//       _client?.disconnect();
//     } catch (e) {
//       print('⚠️ CFD disconnect failed: $e');
//     }
//
//     _client = null;
//   }
//
//   // ---------------------------------------------------------------------------
//   // DISPOSE
//   // ---------------------------------------------------------------------------
//
//   void dispose() {
//     if (_isDisposed) return;
//     _isDisposed = true;
//
//     disconnect();
//
//     _expectedChunkCount.clear();
//     _chunkBuffers.clear();
//
//     final discovery = _discovery;
//     if (discovery != null) {
//       stopDiscovery(discovery).catchError((_) {});
//       _discovery = null;
//     }
//
//     _stateController.close();
//   }
// }


////======


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:nsd/nsd.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/display_state.dart';

class MqttCustomerDisplayService {
  static const String _mdnsServiceType = '_pinaka-pos._tcp';

  final int brokerPort;
  final String displayId;
  final String username;
  final String token;
  final String? brokerHost;
  final String? terminalId;
  final String? merchantId;
  final String? storeId;
  final String? topicPrefix;

  MqttServerClient? _client;

  String? _activeBrokerHost;
  int? _activeBrokerPort;

  String? _discoveredMerchantId;
  String? _discoveredStoreId;
  String? _discoveredTerminalId;

  Discovery? _discovery;

  int _lastSequenceSeen = -1;

  Timer? _heartbeatTimer;

  final _stateController = StreamController<DisplayState>.broadcast();

  Stream<DisplayState> get stateStream => _stateController.stream;

  DisplayState? _latestState;

  final Map<int, int> _expectedChunkCount = {};
  final Map<int, Map<int, String>> _chunkBuffers = {};

  StreamSubscription? _updatesSubscription;

  bool _isDisposed = false;

  MqttCustomerDisplayService({
    required this.brokerPort,
    required this.displayId,
    required this.username,
    required this.token,
    this.brokerHost,
    this.terminalId,
    this.merchantId,
    this.storeId,
    this.topicPrefix,
  });

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  String? get activeBrokerHost => _activeBrokerHost;
  int? get activeBrokerPort => _activeBrokerPort;
  String? get discoveredMerchantId => _discoveredMerchantId;
  String? get discoveredStoreId => _discoveredStoreId;
  String? get discoveredTerminalId => _discoveredTerminalId;

  /// Topic order:
  /// 1. explicit [topicPrefix]
  /// 2. mDNS-discovered IDs
  /// 3. constructor IDs (QR / direct connect)
  String? get activeTopicPrefix {
    if (topicPrefix != null && topicPrefix!.isNotEmpty) {
      return topicPrefix;
    }

    final m = _discoveredMerchantId ?? merchantId;
    final s = _discoveredStoreId ?? storeId;
    final t = _discoveredTerminalId ?? terminalId;

    if (m == null || s == null || t == null) return null;
    return 'pinaka/$m/$s/$t/cfd';
  }

  // ---------------------------------------------------------------------------
  // CONNECT
  // ---------------------------------------------------------------------------

  // Future<bool> connect() async {
  //   if (_isDisposed) {
  //     print('❌ CFD service already disposed');
  //     return false;
  //   }
  //
  //   // Direct connect (QR scan path) — brokerHost is a concrete IP/hostname
  //   if (brokerHost != null && brokerHost!.trim().isNotEmpty) {
  //     print('🔌 CFD using configured broker $brokerHost:$brokerPort');
  //     return _connectDirect(brokerHost!.trim(), brokerPort);
  //   }
  //
  //   // Dynamic path — discover current POS via mDNS, prefer real IPv4
  //   print('🔍 CFD searching for POS via mDNS $_mdnsServiceType...');
  //   final service = await _discoverPosService();
  //   if (service == null) {
  //     print('❌ CFD could not find POS');
  //     return false;
  //   }
  //   return _connectToDiscoveredService(service);
  // }

  Future<bool> connect() async {
    if (_isDisposed) {
      print('❌ CFD service already disposed');
      return false;
    }

    // Direct connect (QR scan path) — brokerHost is a concrete IP/hostname
    if (brokerHost != null && brokerHost!.trim().isNotEmpty) {
      print('🔌 CFD using configured broker $brokerHost:$brokerPort');
      return _connectDirect(brokerHost!.trim(), brokerPort);
    }

    // Dynamic path — discover current POS via mDNS, prefer real IPv4
    print('🔍 CFD searching for POS via mDNS $_mdnsServiceType...');
    final service = await _discoverPosService();
    if (service == null) {
      print('❌ CFD could not find POS');
      return false;
    }
    return _connectToDiscoveredService(service);
  }


  // ---------------------------------------------------------------------------
  // HOST CANDIDATES (dynamic — prefer IPv4 over .local)
  // ---------------------------------------------------------------------------

  List<String> _candidateHosts(Service service) {
    final candidates = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null) return;
      final v = value.trim();
      if (v.isEmpty || !seen.add(v)) return;
      candidates.add(v);
    }

    // 1) Addresses from ipLookupType: IpLookupType.any
    try {
      final dynamic addrs = (service as dynamic).addresses;
      if (addrs is List) {
        // Prefer non-loopback IPv4 first
        for (final a in addrs) {
          if (a is InternetAddress) {
            if (a.type == InternetAddressType.IPv4 && !a.isLoopback) {
              add(a.address);
            }
          } else if (a != null) {
            final s = a.toString();
            if (_looksLikeIpv4(s) && s != '127.0.0.1') add(s);
          }
        }
        // Then allow loopback (same-machine Windows debug)
        if (candidates.isEmpty) {
          for (final a in addrs) {
            if (a is InternetAddress && a.type == InternetAddressType.IPv4) {
              add(a.address);
            } else if (a != null && _looksLikeIpv4(a.toString())) {
              add(a.toString());
            }
          }
        }
      }
    } catch (_) {
      // older nsd builds may not expose addresses
    }

    // 2) service.host if it is already an IPv4
    final host = service.host;
    if (host != null && _looksLikeIpv4(host)) {
      add(host);
    }

    // 3) Last resort: hostname (e.g. DESKTOP-xxx.local) — often fails on Windows
    if (host != null && host.isNotEmpty) {
      add(host);
    }

    return candidates;
  }

  bool _looksLikeIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // DIRECT CONNECTION
  // ---------------------------------------------------------------------------

  Future<bool> _connectDirect(String host, int port) async {
    if (_isDisposed) return false;

    // Seed discovered IDs from constructor so QR/direct path builds the topic
    _discoveredMerchantId ??= merchantId;
    _discoveredStoreId ??= storeId;
    _discoveredTerminalId ??= terminalId;

    final topic = activeTopicPrefix;
    if (topic == null || topic.isEmpty) {
      print('❌ CFD MQTT topic is not configured '
          '(merchant/store/terminal missing)');
      return false;
    }

    _activeBrokerHost = host;
    _activeBrokerPort = port;

    final client = MqttServerClient(host, displayId);
    client.port = port;
    client.keepAlivePeriod = 15;
    client.connectTimeoutPeriod = 5000;
    client.setProtocolV311();
    client.logging(on: true);
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.onAutoReconnect = () {
      print('🔄 CFD reconnecting to $host:$port');
    };

    client.onConnected = () {
      _activeBrokerHost = host;
      _activeBrokerPort = port;
      _onConnected();
    };

    client.onDisconnected = () {
      print('⚠️ CFD MQTT disconnected from $host:$port');
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(displayId)
        .authenticateAs(username, token)
        .withWillTopic('$topic/status')
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();

    client.connectionMessage = connMessage;
    _client = client;

    try {
      print('⏳ CFD connecting to MQTT $host:$port  topic=$topic');
      await client.connect();

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        print('✅ CFD connected successfully to $host:$port');
        return true;
      }

      print('❌ CFD broker rejected connection: '
          '${client.connectionStatus}');
      client.disconnect();
    } catch (e, st) {
      print('❌ CFD connection failed ($host:$port): $e');
      print(st);
      try {
        client.disconnect();
      } catch (_) {}
    }

    _client = null;
    _activeBrokerHost = null;
    _activeBrokerPort = null;
    return false;
  }

  // ---------------------------------------------------------------------------
  // mDNS DISCOVERY
  // ---------------------------------------------------------------------------

  Future<Service?> _discoverPosService() async {
    Discovery? discovery;

    try {
      discovery = await startDiscovery(
        _mdnsServiceType,
        autoResolve: true,
        ipLookupType: IpLookupType.any, // required for real IPv4 addresses
      );
      _discovery = discovery;

      print('📡 CFD mDNS discovery started: $_mdnsServiceType');

      final completer = Completer<Service>();
      late Timer timer;

      discovery.addServiceListener((service, status) {
        if (status != ServiceStatus.found) return;

        print(
          '🔎 CFD found mDNS service: '
              'name=${service.name}, host=${service.host}, port=${service.port}',
        );

        try {
          final dynamic addrs = (service as dynamic).addresses;
          print('🔎 CFD service addresses: $addrs');
        } catch (_) {}

        if (_serviceMatches(service) && !completer.isCompleted) {
          completer.complete(service);
        }
      });

      timer = Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('mDNS discovery timeout'),
          );
        }
      });

      try {
        final service = await completer.future;
        timer.cancel();
        return service;
      } catch (e) {
        timer.cancel();
        print('❌ mDNS discovery failed: $e');
        return null;
      }
    } catch (e, st) {
      print('❌ Failed to start mDNS: $e');
      print(st);
      return null;
    } finally {
      if (discovery != null) {
        try {
          await stopDiscovery(discovery);
        } catch (_) {}
        if (identical(_discovery, discovery)) {
          _discovery = null;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SERVICE MATCH
  // ---------------------------------------------------------------------------

  bool _serviceMatches(Service service) {
    final terminal = _readTxt(service.txt, 'terminal');
    final store = _readTxt(service.txt, 'store');
    final merchant = _readTxt(service.txt, 'merchant');

    print(
      '📋 CFD mDNS TXT: terminal=$terminal store=$store merchant=$merchant',
    );

    if (merchantId != null && merchant != null && merchant != merchantId) {
      return false;
    }
    if (storeId != null && store != null && store != storeId) {
      return false;
    }
    if (terminalId != null) {
      if (terminal != null) return terminal == terminalId;
      return service.name == 'PINAKA-$terminalId';
    }
    return true;
  }

  String? _readTxt(Map<String, Uint8List?>? txt, String key) {
    if (txt == null) return null;
    final value = txt[key];
    if (value == null) return null;
    return utf8.decode(value, allowMalformed: true);
  }

  // ---------------------------------------------------------------------------
  // DISCOVERED CONNECTION (dynamic host list)
  // ---------------------------------------------------------------------------

  Future<bool> _connectToDiscoveredService(Service service) async {
    final port = service.port ?? brokerPort;

    _discoveredTerminalId = _readTxt(service.txt, 'terminal');
    _discoveredStoreId = _readTxt(service.txt, 'store');
    _discoveredMerchantId = _readTxt(service.txt, 'merchant');

    final topic = activeTopicPrefix;
    if (topic == null) {
      print('❌ CFD cannot determine topic');
      return false;
    }

    final hosts = _candidateHosts(service);
    if (hosts.isEmpty) {
      print('❌ CFD discovered service has no usable host');
      return false;
    }

    print('🔌 CFD will try hosts in order: $hosts  port=$port  topic=$topic');

    for (final host in hosts) {
      print('🔌 CFD trying $host:$port …');
      final ok = await _connectDirect(host, port);
      if (ok) {
        print('✅ CFD connected via discovered service at $host:$port');
        return true;
      }
      print('❌ CFD failed at $host:$port — trying next candidate');
    }

    print('❌ CFD could not connect to any host for discovered POS');
    return false;
  }

  // ---------------------------------------------------------------------------
  // CONNECTED
  // ---------------------------------------------------------------------------

  void _onConnected() {
    final client = _client;
    final topic = activeTopicPrefix;
    if (client == null || topic == null) return;

    print('✅ CFD connected to $_activeBrokerHost:$_activeBrokerPort');

    client.subscribe('$topic/state', MqttQos.atLeastOnce);
    client.subscribe('$topic/state/meta', MqttQos.atLeastOnce);
    client.subscribe('$topic/state/chunk/#', MqttQos.atLeastOnce);
    client.subscribe('$topic/cmd', MqttQos.atLeastOnce);

    print('📡 CFD subscribed to $topic/state (+meta, +chunk/#, +cmd)');

    _updatesSubscription?.cancel();

    final updates = client.updates;
    if (updates == null) {
      print('❌ CFD updates stream is null');
      return;
    }

    _updatesSubscription = updates.listen(
          (events) {
        for (final event in events) {
          _processMqttEvent(event);
        }
      },
      onError: (error, stack) {
        print('❌ CFD MQTT updates error: $error');
        print(stack);
      },
      cancelOnError: false,
    );

    _publishOnlineStatus();

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _publishOnlineStatus(),
    );
  }

  // ---------------------------------------------------------------------------
  // MQTT EVENT
  // ---------------------------------------------------------------------------

  void _processMqttEvent(MqttReceivedMessage<MqttMessage> event) {
    try {
      final message = event.payload as MqttPublishMessage;
      final topic = message.variableHeader?.topicName ?? '';
      final bytes = message.payload.message;
      final payload = MqttPublishPayload.bytesToStringAsString(bytes);

      print('📥 CFD MQTT topic=$topic bytes=${bytes.length}');

      final currentTopic = activeTopicPrefix;
      if (currentTopic == null) return;

      final stateTopic = '$currentTopic/state';
      final metaTopic = '$currentTopic/state/meta';
      final chunkPrefix = '$currentTopic/state/chunk/';
      final cmdTopic = '$currentTopic/cmd';

      if (topic == cmdTopic) {
        print('📥 CFD CMD payload=$payload');
        try {
          final map = jsonDecode(payload);
          if (map is Map &&
              (map['action']?.toString().toUpperCase() == 'IDLE')) {
            final currentOrderId = _latestState?.orderId ?? '';
            if (currentOrderId.isNotEmpty && currentOrderId != '0') {
              print('⏭️ CFD ignored IDLE cmd – active order present');
              return;
            }
            print('🧹 CFD CMD → force IDLE/Welcome (no active order)');
            final seq = map['sequence'] ??
                DateTime.now().millisecondsSinceEpoch;
            _handleIncoming(jsonEncode({
              'sequence': seq,
              'screen': 'IDLE',
              'items': <dynamic>[],
              'orderId': null,
              'summaryEnabled': false,
            }));
          }
        } catch (e) {
          print('⚠️ CFD cmd parse error: $e');
        }
        return;
      }

      if (topic == stateTopic) {
        print('📥 CFD FULL STATE: $payload');
        _handleIncoming(payload);
        return;
      }

      if (topic == metaTopic) {
        _handleMeta(payload);
        return;
      }

      if (topic.startsWith(chunkPrefix)) {
        _handleChunk(payload, topic: topic);
        return;
      }
    } catch (e, st) {
      print('❌ CFD MQTT event error: $e');
      print(st);
    }
  }

  // ---------------------------------------------------------------------------
  // META
  // ---------------------------------------------------------------------------

  void _handleMeta(String payload) {
    if (payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('META is not an object');
      }

      final actualSequence =
          _parseInt(decoded['s']) ?? _parseInt(decoded['sequence']);
      final actualCount =
          _parseInt(decoded['n']) ?? _parseInt(decoded['chunkCount']);

      if (actualSequence == null || actualCount == null || actualCount <= 0) {
        throw const FormatException('Invalid META values');
      }

      _expectedChunkCount[actualSequence] = actualCount;

      final stale =
      _expectedChunkCount.keys.where((s) => s < actualSequence).toList();
      for (final oldSeq in stale) {
        _chunkBuffers.remove(oldSeq);
        _expectedChunkCount.remove(oldSeq);
      }

      print('📋 CFD META seq=$actualSequence chunks=$actualCount');
      _tryAssemble(actualSequence);
    } catch (e) {
      print('❌ CFD invalid META: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CHUNK
  // ---------------------------------------------------------------------------

  void _handleChunk(String payload, {required String topic}) {
    if (payload.isEmpty) {
      print('⚠️ CFD empty chunk ignored topic=$topic');
      return;
    }

    try {
      final parts = topic.split('/');
      final chunkPos = parts.lastIndexWhere((p) => p == 'chunk');

      if (chunkPos < 0 || chunkPos + 2 >= parts.length) {
        print('⚠️ CFD bad chunk topic: $topic');
        return;
      }

      final sequence = int.tryParse(parts[chunkPos + 1]);
      final index = int.tryParse(parts[chunkPos + 2]);

      if (sequence == null || index == null || index < 0) {
        print('⚠️ CFD bad chunk seq/index on $topic');
        return;
      }

      final trimmed = payload.trim();

      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final encodedData = decoded['d'];
            if (encodedData is String) {
              final bytes = base64Decode(encodedData);
              final data = utf8.decode(bytes, allowMalformed: false);
              _storeChunk(sequence, index, data);
              return;
            }

            final oldData = decoded['data'];
            if (oldData is String) {
              print(
                '⚠️ CFD legacy chunk format seq=$sequence index=$index',
              );
              _storeChunk(sequence, index, oldData);
              return;
            }
          }
        } catch (_) {}
      }

      _storeChunk(sequence, index, payload);
    } catch (e) {
      print('⚠️ CFD chunk error topic=$topic error=$e');
    }
  }

  void _storeChunk(int sequence, int index, String data) {
    if (data.isEmpty) {
      print('⚠️ CFD empty chunk ignored seq=$sequence index=$index');
      return;
    }

    _chunkBuffers.putIfAbsent(sequence, () => <int, String>{});
    _chunkBuffers[sequence]![index] = data;

    final received = _chunkBuffers[sequence]!.length;
    final expected = _expectedChunkCount[sequence];

    final preview = data.length > 60 ? '${data.substring(0, 60)}…' : data;
    print(
      '🧩 CFD CHUNK seq=$sequence index=$index $received/${expected ?? "?"} '
          'len=${data.length} >>>$preview<<<',
    );

    _tryAssemble(sequence);
  }

  // ---------------------------------------------------------------------------
  // JSON REPAIR
  // ---------------------------------------------------------------------------

  String _repairJson(String raw) {
    var s = raw.trim();

    if (!s.endsWith('}')) {
      s = '$s}';
    }

    s = s.replaceAllMapped(
      RegExp(r'"(\w+):"'),
          (m) => '"${m[1]}":"',
    );

    s = s.replaceAllMapped(
      RegExp(r'"(\w+)"(\d+\.?\d*)'),
          (m) => '"${m[1]}":${m[2]}',
    );

    s = s.replaceAllMapped(
      RegExp(r',(\w+)":'),
          (m) => ',"${m[1]}":',
    );

    s = s.replaceAllMapped(
      RegExp(r'"(\w+)""'),
          (m) => '"${m[1]}":"',
    );

    s = s.replaceAll('"iscount"', '"discount"');
    s = s.replaceAll('"ubtotal"', '"subtotal"');
    s = s.replaceAll('"etTotal"', '"netTotal"');
    s = s.replaceAll('"rossTotal"', '"grossTotal"');

    return s;
  }

  // ---------------------------------------------------------------------------
  // ASSEMBLE
  // ---------------------------------------------------------------------------

  void _tryAssemble(int sequence) {
    final expected = _expectedChunkCount[sequence];
    final buffer = _chunkBuffers[sequence];

    if (expected == null || buffer == null || expected <= 0) return;
    if (buffer.length < expected) return;

    final builder = StringBuffer();
    for (var i = 0; i < expected; i++) {
      final chunk = buffer[i];
      if (chunk == null) {
        print('⏳ Missing chunk seq=$sequence index=$i');
        return;
      }
      builder.write(chunk);
    }

    final completePayload = builder.toString();

    print(
      '🧩 CFD REASSEMBLED seq=$sequence '
          'chunks=$expected chars=${completePayload.length}',
    );

    String toParse = completePayload;

    try {
      final decoded = jsonDecode(toParse);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Reassembled state is not an object');
      }
    } catch (e) {
      final repaired = _repairJson(completePayload);
      try {
        final decoded = jsonDecode(repaired);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Repaired state is not an object');
        }
        print('🛠️ CFD JSON repaired successfully for seq=$sequence');
        toParse = repaired;
      } catch (e2) {
        print(
          '⚠️ CFD skipped bad reassembly seq=$sequence '
              '(${completePayload.length} chars) – waiting for next state',
        );
        return;
      }
    }

    _handleIncoming(toParse);

    _expectedChunkCount.remove(sequence);
    _chunkBuffers.remove(sequence);

    final stale =
    _chunkBuffers.keys.where((value) => value < sequence - 1).toList();
    for (final oldSequence in stale) {
      _chunkBuffers.remove(oldSequence);
      _expectedChunkCount.remove(oldSequence);
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETE STATE
  // ---------------------------------------------------------------------------

  void _handleIncoming(String payload) {
    if (payload.trim().isEmpty) return;
    if (!payload.trim().endsWith('}')) {
      print('⚠️ CFD skipped incomplete state (${payload.length}B)');
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;

      final sequence = _parseInt(decoded['sequence']) ?? 0;
      final screenUpper =
      (decoded['screen'] ?? '').toString().toUpperCase().trim();
      final isIdle =
          screenUpper == 'IDLE' || screenUpper == 'WELCOME';

      if (!isIdle) {
        if (sequence < _lastSequenceSeen) {
          print(
            '⏭️ CFD ignored old seq=$sequence last=$_lastSequenceSeen',
          );
          return;
        }
        if (sequence == _lastSequenceSeen) {
          print('🔁 CFD duplicate seq=$sequence');
          return;
        }
      }

      final state = DisplayState.fromJson(decoded);
      _lastSequenceSeen = sequence;
      _latestState = state;

      if (!_stateController.isClosed) {
        _stateController.add(state);
      }

      print(
        '⚡ CFD state applied seq=$sequence screen=${state.screen} '
            'items=${state.items.length}',
      );
    } catch (e, st) {
      print('❌ CFD invalid MQTT message: $e');
      print(st);
    }
  }

  // ---------------------------------------------------------------------------
  // ONLINE STATUS
  // ---------------------------------------------------------------------------

  void _publishOnlineStatus() {
    final client = _client;
    final topic = activeTopicPrefix;

    if (client == null ||
        topic == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    final payload = jsonEncode({
      'displayId': displayId,
      'status': 'online',
      'appVersion': '1.2.0',
      'broker': _activeBrokerHost,
      'port': _activeBrokerPort,
      'merchant': _discoveredMerchantId ?? merchantId,
      'store': _discoveredStoreId ?? storeId,
      'terminal': _discoveredTerminalId ?? terminalId,
    });

    final builder = MqttClientPayloadBuilder()..addString(payload);
    client.publishMessage(
      '$topic/status',
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );

    print('💓 CFD online status published');
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  // ---------------------------------------------------------------------------
  // DISCONNECT / DISPOSE
  // ---------------------------------------------------------------------------

  void disconnect() {
    print('🛑 CFD disconnect requested');

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _updatesSubscription?.cancel();
    _updatesSubscription = null;

    try {
      _client?.disconnect();
    } catch (e) {
      print('⚠️ CFD disconnect failed: $e');
    }

    _client = null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    disconnect();

    _expectedChunkCount.clear();
    _chunkBuffers.clear();

    final discovery = _discovery;
    if (discovery != null) {
      stopDiscovery(discovery).catchError((_) {});
      _discovery = null;
    }

    _stateController.close();
  }
}