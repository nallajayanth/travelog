import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  static Future<bool> isOnline() async {
    final conn = await Connectivity().checkConnectivity();
    return !conn.contains(ConnectivityResult.none);
  }
  
  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged;
  }
}