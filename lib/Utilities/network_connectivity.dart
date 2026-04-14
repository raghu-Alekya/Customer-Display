import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

ConnectivityResult _primaryConnectivity(List<ConnectivityResult> results) {
  if (results.isEmpty) return ConnectivityResult.none;
  final active = results.where((r) => r != ConnectivityResult.none);
  if (active.isEmpty) return ConnectivityResult.none;
  return active.first;
}

class NetworkConnectivity {
  NetworkConnectivity._();
  static final _instance = NetworkConnectivity._();
  static NetworkConnectivity get instance => _instance;
  final _networkConnectivity = Connectivity();
  final _controller = StreamController.broadcast();
  Stream get myStream => _controller.stream;
  // 1.
  Future<bool> initialise() async {
    final results = await _networkConnectivity.checkConnectivity();
    bool isOnline = await checkStatus(results);
    _networkConnectivity.onConnectivityChanged.listen((results) async {
      if (kDebugMode) {
        print(results);
      }
      isOnline = await checkStatus(results);
    });
    return isOnline;
  }
// 2.
  Future<bool> checkStatus(List<ConnectivityResult> connectivityResults) async {
    bool isOnline = false;
    try {
      final addresses = await InternetAddress.lookup('example.com');
      isOnline =
          addresses.isNotEmpty && addresses[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      isOnline = false;
    }
    final key = _primaryConnectivity(connectivityResults);
    _controller.sink.add({key: isOnline});
    return isOnline;
  }
  // 3.
  Future<bool> isConnectivityOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any(
          (r) =>
      r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.mobile,
    );
  }
  void disposeStream() => _controller.close();
}