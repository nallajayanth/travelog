

// services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:async';

class ConnectivityService {
  final Connectivity _conn = Connectivity();

  Future<bool> isOnline() async {
    final results = await _conn.checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (!connected) {
      return false;
    }
    try {
      final lookupResult = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}