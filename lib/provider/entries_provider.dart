import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/vision_api_service.dart';
import '../services/supabase_service.dart';
import '../repositories/local_repository.dart';
import '../repositories/sync_repository.dart';
import '../utils/connectivity_helper.dart';

final supabaseServiceProvider = Provider((ref) => SupabaseService());

final localRepositoryProvider = Provider((ref) => LocalRepository());

final syncRepositoryProvider = Provider((ref) => 
    SyncRepository(ref, ref.read(localRepositoryProvider)));

final entriesNotifierProvider =
    StateNotifierProvider<EntriesNotifier, List<Map<String, dynamic>>>(
  (ref) => EntriesNotifier(ref),
);

class EntriesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref ref;
  late final LocalRepository _localRepository;
  late final SyncRepository _syncRepository;
  
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<AuthState>? _authSub;

  // Track sync status for UI
  bool get hasPendingChanges => _localRepository.hasPendingChanges();

  EntriesNotifier(this.ref) : super([]) {
    _localRepository = ref.read(localRepositoryProvider);
    _syncRepository = ref.read(syncRepositoryProvider);
    _init();
    _setupListeners();
  }

  Future<void> _init() async {
    try {
      await _loadEntries();
      _syncRepository.syncToSupabase();
    } catch (e) {
      print('Error initializing entries: $e');
    }
  }

  void _setupListeners() {
    _connSub = ConnectivityHelper.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncRepository.syncToSupabase();
      }
    });

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        print('User signed out - clearing all local data');
        clearAllLocalData();
      }
    });
  }

  Future<void> _loadEntries() async {
    try {
      final entries = _localRepository.getAllEntries();
      state = entries;
      print('Loaded ${entries.length} entries');
    } catch (e) {
      print('Error loading entries: $e');
      state = [];
    }
  }

  Future<void> addEntry(
    Map<String, dynamic> entryData, {
    List<File>? images,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated. Please log in first.');
    }

    try {
      // Copy images to persistent storage
      final localPhotoPaths = await PhotoService.copyImagesToPersistentStorage(
          images ?? []);

      // Generate tags from images
      List<String> tags = [];
      if (localPhotoPaths.isNotEmpty) {
        final persistentImages =
            localPhotoPaths.map((path) => File(path)).toList();
        tags = await VisionApiService.getImageTags(persistentImages);
      }

      // Generate address from coordinates
      String address = 'Unknown location';
      if (entryData['latitude'] != null && entryData['longitude'] != null) {
        address = await LocationService.getAddressFromLatLong(
          entryData['latitude'],
          entryData['longitude'],
        );
      }

      final entry = {
        'user_id': userId,
        'title': entryData['title'] ?? '',
        'description': entryData['description'] ?? '',
        'local_photos': localPhotoPaths,
        'photos': <String>[],
        'all_photos': localPhotoPaths,
        'latitude': entryData['latitude'] ?? 0.0,
        'longitude': entryData['longitude'] ?? 0.0,
        'address': address,
        'date_time': entryData['date_time'] ?? DateTime.now().toIso8601String(),
        'tags': tags,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': true,
        'sync_status': 'pending',
        'last_sync_attempt': null,
      };

      await _localRepository.saveEntry(entry);
      await _loadEntries();
      _syncRepository.syncToSupabase();
    } catch (e) {
      print('Error adding entry: $e');
      throw Exception('Failed to save entry: $e');
    }
  }

  Future<void> updateEntry(
    int index,
    Map<String, dynamic> entryData, {
    List<File>? newImages,
    List<String>? keptPhotos,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated. Please log in first.');
    }

    if (index >= state.length) {
      throw Exception('Invalid entry index');
    }

    try {
      final currentEntry = state[index];
      
      // Handle new images
      final newLocalPhotoPaths = await PhotoService.copyImagesToPersistentStorage(
          newImages ?? []);

      // Handle kept photos
      final keptLocalPhotos = keptPhotos
          ?.where((p) => !p.startsWith('http'))
          .toList() ?? 
          List<String>.from(currentEntry['local_photos'] ?? []);
      final keptRemotePhotos = keptPhotos
          ?.where((p) => p.startsWith('http'))
          .toList() ?? 
          List<String>.from(currentEntry['photos'] ?? []);

      final allLocalPhotos = [...keptLocalPhotos, ...newLocalPhotoPaths];
      
      // Delete removed local photos
      final currentLocalPhotos = 
          List<String>.from(currentEntry['local_photos'] ?? []);
      final photosToDelete = currentLocalPhotos
          .where((photo) => !allLocalPhotos.contains(photo))
          .toList();
      await PhotoService.deleteLocalPhotos(photosToDelete);

      // Generate new tags if needed
      List<String> tags = 
          List<String>.from(currentEntry['tags'] ?? []);
      if (newLocalPhotoPaths.isNotEmpty) {
        final newImages = newLocalPhotoPaths.map((path) => File(path)).toList();
        final newTags = await VisionApiService.getImageTags(newImages);
        final tagSet = tags.toSet()..addAll(newTags);
        tags = tagSet.toList();
      }

      // Generate address if coordinates changed
      String address = entryData['address'] ?? 
          currentEntry['address'] ?? 'Unknown location';
      if (entryData['latitude'] != null && entryData['longitude'] != null) {
        address = await LocationService.getAddressFromLatLong(
          entryData['latitude'],
          entryData['longitude'],
        );
      }

      final updatedEntry = {
        ...currentEntry,
        'title': entryData['title'] ?? currentEntry['title'],
        'description': entryData['description'] ?? currentEntry['description'],
        'local_photos': allLocalPhotos,
        'photos': keptRemotePhotos,
        'all_photos': [...allLocalPhotos, ...keptRemotePhotos],
        'latitude': entryData['latitude'] ?? currentEntry['latitude'],
        'longitude': entryData['longitude'] ?? currentEntry['longitude'],
        'address': address,
        'date_time': entryData['date_time'] ?? currentEntry['date_time'],
        'tags': tags,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': true,
        'sync_status': currentEntry['supabase_id'] != null ? 'modified' : 'pending',
      };

      await _localRepository.updateEntry(updatedEntry);
      await _loadEntries();
      _syncRepository.syncToSupabase();
    } catch (e) {
      print('Error updating entry: $e');
      throw Exception('Failed to update entry: $e');
    }
  }

  // Keep the legacy method for backward compatibility
  Future<void> updateEntryFixed(
    int index,
    Map<String, dynamic> entry, {
    List<File>? newImages,
    List<String>? keptPhotos,
  }) async {
    await updateEntry(index, entry, newImages: newImages, keptPhotos: keptPhotos);
  }

  Future<void> deleteEntryAt(int index) async {
    if (index >= state.length) {
      throw Exception('Invalid entry index');
    }

    try {
      final entry = state[index];
      
      // Delete local photos
      final localPhotos = 
          List<String>.from(entry['local_photos'] ?? []);
      await PhotoService.deleteLocalPhotos(localPhotos);

      if (entry['supabase_id'] != null) {
        // Mark for deletion if exists in Supabase
        final deletionEntry = {
          ...entry,
          'needs_sync': true,
          'sync_status': 'delete_pending',
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        await _localRepository.updateEntry(deletionEntry);
        _syncRepository.syncToSupabase();
      } else {
        // Delete locally if never synced
        if (entry['local_id'] != null) {
          await _localRepository.deleteEntry(entry['local_id']);
        }
      }

      await _loadEntries();
    } catch (e) {
      print('Error deleting entry: $e');
      throw Exception('Failed to delete entry: $e');
    }
  }

  Future<void> clearAllLocalData() async {
    try {
      // Delete all local photos first
      for (final entry in state) {
        final localPhotos = 
            List<String>.from(entry['local_photos'] ?? []);
        await PhotoService.deleteLocalPhotos(localPhotos);
      }

      await _localRepository.clearAllData();
      state = [];
      print('Successfully cleared all local data');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  Future<void> refreshEntries() async {
    await _loadEntries();
  }

  Future<void> fetchFromSupabase() async {
    await _syncRepository.fetchFromSupabase();
    await _loadEntries();
  }

  List<Map<String, dynamic>> searchEntries(String query) {
    return _localRepository.searchEntries(query);
  }

  int get entriesCount => _localRepository.entriesCount;

  Map<String, dynamic>? getEntryByLocalId(int localId) {
    return _localRepository.getEntryByLocalId(localId);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}