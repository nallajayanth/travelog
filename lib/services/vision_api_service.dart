import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VisionApiService {
  static const String _apiKey = 'AIzaSyDRI_aEJaT6ZNZrCW_GHKXo-Ydn5XKCyr8';
  
  static Future<List<String>> getImageTags(List<File> images) async {
    if (images.isEmpty) {
      print('No images provided for tagging');
      return [];
    }

    final url = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey',
    );

    List<Map<String, dynamic>> requests = [];
    for (var image in images) {
      try {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        requests.add({
          "image": {"content": base64},
          "features": [
            {"type": "LABEL_DETECTION", "maxResults": 5},
          ],
        });
      } catch (e) {
        print('Error reading image file ${image.path}: $e');
      }
    }

    if (requests.isEmpty) {
      print('No valid images for tagging');
      return [];
    }

    final body = jsonEncode({"requests": requests});

    try {
      final response = await http.post(
        url,
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      print('Vision API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Set<String> tags = {};
        for (var res in data['responses']) {
          if (res.containsKey('labelAnnotations')) {
            for (var label in res['labelAnnotations']) {
              tags.add(label['description'].toLowerCase());
            }
          }
        }
        final result = tags.toList().take(5).toList();
        print('Generated tags: $result');
        return result;
      } else {
        print('Vision API error: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error calling Vision API: $e');
      return [];
    }
  }
}