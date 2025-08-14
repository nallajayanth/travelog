import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:travlog_app/screens/add%20entry/add_entry_screen.dart';
import 'package:intl/intl.dart';

class EntryDetailScreen extends ConsumerWidget {
  final int index;
  const EntryDetailScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesNotifierProvider);
    if (index < 0 || index >= entries.length) {
      return const Scaffold(body: Center(child: Text('Entry not found')));
    }
    final entry = entries[index];
    final photos = (entry['photos'] != null)
        ? List<String>.from(entry['photos'])
        : <String>[];
    final localPhotos = (entry['local_photos'] != null)
        ? List<String>.from(entry['local_photos'])
        : <String>[];
    final tags = List<String>.from(entry['tags'] ?? []);
    final DateTime dateTime = DateTime.parse(entry['date_time']);
    String onlyDate = DateFormat('yyyy-MM-dd').format(dateTime);

    // Auto-slide controller
    late PageController pageController;
    if (photos.isNotEmpty || localPhotos.isNotEmpty) {
      pageController = PageController(viewportFraction: 0.9);
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (pageController.hasClients) {
          int nextPage = pageController.page!.round() + 1;
          if (nextPage <
              (photos.isNotEmpty ? photos.length : localPhotos.length)) {
            pageController.animateToPage(
              nextPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          } else {
            pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          }
        }
      });
    }

    Future<void> _confirmAndDeleteEntry() async {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await ref.read(entriesNotifierProvider.notifier).deleteEntryAt(index);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Travel Journal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            fontFamily: 'Roboto',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AddEntryScreen(entry: entry, index: index),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _confirmAndDeleteEntry,
          ),
        ],
        elevation: 6,
        shadowColor: Colors.black26,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty || localPhotos.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: photos.isNotEmpty
                      ? photos.length
                      : localPhotos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 8.0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Hero(
                          tag: 'entry_image_$index',
                          child: photos.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photos[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.broken_image, size: 64),
                                )
                              : Image.file(
                                  File(localPhotos[index]),
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.photo, size: 80, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontStyle: FontStyle.italic,
                      fontFamily: "Roboto",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color.fromARGB(255, 137, 224, 230),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${onlyDate ?? 'Unknown date'}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 20),
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Color(0xFF7F8C8D),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entry['address'] ?? 'Unknown location'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Generated Tags',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        Color color;
                        switch (tag.toLowerCase()) {
                          case 'nature':
                            color = Colors.green;
                            break;
                          case 'hiking':
                            color = Colors.blue;
                            break;
                          case 'adventure':
                            color = Colors.orange;
                            break;
                          case 'photography':
                            color = Colors.purple;
                            break;
                          default:
                            color = const Color.fromARGB(0, 247, 245, 246);
                        }
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                            ),
                          ),
                          backgroundColor: color.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    entry['description'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddEntryScreen(entry: entry, index: index),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),

                      ElevatedButton.icon(
                        onPressed: _confirmAndDeleteEntry,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFE74C3C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Center(
                  //   child: ElevatedButton.icon(
                  //     onPressed: () {
                  //       Navigator.of(context).push(
                  //         MaterialPageRoute(
                  //           builder: (context) =>
                  //               AddEntryScreen(entry: entry, index: index),
                  //         ),
                  //       );
                  //     },
                  //     icon: const Icon(Icons.edit, size: 18),
                  //     label: const Text('Edit Entry'),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Color(0xFF3498DB),
                  //       foregroundColor: Colors.white,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(25),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(
                  //         horizontal: 20,
                  //         vertical: 12,
                  //       ),
                  //       minimumSize: const Size(250, 50),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
