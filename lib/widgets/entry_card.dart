

// widgets/entry_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const EntryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final title = entry['title'] ?? '';
    final desc = entry['description'] ?? '';
    final photos = (entry['photos'] != null) ? List<String>.from(entry['photos']) : <String>[];
    final localPhotos = (entry['local_photos'] != null) ? List<String>.from(entry['local_photos']) : <String>[];
    final dateStr = (entry['date_time'] != null) ? entry['date_time'].toString().split('T').first : '';

    Widget imageWidget;
    if (photos.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: photos.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey[300]),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
      );
    } else if (localPhotos.isNotEmpty) {
      imageWidget = Image.file(
        File(localPhotos.first),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
      );
    } else {
      imageWidget = const Center(child: Icon(Icons.photo, size: 64, color: Colors.grey));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: imageWidget,
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(dateStr, style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  if (entry['synced'] == true)
                    const Icon(Icons.cloud_done, color: Colors.green, size: 18)
                  else
                    const Icon(Icons.cloud_off, color: Colors.redAccent, size: 18)
                ],
              ),
            ]),
          )
        ],
      ),
    );
  }
}