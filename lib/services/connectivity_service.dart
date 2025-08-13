
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _conn = Connectivity();

  Future<bool> isOnline() async {
    final results = await _conn.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}