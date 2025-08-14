import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider((ref) => SupabaseService());

final entriesNotifierProvider =
    StateNotifierProvider<EntriesNotifier, List<Map<String, dynamic>>>(
  (ref) => EntriesNotifier(ref),
);

Future<String> getAddressFromLatLong(double lat, double long) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
    Placemark place = placemarks.first;

    String address =
        "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}"
            .replaceAll(RegExp(r', , '), ', ')
            .replaceAll(RegExp(r', $'), '')
            .trim();
    if (address.isEmpty) {
      return "Unknown location";
    }
    return address;
  } catch (e) {
    print("Error getting address: $e");
    return "Unknown location";
  }
}

Future<List<String>> getImageTags(List<File> images) async {
  if (images.isEmpty) {
    print('No images provided for tagging');
    return [];
  }

  final apiKey = 'AIzaSyDRI_aEJaT6ZNZrCW_GHKXo-Ydn5XKCyr8';
  final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');

  List<Map<String, dynamic>> requests = [];
  for (var image in images) {
    try {
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      requests.add({
        "image": {"content": base64},
        "features": [{"type": "LABEL_DETECTION", "maxResults": 5}]
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
      return []; // Return empty list instead of throwing
    }
  } catch (e) {
    print('Error calling Vision API: $e');
    return []; // Return empty list instead of throwing
  }
}

class EntriesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref ref;
  late final Box _box;
  int _nextLocalId = 1;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  
  // Track sync status for UI
  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;

  EntriesNotifier(this.ref) : super([]) {
    _init();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncToSupabase();
      }
    });
  }

  Future<void> _init() async {
    try {
      _box = Hive.box('entries');
      _loadNextLocalId();
      await _loadLocalEntries();
      // Try to sync with Supabase if online
      _syncToSupabase();
    } catch (e) {
      print('Error initializing entries: $e');
    }
  }

  void _loadNextLocalId() {
    // Find the highest local ID and set next ID
    final entries = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    if (entries.isNotEmpty) {
      final maxLocalId = entries
          .map((e) => e['local_id'] as int? ?? 0)
          .reduce((a, b) => a > b ? a : b);
      _nextLocalId = maxLocalId + 1;
    }
  }

  Future<void> _loadLocalEntries() async {
    try {
      final entries = _box.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
          ..sort((a, b) {
            final aDateTime = DateTime.tryParse(a['date_time'] ?? '') ?? DateTime.now();
            final bDateTime = DateTime.tryParse(b['date_time'] ?? '') ?? DateTime.now();
            return bDateTime.compareTo(aDateTime); // Most recent first
          });
      
      // Check if there are pending changes
      _hasPendingChanges = entries.any((e) => 
          e['needs_sync'] == true || 
          e['sync_status'] == 'pending' || 
          e['sync_status'] == 'modified'
      );
      
      state = entries;
      print('Loaded ${entries.length} entries from local storage');
    } catch (e) {
      print('Error loading local entries: $e');
      state = [];
    }
  }

  // Public method to refresh entries from local storage
  Future<void> refreshEntries() async {
    try {
      await _loadLocalEntries();
      print('Entries refreshed from local storage');
    } catch (e) {
      print('Error refreshing entries: $e');
    }
  }

  Future<void> addEntry(
    Map<String, dynamic> entry, {
    List<File>? images,
  }) async {
    try {
      print('Adding new entry to local storage');
      
      // Generate tags from images if provided
      List<String> tags = [];
      if (images != null && images.isNotEmpty) {
        try {
          tags = await getImageTags(images);
        } catch (e) {
          print('Tagging failed: $e');
          // Continue without tags rather than failing
        }
      }

      // Generate address from coordinates
      String address = 'Unknown location';
      if (entry['latitude'] != null && entry['longitude'] != null) {
        try {
          address = await getAddressFromLatLong(
            entry['latitude'], 
            entry['longitude']
          );
          print('Generated address: $address');
        } catch (e) {
          print('Error generating address: $e');
        }
      }

      // Prepare entry data for local storage
      final entryData = {
        'local_id': _nextLocalId++,
        'supabase_id': null, // Will be set after sync
        'title': entry['title'] ?? '',
        'description': entry['description'] ?? '',
        'local_photos': images?.map((f) => f.path).toList() ?? [],
        'photos': <String>[], // Remote URLs after sync
        'latitude': entry['latitude'] ?? 0.0,
        'longitude': entry['longitude'] ?? 0.0,
        'address': address,
        'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
        'tags': tags,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': true,
        'sync_status': 'pending', // pending, synced, modified, error
        'last_sync_attempt': null,
      };

      // Save to local storage
      final key = 'entry_${entryData['local_id']}';
      await _box.put(key, entryData);
      print('Entry saved locally with key: $key');
      
      // Update pending changes flag
      _hasPendingChanges = true;
      
      // Reload entries to update state
      await _loadLocalEntries();
      
      // Try to sync immediately if online
      _syncToSupabase();
    } catch (e) {
      print('Error adding entry: $e');
      throw Exception('Failed to save entry locally: $e');
    }
  }

Future<void> updateEntry(
  int index,
  Map<String, dynamic> entry, {
  List<File>? images,
  List<String>? existingPhotos,
}) async {
  try {
    if (index >= state.length) {
      throw Exception('Invalid entry index');
    }

    print('Updating entry at index $index');
    final currentEntry = state[index];
    final localId = currentEntry['local_id'];

    // Generate new tags if new images are provided
    List<String> tags = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? 
                       (currentEntry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    
    if (images != null && images.isNotEmpty) {
      try {
        tags = await getImageTags(images);
      } catch (e) {
        print('Tagging failed: $e');
        // Keep existing tags if new tagging fails
      }
    }

    // Generate address if coordinates changed
    String address = entry['address'] ?? currentEntry['address'] ?? 'Unknown location';
    if (entry['latitude'] != null && entry['longitude'] != null) {
      try {
        address = await getAddressFromLatLong(
          entry['latitude'], 
          entry['longitude']
        );
        print('Generated address: $address');
      } catch (e) {
        print('Error generating address: $e');
      }
    }

    // Handle photos properly - use the photos as they are sent from AddEntryScreen
    // Separate local photos (file paths) from remote photos (URLs)
    final List<String> localPhotoPaths = [];
    final List<String> remotePhotoUrls = [];
    
    // Process the display photos from the edit screen
    if (images != null) {
      for (final file in images) {
        localPhotoPaths.add(file.path);
      }
    }
    
    // Add any existing remote URLs that were passed
    if (existingPhotos != null) {
      for (final photo in existingPhotos) {
        if (photo.startsWith('http')) {
          remotePhotoUrls.add(photo);
        } else {
          // This is a local photo path
          if (!localPhotoPaths.contains(photo)) {
            localPhotoPaths.add(photo);
          }
        }
      }
    }

    // Prepare updated entry data
    final updatedEntry = {
      'local_id': localId,
      'supabase_id': currentEntry['supabase_id'],
      'title': entry['title'] ?? currentEntry['title'] ?? '',
      'description': entry['description'] ?? currentEntry['description'] ?? '',
      'local_photos': localPhotoPaths,
      'photos': remotePhotoUrls,
      'latitude': entry['latitude'] ?? currentEntry['latitude'] ?? 0.0,
      'longitude': entry['longitude'] ?? currentEntry['longitude'] ?? 0.0,
      'address': address,
      'date_time': entry['date_time'] ?? currentEntry['date_time'] ?? DateTime.now().toIso8601String(),
      'tags': tags,
      'created_at': currentEntry['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'needs_sync': true,
      'sync_status': currentEntry['supabase_id'] != null ? 'modified' : 'pending',
      'last_sync_attempt': currentEntry['last_sync_attempt'],
    };

    // Update in local storage
    final key = 'entry_$localId';
    await _box.put(key, updatedEntry);
    print('Entry updated locally with key: $key');
    
    // Update pending changes flag
    _hasPendingChanges = true;
    
    // Reload entries to update state
    await _loadLocalEntries();
    
    // Try to sync immediately if online
    _syncToSupabase();
  } catch (e) {
    print('Error updating entry: $e');
    throw Exception('Failed to update entry locally: $e');
  }
}
  Future<void> deleteEntryAt(int index) async {
    try {
      if (index >= state.length) {
        throw Exception('Invalid entry index');
      }

      final entry = state[index];
      final localId = entry['local_id'];
      final supabaseId = entry['supabase_id'];
      
      // Delete associated local photos
      final localPhotos = (entry['local_photos'] as List<dynamic>?)?.cast<String>() ?? [];
      for (final photoPath in localPhotos) {
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

      // If it exists in Supabase, mark for deletion instead of removing locally
      if (supabaseId != null) {
        final deletionEntry = {
          ...entry,
          'needs_sync': true,
          'sync_status': 'delete_pending',
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        final key = 'entry_$localId';
        await _box.put(key, deletionEntry);
        print('Marked entry for deletion: $key');
        
        _hasPendingChanges = true;
        _syncToSupabase(); // Try to delete from Supabase immediately
      } else {
        // Remove from local storage completely (never synced)
        final key = 'entry_$localId';
        await _box.delete(key);
        print('Deleted local-only entry with key: $key');
      }
      
      // Reload entries to update state
      await _loadLocalEntries();
    } catch (e) {
      print('Error deleting entry: $e');
      throw Exception('Failed to delete entry: $e');
    }
  }

  // Sync local changes to Supabase
  Future<void> _syncToSupabase() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
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
    
    // Get all entries that need sync
    final allEntries = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    final entriesToSync = allEntries.where((e) => e['needs_sync'] == true).toList();
    
    for (final entry in entriesToSync) {
      try {
        final localId = entry['local_id'];
        final key = 'entry_$localId';
        
        if (entry['sync_status'] == 'delete_pending') {
          // Delete from Supabase
          if (entry['supabase_id'] != null) {
            await Supabase.instance.client
                .from('journal_entries')
                .delete()
                .eq('id', entry['supabase_id']);
            print('Deleted entry from Supabase: ${entry['supabase_id']}');
          }
          
          // Remove from local storage after successful deletion
          await _box.delete(key);
          continue;
        }
        
        // Upload local photos to Supabase
        final localPhotos = (entry['local_photos'] as List<dynamic>?)?.cast<String>() ?? [];
        final uploadedUrls = <String>[...(entry['photos'] as List<dynamic>?)?.cast<String>() ?? []];
        
        for (final photoPath in localPhotos) {
          try {
            final file = File(photoPath);
            if (await file.exists()) {
              final url = await supabaseService.uploadPhoto(file);
              uploadedUrls.add(url);
              print('Photo uploaded: $url');
            }
          } catch (e) {
            print('Error uploading photo $photoPath: $e');
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
          'tags': entry['tags'] ?? [],
        };

        Map<String, dynamic>? result;
        
        if (entry['supabase_id'] != null && entry['sync_status'] == 'modified') {
          // Update existing entry
          result = await Supabase.instance.client
              .from('journal_entries')
              .update(payload)
              .eq('id', entry['supabase_id'])
              .select()
              .maybeSingle();
          print('Updated entry in Supabase: ${entry['supabase_id']}');
        } else {
          // Insert new entry
          result = await supabaseService.insertEntry(payload);
          print('Inserted new entry to Supabase');
        }

        if (result != null) {
          // Update local entry with sync info
          final syncedEntry = {
            ...entry,
            'supabase_id': result['id'],
            'photos': uploadedUrls,
            'needs_sync': false,
            'sync_status': 'synced',
            'last_sync_attempt': DateTime.now().toIso8601String(),
          };
          
          await _box.put(key, syncedEntry);
          print('Updated local entry after successful sync: $key');
        }
        
      } catch (e) {
        print('Sync error for entry ${entry['local_id']}: $e');
        
        // Mark sync attempt
        final updatedEntry = {
          ...entry,
          'sync_status': 'error',
          'last_sync_attempt': DateTime.now().toIso8601String(),
        };
        
        final key = 'entry_${entry['local_id']}';
        await _box.put(key, updatedEntry);
      }
    }
    
    // Reload entries and update sync status
    await _loadLocalEntries();
    print('Sync to Supabase completed');
  }

  // Fetch from Supabase and merge with local (for initial sync)
  Future<void> fetchFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated, cannot fetch from Supabase');
      await _loadLocalEntries(); // Still load local entries
      return;
    }

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final remoteEntries = await supabaseService.fetchEntriesForUser(userId);
      print('Fetched ${remoteEntries.length} entries from Supabase');
      
      // Merge with local entries (avoid duplicates)
      for (final remoteEntry in remoteEntries) {
        final supabaseId = remoteEntry['id'];
        
        // Check if we already have this entry locally
        final existingLocal = _box.values
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['supabase_id'] == supabaseId)
            .firstOrNull;
        
        if (existingLocal == null) {
          // Add new entry from Supabase
          final localEntry = {
            'local_id': _nextLocalId++,
            'supabase_id': supabaseId,
            'title': remoteEntry['title'] ?? '',
            'description': remoteEntry['description'] ?? '',
            'local_photos': <String>[],
            'photos': (remoteEntry['photos'] as List<dynamic>?)?.cast<String>() ?? [],
            'latitude': remoteEntry['latitude'] ?? 0.0,
            'longitude': remoteEntry['longitude'] ?? 0.0,
            'address': remoteEntry['address'] ?? 'Unknown location',
            'date_time': remoteEntry['date_time'] ?? DateTime.now().toIso8601String(),
            'tags': (remoteEntry['tags'] as List<dynamic>?)?.cast<String>() ?? [],
            'created_at': remoteEntry['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': remoteEntry['updated_at'] ?? DateTime.now().toIso8601String(),
            'needs_sync': false,
            'sync_status': 'synced',
            'last_sync_attempt': DateTime.now().toIso8601String(),
          };
          
          final key = 'entry_${localEntry['local_id']}';
          await _box.put(key, localEntry);
          print('Added remote entry to local storage: $key');
        }
      }
      
      await _loadLocalEntries();
    } catch (e) {
      print('Fetch error from Supabase: $e');
      await _loadLocalEntries(); // Still load local entries
    }
  }

  // Search entries by title, description, tags, address
  List<Map<String, dynamic>> searchEntries(String query) {
    if (query.isEmpty) return state;
    
    final lowerQuery = query.toLowerCase();
    return state.where((entry) {
      // Skip entries marked for deletion
      if (entry['sync_status'] == 'delete_pending') return false;
      
      final title = (entry['title'] ?? '').toString().toLowerCase();
      final description = (entry['description'] ?? '').toString().toLowerCase();
      final address = (entry['address'] ?? '').toString().toLowerCase();
      final tags = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      final tagString = tags.join(' ').toLowerCase();
      final dateStr = (entry['date_time'] as String?)?.split('T').first.toLowerCase() ?? '';
      
      return title.contains(lowerQuery) || 
             description.contains(lowerQuery) || 
             address.contains(lowerQuery) ||
             tagString.contains(lowerQuery) ||
             dateStr.contains(lowerQuery);
    }).toList();
  }

  // Get entries count (excluding deleted ones)
  int get entriesCount => state.where((e) => e['sync_status'] != 'delete_pending').length;

  // Get entry by local ID
  Map<String, dynamic>? getEntryByLocalId(int localId) {
    try {
      final key = 'entry_$localId';
      final entry = _box.get(key);
      return entry != null ? Map<String, dynamic>.from(entry) : null;
    } catch (e) {
      print('Error getting entry by local ID $localId: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}



