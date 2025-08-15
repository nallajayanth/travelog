

import 'dart:io';
import 'package:flutter/material.dart';

class PhotoGrid extends StatelessWidget {
  final List<String> photoPaths; // Accepts both local paths and remote URLs
  const PhotoGrid({super.key, required this.photoPaths});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photoPaths.map((path) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path.startsWith('http')
              ? Image.network(
                  path,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                )
              : Image.file(
                  File(path),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
        );
      }).toList(),
    );
  }
}