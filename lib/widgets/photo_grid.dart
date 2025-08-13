

// widgets/photo_grid.dart (if used, e.g., in add_entry)
import 'dart:io';
import 'package:flutter/material.dart';

class PhotoGrid extends StatelessWidget {
  final List<String> localPaths;
  const PhotoGrid({super.key, required this.localPaths});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: localPaths
          .map(
            (p) =>
                Image.file(File(p), width: 100, height: 100, fit: BoxFit.cover),
          )
          .toList(),
    );
  }
}
