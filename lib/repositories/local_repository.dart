import 'package:hive/hive.dart';

class LocalRepository {
  late final Box _box;
  int _nextLocalId = 1;

  LocalRepository() {
    _box = Hive.box('entries');
    _loadNextLocalId();
  }

  void _loadNextLocalId() {
    final entries = _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (entries.isNotEmpty) {
      final maxLocalId = entries
          .map((e) => e['local_id'] as int? ?? 0)
          .reduce((a, b) => a > b ? a : b);
      _nextLocalId = maxLocalId + 1;
    }
  }

  List<Map<String, dynamic>> getAllEntries() {
    final entries = _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) {
        final aDateTime =
            DateTime.tryParse(a['date_time'] ?? '') ?? DateTime.now();
        final bDateTime =
            DateTime.tryParse(b['date_time'] ?? '') ?? DateTime.now();
        return bDateTime.compareTo(aDateTime); // Most recent first
      });

    // Add all_photos for display, combining local and remote photos
    for (var e in entries) {
      e['all_photos'] = [
        ...(e['local_photos'] as List<dynamic>?)?.cast<String>() ?? [],
        ...(e['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      ];
    }

    return entries;
  }

  Future<void> saveEntry(Map<String, dynamic> entry) async {
    final entryToSave = {
      ...entry,
      'local_id': entry['local_id'] ?? _nextLocalId++,
    };
    
    final key = 'entry_${entryToSave['local_id']}';
    await _box.put(key, entryToSave);
    print('Entry saved locally with key: $key');
  }

  Future<void> updateEntry(Map<String, dynamic> entry) async {
    if (entry['local_id'] == null) {
      throw Exception('Cannot update entry without local ID');
    }
    
    final key = 'entry_${entry['local_id']}';
    await _box.put(key, entry);
    print('Entry updated locally with key: $key');
  }

  Future<void> deleteEntry(int localId) async {
    final key = 'entry_$localId';
    await _box.delete(key);
    print('Deleted entry with key: $key');
  }

  Map<String, dynamic>? getEntryByLocalId(int localId) {
    try {
      final key = 'entry_$localId';
      final entry = _box.get(key);
      if (entry != null) {
        final entryMap = Map<String, dynamic>.from(entry);
        // Ensure all_photos is included when fetching by ID
        entryMap['all_photos'] = [
          ...(entryMap['local_photos'] as List<dynamic>?)?.cast<String>() ?? [],
          ...(entryMap['photos'] as List<dynamic>?)?.cast<String>() ?? [],
        ];
        return entryMap;
      }
      return null;
    } catch (e) {
      print('Error getting entry by local ID $localId: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> getEntriesNeedingSync() {
    return _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['needs_sync'] == true)
        .toList();
  }

  bool hasPendingChanges() {
    return _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .any((e) =>
            e['needs_sync'] == true ||
            e['sync_status'] == 'pending' ||
            e['sync_status'] == 'modified');
  }

  Future<void> clearAllData() async {
    await _box.clear();
    _nextLocalId = 1;
    print('Cleared all entries from local storage');
  }

  List<Map<String, dynamic>> searchEntries(String query) {
    if (query.isEmpty) return getAllEntries();

    final lowerQuery = query.toLowerCase();
    return getAllEntries().where((entry) {
      // Skip entries marked for deletion
      if (entry['sync_status'] == 'delete_pending') return false;

      final title = (entry['title'] ?? '').toString().toLowerCase();
      final description = (entry['description'] ?? '').toString().toLowerCase();
      final address = (entry['address'] ?? '').toString().toLowerCase();
      final tags = (entry['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      final tagString = tags.join(' ').toLowerCase();
      final dateStr =
          (entry['date_time'] as String?)?.split('T').first.toLowerCase() ?? '';

      return title.contains(lowerQuery) ||
          description.contains(lowerQuery) ||
          address.contains(lowerQuery) ||
          tagString.contains(lowerQuery) ||
          dateStr.contains(lowerQuery);
    }).toList();
  }

  int get entriesCount => 
      getAllEntries().where((e) => e['sync_status'] != 'delete_pending').length;
}