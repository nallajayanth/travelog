// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'dart:io';

// class EntryCard extends StatelessWidget {
//   final Map<String, dynamic> entry;
//   const EntryCard({super.key, required this.entry});

//   @override
//   Widget build(BuildContext context) {
//     final title = entry['title'] ?? '';
//     final desc = entry['description'] ?? '';
//     final photos = (entry['photos'] != null)
//         ? List<String>.from(entry['photos'])
//         : <String>[];
//     final localPhotos = (entry['local_photos'] != null)
//         ? List<String>.from(entry['local_photos'])
//         : <String>[];
//     final dateStr = (entry['date_time'] != null)
//         ? entry['date_time'].toString().split('T').first
//         : '';
//     final tags = List<String>.from(entry['tags'] ?? []);

//     Widget imageWidget;
//     if (photos.isNotEmpty) {
//       imageWidget = CachedNetworkImage(
//         imageUrl: photos.first,
//         fit: BoxFit.cover,
//         placeholder: (_, __) => Container(
//           color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
//         ),
//         errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
//       );
//     } else if (localPhotos.isNotEmpty) {
//       imageWidget = Image.file(
//         File(localPhotos.first),
//         fit: BoxFit.cover,
//         errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
//       );
//     } else {
//       imageWidget = Center(
//         child: Icon(
//           Icons.photo,
//           size: 64,
//           color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
//         ),
//       );
//     }

//     return Card(
//       elevation: 6,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       clipBehavior: Clip.hardEdge,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(height: 180, width: double.infinity, child: imageWidget),
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title.isNotEmpty ? title : 'Untitled',
//                   style: Theme.of(
//                     context,
//                   ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 6),
//                 Text(
//                   desc.isNotEmpty ? desc : 'No description',
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: Theme.of(context).textTheme.bodyMedium,
//                 ),
//                 const SizedBox(height: 8),
//                 if (tags.isNotEmpty)
//                   Wrap(
//                     spacing: 6,
//                     runSpacing: 6,
//                     children: tags
//                         .map(
//                           (tag) => Chip(
//                             label: Text(
//                               tag,
//                               style: const TextStyle(fontSize: 12),
//                             ),
//                             backgroundColor: Theme.of(
//                               context,
//                             ).colorScheme.primary.withOpacity(0.1),
//                             labelStyle: TextStyle(
//                               color: Theme.of(context).colorScheme.primary,
//                             ),
//                             side: BorderSide(
//                               color: Theme.of(
//                                 context,
//                               ).colorScheme.primary.withOpacity(0.3),
//                             ),
//                           ),
//                         )
//                         .toList(),
//                   ),
//                 const SizedBox(height: 8),
//                 Text(
//                   dateStr.isNotEmpty ? dateStr : 'No date',
//                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.onSurface.withOpacity(0.6),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.location_on,
//                       size: 14,
//                       color: Theme.of(
//                         context,
//                       ).colorScheme.onSurface.withOpacity(0.6),
//                     ),
//                     const SizedBox(width: 6),
//                     Expanded(
//                       child: Text(
//                         'Address: ${entry['address'] ?? 'Unknown location'}',
//                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Theme.of(
//                             context,
//                           ).colorScheme.onSurface.withOpacity(0.6),
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                         maxLines: 1,
//                       ),
//                     ),
//                     const Spacer(),
//                     Icon(
//                       entry['synced'] == true
//                           ? Icons.cloud_done
//                           : Icons.cloud_off,
//                       color: entry['synced'] == true
//                           ? Colors.green
//                           : Colors.redAccent,
//                       size: 18,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


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
    
    // Prioritize local photos first, then remote photos
    if (localPhotos.isNotEmpty) {
      imageWidget = Image.file(
        File(localPhotos.first),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // If local photo fails, try remote photo if available
          if (photos.isNotEmpty) {
            return CachedNetworkImage(
              imageUrl: photos.first,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
            );
          }
          return const Icon(Icons.broken_image, size: 64);
        },
      );
    } else if (photos.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: photos.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Text(
                  dateStr.isNotEmpty ? dateStr : 'No date',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry['address'] ?? 'Unknown location',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Smart sync status indicator
                    _buildSyncStatusIndicator(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusIndicator(BuildContext context) {
    final syncStatus = entry['sync_status'] ?? 'unknown';
    final needsSync = entry['needs_sync'] == true;

    IconData icon;
    Color color;
    String tooltip;

    switch (syncStatus) {
      case 'synced':
        if (needsSync) {
          // This shouldn't happen, but handle edge case
          icon = Icons.cloud_sync;
          color = Colors.orange;
          tooltip = 'Sync pending';
        } else {
          icon = Icons.cloud_done;
          color = const Color(0xFF27AE60); // Green - all good
          tooltip = 'Synced to cloud';
        }
        break;
      
      case 'pending':
        icon = Icons.cloud_upload;
        color = const Color(0xFFF39C12); // Orange - uploading
        tooltip = 'Uploading to cloud';
        break;
      
      case 'modified':
        icon = Icons.cloud_sync;
        color = const Color(0xFFE74C3C); // Red - has changes
        tooltip = 'Changes need to be synced';
        break;
      
      case 'error':
        icon = Icons.cloud_off;
        color = const Color(0xFFE74C3C); // Red - error
        tooltip = 'Sync failed';
        break;
      
      case 'delete_pending':
        icon = Icons.delete_sweep;
        color = const Color(0xFF95A5A6); // Gray - being deleted
        tooltip = 'Marked for deletion';
        break;
      
      default:
        // For entries that haven't been synced yet or unknown status
        if (entry['supabase_id'] == null) {
          // Never synced - local only
          icon = Icons.cloud_upload;
          color = const Color(0xFFF39C12); // Orange - needs first sync
          tooltip = 'Local only - needs sync';
        } else {
          // Unknown status but has supabase_id
          icon = Icons.cloud_outlined;
          color = const Color(0xFF95A5A6); // Gray - unknown
          tooltip = 'Unknown sync status';
        }
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _getSyncStatusText(syncStatus, needsSync),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSyncStatusText(String syncStatus, bool needsSync) {
    switch (syncStatus) {
      case 'synced':
        return needsSync ? 'Sync' : 'Synced';
      case 'pending':
        return 'Pending';
      case 'modified':
        return 'Modified';
      case 'error':
        return 'Error';
      case 'delete_pending':
        return 'Deleting';
      default:
        if (entry['supabase_id'] == null) {
          return 'Local';
        }
        return 'Unknown';
    }
  }
}