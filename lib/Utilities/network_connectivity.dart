import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkConnectivity {
  NetworkConnectivity._();
  static final _instance = NetworkConnectivity._();
  static NetworkConnectivity get instance => _instance;
  final _networkConnectivity = Connectivity();
  final _controller = StreamController.broadcast();
  Stream get myStream => _controller.stream;
  // 1.
  Future<bool> initialise() async {
    ConnectivityResult result = await _networkConnectivity.checkConnectivity();
    bool isOnline = await checkStatus(result);
    _networkConnectivity.onConnectivityChanged.listen((result) async {
      if (kDebugMode) {
        print(result);
      }
      isOnline = await checkStatus(result);
    });
    return isOnline;
  }
// 2.
  Future<bool> checkStatus(ConnectivityResult result) async {
    bool isOnline = false;
    try {
      final result = await InternetAddress.lookup('example.com');
      isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      isOnline = false;
    }
    _controller.sink.add({result: isOnline});
    return isOnline;
  }
  // 3.
  Future<bool> isConnectivityOnline() async {
    ConnectivityResult result = await Connectivity().checkConnectivity();
    switch(result){
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.mobile:
        return true;
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.none:
      default:
        return false;
    }
  }
  void disposeStream() => _controller.close();
}