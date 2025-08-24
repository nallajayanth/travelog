import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static Future<Directory> _getImagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/journal_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static Future<List<String>> copyImagesToPersistentStorage(
      List<File> images) async {
    if (images.isEmpty) return [];

    final imagesDir = await _getImagesDirectory();
    List<String> localPhotoPaths = [];

    for (var img in images) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${img.path.split('/').last}';
        final newPath = '${imagesDir.path}/$fileName';
        await img.copy(newPath);
        localPhotoPaths.add(newPath);
        print('Copied image to persistent path: $newPath');
      } catch (e) {
        print('Error copying image ${img.path}: $e');
      }
    }

    return localPhotoPaths;
  }

  static Future<void> deleteLocalPhotos(List<String> photoPaths) async {
    for (final photoPath in photoPaths) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
          print('Deleted local photo: $photoPath');
        }
      } catch (e) {
        print('Error deleting photo $photoPath: $e');
      }
    }
  }

  static Future<void> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        print('Deleted photo: $photoPath');
      }
    } catch (e) {
      print('Error deleting photo $photoPath: $e');
    }
  }
}