import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import '../services/supabase_service.dart';
import '../services/photo_service.dart';
import '../services/vision_api_service.dart';
import '../utils/connectivity_helper.dart';
import 'local_repository.dart';

class SyncRepository {
  final Ref ref;
  final LocalRepository localRepository;

  SyncRepository(this.ref, this.localRepository);

  Future<void> syncToSupabase() async {
    if (!await ConnectivityHelper.isOnline()) {
      print('Offline - skipping sync');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated - skipping sync');
      return;
    }

    print('Starting sync to Supabase');
    final supabaseService = ref.read(supabaseServiceProvider);
    final entriesToSync = localRepository.getEntriesNeedingSync();

    for (final entry in entriesToSync) {
      try {
        if (entry['sync_status'] == 'delete_pending') {
          await _handleDeletion(entry);
        } else {
          await _handleCreateOrUpdate(entry, supabaseService, userId);
        }
      } catch (e) {
        print('Sync error for entry ${entry['local_id']}: $e');
        await _markSyncError(entry);
      }
    }

    print('Sync to Supabase completed');
  }

  Future<void> _handleDeletion(Map<String, dynamic> entry) async {
    if (entry['supabase_id'] != null) {
      await Supabase.instance.client
          .from('journal_entries')
          .delete()
          .eq('id', entry['supabase_id']);
      print('Deleted entry from Supabase: ${entry['supabase_id']}');
    }

    if (entry['local_id'] != null) {
      await localRepository.deleteEntry(entry['local_id']);
    }
  }

  Future<void> _handleCreateOrUpdate(
    Map<String, dynamic> entry,
    SupabaseService supabaseService,
    String userId,
  ) async {
    // Upload local photos
    final localPhotos =
        (entry['local_photos'] as List<dynamic>?)?.cast<String>() ?? [];
    final uploadedUrls = <String>[
      ...(entry['photos'] as List<dynamic>?)?.cast<String>() ?? [],
    ];
    final files = <File>[];

    for (final photoPath in localPhotos) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          files.add(file);
          final url = await supabaseService.uploadPhoto(file);
          uploadedUrls.add(url);
          print('Photo uploaded: $url');
        }
      } catch (e) {
        print('Error uploading photo $photoPath: $e');
      }
    }

    // Generate tags if there are new local photos
    List<String> tags =
        (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    if (files.isNotEmpty) {
      try {
        final newTags = await VisionApiService.getImageTags(files);
        final tagSet = tags.toSet()..addAll(newTags);
        tags = tagSet.toList();
      } catch (e) {
        print('Failed to generate tags during sync: $e');
      }
    }

    // Prepare payload for Supabase
    final payload = {
      'user_id': userId,
      'title': entry['title'] ?? '',
      'description': entry['description'] ?? '',
      'photos': uploadedUrls,
      'latitude': entry['latitude'] ?? 0.0,
      'longitude': entry['longitude'] ?? 0.0,
      'address': entry['address'] ?? 'Unknown location',
      'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
      'tags': tags,
    };

    Map<String, dynamic>? result;

    if (entry['supabase_id'] != null && entry['sync_status'] == 'modified') {
      result = await Supabase.instance.client
          .from('journal_entries')
          .update(payload)
          .eq('id', entry['supabase_id'])
          .select()
          .maybeSingle();
      print('Updated entry in Supabase: ${entry['supabase_id']}');
    } else {
      result = await supabaseService.insertEntry(payload);
      print('Inserted new entry to Supabase');
    }

    if (result != null) {
      // Delete local photo files after successful upload
      await PhotoService.deleteLocalPhotos(localPhotos);

      // Update local entry with sync info
      final syncedEntry = {
        ...entry,
        'supabase_id': result['id'],
        'photos': uploadedUrls,
        'local_photos': <String>[],
        'all_photos': uploadedUrls,
        'tags': tags,
        'needs_sync': false,
        'sync_status': 'synced',
        'last_sync_attempt': DateTime.now().toIso8601String(),
      };

      await localRepository.updateEntry(syncedEntry);
      print('Updated local entry after successful sync');
    }
  }

  Future<void> _markSyncError(Map<String, dynamic> entry) async {
    final updatedEntry = {
      ...entry,
      'sync_status': 'error',
      'last_sync_attempt': DateTime.now().toIso8601String(),
    };
    await localRepository.updateEntry(updatedEntry);
  }

  Future<void> fetchFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated, cannot fetch from Supabase');
      return;
    }

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final remoteEntries = await supabaseService.fetchEntriesForUser(userId);
      print('Fetched ${remoteEntries.length} entries from Supabase');

      final existingEntries = localRepository.getAllEntries();
      
      for (final remoteEntry in remoteEntries) {
        final supabaseId = remoteEntry['id'];

        final existingLocal = existingEntries
            .where((e) => e['supabase_id'] == supabaseId)
            .firstOrNull;

        if (existingLocal == null && remoteEntry is Map<String, dynamic>) {
          final localEntry = {
            ...remoteEntry,
            'local_photos': <String>[],
            'all_photos': remoteEntry['photos'] ?? [],
            'needs_sync': false,
            'sync_status': 'synced',
            'last_sync_attempt': DateTime.now().toIso8601String(),
          };

          await localRepository.saveEntry(localEntry);
          print('Added remote entry to local storage');
        }
      }
    } catch (e) {
      print('Fetch error from Supabase: $e');
    }
  }
}