
// screens/add_entry/entry_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travlog_app/provider/entries_provider.dart';

class EntryDetailScreen extends ConsumerWidget {
  final int index;
  const EntryDetailScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesNotifierProvider);
    if (index < 0 || index >= entries.length) {
      return const Scaffold(body: Center(child: Text('Not found')));
    }
    final entry = entries[index];
    final photos = (entry['photos'] != null)
        ? List<String>.from(entry['photos'])
        : <String>[];
    final localPhotos = (entry['local_photos'] != null)
        ? List<String>.from(entry['local_photos'])
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(entry['title'] ?? 'Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await ref
                  .read(entriesNotifierProvider.notifier)
                  .deleteEntryAt(index);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (photos.isNotEmpty)
              SizedBox(
                height: 260,
                child: PageView(
                  children: photos
                      .map(
                        (p) =>
                            CachedNetworkImage(imageUrl: p, fit: BoxFit.cover),
                      )
                      .toList(),
                ),
              )
            else if (localPhotos.isNotEmpty)
              SizedBox(
                height: 260,
                child: PageView(
                  children: localPhotos
                      .map((p) => Image.file(File(p), fit: BoxFit.cover))
                      .toList(),
                ),
              )
            else
              Container(
                height: 260,
                color: Colors.grey[100],
                child: const Center(child: Icon(Icons.photo, size: 64)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry['description'] ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 6),
                      Text(
                        '${entry['latitude'] ?? '-'}, ${entry['longitude'] ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Synced: ${entry['synced'] == true ? "Yes" : "No"}'),
                  const SizedBox(height: 12),
                  if (entry['tags'] != null && entry['tags'].isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: List<String>.from(entry['tags']).map((tag) => Chip(label: Text(tag))).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}