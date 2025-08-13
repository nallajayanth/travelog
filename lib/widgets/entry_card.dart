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
    final photos = (entry['photos'] != null)
        ? List<String>.from(entry['photos'])
        : <String>[];
    final localPhotos = (entry['local_photos'] != null)
        ? List<String>.from(entry['local_photos'])
        : <String>[];
    final dateStr = (entry['date_time'] != null)
        ? entry['date_time'].toString().split('T').first
        : '';
    final tags = List<String>.from(entry['tags'] ?? []);

    Widget imageWidget;
    if (photos.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: photos.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
      );
    } else if (localPhotos.isNotEmpty) {
      imageWidget = Image.file(
        File(localPhotos.first),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
      );
    } else {
      imageWidget = Center(
        child: Icon(
          Icons.photo,
          size: 64,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      );
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 180, width: double.infinity, child: imageWidget),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : 'Untitled',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  desc.isNotEmpty ? desc : 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Text(
                  dateStr.isNotEmpty ? dateStr : 'No date',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Address: ${entry['address'] ?? 'Unknown location'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      entry['synced'] == true
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: entry['synced'] == true
                          ? Colors.green
                          : Colors.redAccent,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
