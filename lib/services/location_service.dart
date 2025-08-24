import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String> getAddressFromLatLong(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      Placemark place = placemarks.first;

      String address =
          "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}"
              .replaceAll(RegExp(r', , '), ', ')
              .replaceAll(RegExp(r', $'), '')
              .trim();
      
      if (address.isEmpty) {
        return "Unknown location";
      }
      return address;
    } catch (e) {
      print("Error getting address: $e");
      return "Unknown location";
    }
  }
}