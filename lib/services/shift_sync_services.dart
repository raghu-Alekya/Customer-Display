// In lib/Services/shift_sync_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../Repositories/Auth/shift_repository.dart';

class ShiftSyncService {
  static final ShiftSyncService _instance = ShiftSyncService._internal();
  factory ShiftSyncService() => _instance;
  ShiftSyncService._internal();

  final ShiftRepository _repository = ShiftRepository();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  bool _isSyncing = false;

  void startListening() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasNet = _hasInternet(results);
      if (hasNet) {
        triggerSync();
      }
    });
  }

  bool _hasInternet(dynamic results) {
    if (results is List) {
      if (results.isEmpty) return false;
      return !results.every((r) => r == ConnectivityResult.none);
    }
    return results != ConnectivityResult.none;
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      if (kDebugMode) print('🌐 [ShiftSyncService] Internet connected. Triggering sync...');
      await _repository.syncPendingShifts();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ShiftSyncService] Sync retry will occur on next reconnect: $e');
    } finally {
      _isSyncing = false;    }
  }

  void stopListening() {
    _subscription?.cancel();
  }
}