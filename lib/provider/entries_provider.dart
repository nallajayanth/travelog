import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider((ref) => SupabaseService());

final entriesNotifierProvider =
    StateNotifierProvider<EntriesNotifier, List<Map<String, dynamic>>>(
      (ref) => EntriesNotifier(ref),
    );

class EntriesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref ref;
  late final Box _box;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  EntriesNotifier(this.ref) : super([]) {
    _init();

    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncPendingEntries();
      }
    });
  }

  Future<void> _init() async {
    _box = Hive.box('entries');
    state = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    await fetchFromSupabase();
    await _syncPendingEntries();
  }

  Future<void> addEntry(
    Map<String, dynamic> entry, {
    List<File>? images,
  }) async {
    final supabaseService = ref.read(supabaseServiceProvider);

    final localEntry = Map<String, dynamic>.from(entry);
    localEntry['synced'] = localEntry['synced'] ?? false;
    localEntry['photos'] = localEntry['photos'] ?? <String>[];
    localEntry['local_photos'] = localEntry['local_photos'] ?? <String>[];

    final dynamic key = await _box.add(localEntry);
    state = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
      print('No connectivity, entry saved locally only');
      return;
    }

    final index = _box.values.toList().indexOf(localEntry);
    if (index != -1) {
      await _uploadLocalEntryAtIndex(index);
    }
  }

  Future<void> _uploadLocalEntryAtIndex(int index) async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated, cannot sync');
      return;
    }

    final dynamic rawEntry = _box.getAt(index);
    if (rawEntry == null) return;
    final entry = Map<String, dynamic>.from(rawEntry);

    final List<String> localPhotos = List<String>.from(
      entry['local_photos'] ?? [],
    );
    final uploadedUrls = <String>[];

    try {
      for (final p in localPhotos) {
        final f = File(p);
        if (await f.exists()) {
          final url = await supabaseService.uploadPhoto(f);
          uploadedUrls.add(url);
          print('Photo uploaded: $url');
        } else {
          print('Local photo not found: $p');
        }
      }

      final payload = {
        'user_id': userId,
        'title': entry['title'],
        'description': entry['description'],
        'photos': uploadedUrls,
        'latitude': entry['latitude'],
        'longitude': entry['longitude'],
        'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
        'tags': entry['tags'] ?? <String>[],
      };
      print('Inserting payload to Supabase: $payload');

      final inserted = await supabaseService.insertEntry(payload);
      print('Raw insert result: $inserted');
      if (inserted == null) {
        print('Insert failed, no data returned - check RLS policies or schema');
        return;
      }

      final updated = Map<String, dynamic>.from(entry);
      updated['photos'] = uploadedUrls;
      updated['synced'] = true;
      if (inserted['id'] != null) {
        updated['remote_id'] = inserted['id'];
      }

      await _box.putAt(index, updated);
      state = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
      print('Entry synced successfully with ID: ${inserted['id']}');
    } catch (e) {
      print('Sync error: $e - Check Supabase logs for details');
    }
  }

  Future<void> _syncPendingEntries() async {
    print('Starting sync of pending entries');
    for (int i = 0; i < _box.length; i++) {
      final raw = _box.getAt(i);
      if (raw == null) continue;
      final e = Map<String, dynamic>.from(raw);
      if (e['synced'] == true) continue;
      await _uploadLocalEntryAtIndex(i);
    }
  }

  Future<void> fetchFromSupabase() async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated, cannot fetch');
      return;
    }

    final remoteEntries = await supabaseService.fetchEntriesForUser(userId);
    print('Fetched raw remote entries: $remoteEntries');

    for (final remote in remoteEntries) {
      final r = Map<String, dynamic>.from(remote);
      r['synced'] = true;

      final existingIndex = _box.values.toList().indexWhere((local) {
        final lm = Map<String, dynamic>.from(local);
        if (lm['remote_id'] != null && lm['remote_id'] == r['id']) return true;
        return false;
      });

      if (existingIndex >= 0) {
        await _box.putAt(existingIndex, r);
      } else {
        await _box.add(r);
      }
    }

    state = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    print('Fetched and synced ${remoteEntries.length} entries from Supabase');
  }


  Future<void> deleteEntryAt(int index) async {
    final raw = _box.getAt(index);
    if (raw == null) return;

    final entry = Map<String, dynamic>.from(raw);

    // First, delete from Supabase if remote_id exists
    if (entry['remote_id'] != null) {
      try {
        await Supabase.instance.client
            .from('journal_entries')
            .delete()
            .eq('id', entry['remote_id']);
        print('Deleted remote entry with ID: ${entry['remote_id']}');
      } catch (e) {
        print('Delete error from Supabase: $e');
      }
    }

    // Delete from local storage (Hive or similar)
    await _box.deleteAt(index);

    // Make sure state is updated for UI
    state = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();

    print('Deleted local entry at index $index');
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}
