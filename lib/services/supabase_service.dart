import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;
  final String bucket = 'journal-photos';

  Future<String> uploadPhoto(File file) async {
    final uuid = const Uuid().v4();
    final ext = file.path.split('.').last;
    final path = 'photos/$uuid.$ext';

    try {
      final response = await client.storage.from(bucket).upload(path, file);
      print('Upload successful: $response');
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Primary upload failed: $e - Trying binary fallback');
      try {
        final bytes = await file.readAsBytes();
        final binaryResponse = await client.storage
            .from(bucket)
            .uploadBinary(path, bytes);
        print('Binary upload successful: $binaryResponse');
        return client.storage.from(bucket).getPublicUrl(path);
      } catch (binaryError) {
        print('Binary upload failed: $binaryError - Check bucket policies/RLS');
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> insertEntry(Map<String, dynamic> entry) async {
    try {
      final res = await client
          .from('journal_entries')
          .insert(entry)
          .select()
          .maybeSingle();
      print('Insert response: $res');
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      print('Insert error: $e - Check table RLS/policies or schema');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchEntriesForUser(String userId) async {
    try {
      final res = await client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      print('Fetch response: $res');
      return res != null ? List<Map<String, dynamic>>.from(res) : [];
    } catch (e) {
      print('Fetch error: $e');
      return [];
    }
  }

  // in SupabaseService
  Future<Map<String, dynamic>?> updateEntry(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await client
          .from('journal_entries')
          .update(data)
          .eq('id', id)
          .select()
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      print('Update error: $e');
      return null;
    }
  }
}
