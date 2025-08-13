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
    print('Vision API raw response: ${response.body}');
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
      if (response.statusCode == 403) {
        throw Exception('Billing not enabled for Google Cloud Vision API. Please enable billing at https://console.developers.google.com/billing/enable?project=695801669377');
      }
      return [];
    }
  } catch (e) {
    print('Error calling Vision API: $e');
    throw e;
  }
}

class EntriesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref ref;
  late final Box _box;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  List<Map<String, dynamic>> _remoteEntries = [];

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
    _updateState();
    fetchFromSupabase();
    _syncPendingEntries();
  }

  void _updateState() {
    final localPending = _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['synced'] == false)
        .toList();
    state = [...localPending, ..._remoteEntries];
  }

  Future<void> addEntry(
    Map<String, dynamic> entry, {
    List<File>? images,
  }) async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final conn = await Connectivity().checkConnectivity();

    if (!conn.contains(ConnectivityResult.none)) {
      print('Online, uploading directly to Supabase');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('User not authenticated, cannot upload');
        throw Exception('User not authenticated. Please log in.');
      }

      final uploadedUrls = <String>[];
      List<String> tags = [];
      String address = 'Unknown location';
      if (images != null && images.isNotEmpty) {
        try {
          tags = await getImageTags(images);
        } catch (e) {
          print('Tagging failed: $e');
          throw e;
        }
        for (final img in images) {
          try {
            final url = await supabaseService.uploadPhoto(img);
            uploadedUrls.add(url);
            print('Photo uploaded: $url');
          } catch (e) {
            print('Error uploading photo ${img.path}: $e');
          }
        }
      }

      if (entry['latitude'] != null && entry['longitude'] != null) {
        try {
          address = await getAddressFromLatLong(entry['latitude'], entry['longitude']);
          print('Generated address: $address');
        } catch (e) {
          print('Error generating address: $e');
        }
      }

      final payload = {
        'user_id': userId,
        'title': entry['title'] ?? '',
        'description': entry['description'] ?? '',
        'photos': uploadedUrls,
        'latitude': entry['latitude'] ?? 0.0,
        'longitude': entry['longitude'] ?? 0.0,
        'address': address,
        'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
        'tags': tags,
      };
      print('Inserting payload to Supabase: $payload');

      final inserted = await supabaseService.insertEntry(payload);
      print('Raw insert result: $inserted');
      if (inserted == null) {
        print('Insert failed, no data returned - check RLS policies or schema');
        throw Exception('Failed to save entry to Supabase. Check database permissions.');
      }

      await fetchFromSupabase();
      return;
    }

    print('Offline, storing locally');
    entry['synced'] = false;
    entry['local_photos'] = images?.map((f) => f.path).toList() ?? [];
    entry['photos'] = <String>[];
    entry['tags'] = <String>[];
    entry['address'] = 'Unknown location';
    await _box.add(entry);
    _updateState();
  }

  Future<void> updateEntry(
    int index,
    Map<String, dynamic> entry, {
    List<File>? images,
    List<String>? existingPhotos,
  }) async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final conn = await Connectivity().checkConnectivity();

    if (!conn.contains(ConnectivityResult.none)) {
      print('Online, updating directly in Supabase');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('User not authenticated, cannot update');
        throw Exception('User not authenticated. Please log in.');
      }

      final uploadedUrls = <String>[...(existingPhotos ?? [])];
      List<String> tags = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      String address = entry['address'] ?? 'Unknown location';

      if (images != null && images.isNotEmpty) {
        try {
          tags = await getImageTags(images);
        } catch (e) {
          print('Tagging failed: $e');
          throw e;
        }
        for (final img in images) {
          try {
            final url = await supabaseService.uploadPhoto(img);
            uploadedUrls.add(url);
            print('Photo uploaded: $url');
          } catch (e) {
            print('Error uploading photo ${img.path}: $e');
          }
        }
      }

      if (entry['latitude'] != null && entry['longitude'] != null) {
        try {
          address = await getAddressFromLatLong(entry['latitude'], entry['longitude']);
          print('Generated address: $address');
        } catch (e) {
          print('Error generating address: $e');
        }
      }

      final payload = {
        'user_id': userId,
        'title': entry['title'] ?? '',
        'description': entry['description'] ?? '',
        'photos': uploadedUrls,
        'latitude': entry['latitude'] ?? 0.0,
        'longitude': entry['longitude'] ?? 0.0,
        'address': address,
        'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
        'tags': tags,
      };
      print('Updating payload in Supabase: $payload');

      try {
        final res = await Supabase.instance.client
            .from('journal_entries')
            .update(payload)
            .eq('id', entry['id'])
            .select()
            .maybeSingle();
        print('Update response: $res');
        if (res == null) {
          print('Update failed, no data returned - check RLS policies or schema');
          throw Exception('Failed to update entry in Supabase. Check database permissions.');
        }
      } catch (e) {
        print('Update error: $e');
        throw e;
      }

      await fetchFromSupabase();
      return;
    }

    print('Offline, updating locally');
    entry['synced'] = false;
    entry['local_photos'] = images?.map((f) => f.path).toList() ?? (entry['local_photos'] as List<dynamic>?)?.cast<String>() ?? [];
    entry['photos'] = existingPhotos ?? (entry['photos'] as List<dynamic>?)?.cast<String>() ?? [];
    entry['tags'] = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    entry['address'] = entry['address'] ?? 'Unknown location';

    final localKeys = _box.keys.toList()..sort();
    if (index < localKeys.length && entry['synced'] == false) {
      final keyToUpdate = localKeys[index];
      await _box.put(keyToUpdate, entry);
      print('Updated local entry at key: $keyToUpdate');
    } else {
      final id = entry['id'];
      if (id != null) {
        entry['sync_action'] = 'update'; // Flag for sync to use update instead of insert
      }
      await _box.add(entry);
      print('Added updated entry to local storage for sync');
    }
    _updateState();
  }

  Future<void> _syncPendingEntries() async {
    print('Starting sync of pending entries');
    final supabaseService = ref.read(supabaseServiceProvider);
    final pendingKeys = _box.keys.toList();
    for (final key in pendingKeys) {
      final entry = Map<String, dynamic>.from(_box.get(key) ?? {});
      if (entry['synced'] == true) continue;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('User not authenticated, skipping sync');
        continue;
      }

      final localPhotos = (entry['local_photos'] as List<dynamic>?)?.cast<String>() ?? [];
      final uploadedUrls = (entry['photos'] as List<dynamic>?)?.cast<String>() ?? [];
      final files = <File>[];

      try {
        for (final p in localPhotos) {
          final f = File(p);
          if (await f.exists()) {
            files.add(f);
          } else {
            print('Local photo not found: $p');
          }
        }

        List<String> tags = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        try {
          if (files.isNotEmpty) {
            tags = await getImageTags(files);
          }
        } catch (e) {
          print('Tagging failed during sync: $e');
          throw e;
        }

        for (final f in files) {
          final url = await supabaseService.uploadPhoto(f);
          uploadedUrls.add(url);
          print('Photo uploaded: $url');
        }

        String address = entry['address'] ?? 'Unknown location';
        if (entry['latitude'] != null && entry['longitude'] != null) {
          try {
            address = await getAddressFromLatLong(entry['latitude'], entry['longitude']);
            print('Generated address: $address');
          } catch (e) {
            print('Error generating address: $e');
          }
        }

        final payload = {
          'user_id': userId,
          'title': entry['title'] ?? '',
          'description': entry['description'] ?? '',
          'photos': uploadedUrls,
          'latitude': entry['latitude'] ?? 0.0,
          'longitude': entry['longitude'] ?? 0.0,
          'address': address,
          'date_time': entry['date_time'] ?? DateTime.now().toIso8601String(),
          'tags': tags,
        };
        print('Syncing payload to Supabase: $payload');

        Map<String, dynamic>? inserted;
        if (entry['sync_action'] == 'update' && entry['id'] != null) {
          print('Performing update sync for entry with ID: ${entry['id']}');
          final res = await Supabase.instance.client
              .from('journal_entries')
              .update(payload)
              .eq('id', entry['id'])
              .select()
              .maybeSingle();
          print('Update sync response: $res');
          inserted = res;
        } else {
          inserted = await supabaseService.insertEntry(payload);
          print('Raw sync insert result: $inserted');
        }

        if (inserted == null) {
          print('Sync failed');
          continue;
        }

        await _box.delete(key);
        print('Deleted local entry after successful sync');
      } catch (e) {
        print('Sync error for entry $key: $e');
      }
    }

    await fetchFromSupabase();
    _updateState();
  }

  Future<void> fetchFromSupabase() async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('User not authenticated, cannot fetch');
      return;
    }

    try {
      final remoteEntries = await supabaseService.fetchEntriesForUser(userId);
      print('Fetched raw remote entries: $remoteEntries');
      _remoteEntries = remoteEntries.map((e) {
        final r = Map<String, dynamic>.from(e);
        r['synced'] = true;
        return r;
      }).toList();
      _updateState();
    } catch (e) {
      print('Fetch error: $e');
    }
  }

  Future<void> deleteEntryAt(int index) async {
    if (index >= state.length) return;
    final entry = state[index];

    if (entry['synced'] == false) {
      final localKeys = _box.keys.toList()..sort();
      if (index < localKeys.length) {
        final keyToDelete = localKeys[index];
        await _box.delete(keyToDelete);
        print('Deleted local unsynced entry');
      }
    } else {
      final remoteId = entry['id'];
      try {
        await Supabase.instance.client
            .from('journal_entries')
            .delete()
            .eq('id', remoteId);
        print('Deleted remote entry with ID: $remoteId');
      } catch (e) {
        print('Delete error from Supabase: $e');
      }
    }

    await fetchFromSupabase();
    _updateState();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}