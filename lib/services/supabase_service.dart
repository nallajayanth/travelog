import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;
  final String bucket = 'journal-photos';
  final String clarifaiApiKey =
      'YOUR_CLARIFAI_API_KEY'; // Replace or leave empty

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
        print(
          'Binary upload failed: $binaryError - Check bucket policies/RLS in Supabase',
        );
        rethrow; // Propagate error
      }
    }
  }

  Future<List<String>> getTagsForImage(String imageUrl) async {
    if (clarifaiApiKey == 'YOUR_CLARIFAI_API_KEY' || clarifaiApiKey.isEmpty) {
      print('Clarifai key not set, skipping tags');
      return [];
    }
    try {
      final response = await http.post(
        Uri.parse('https://api.clarifai.com/v2/models/general-v1.3/outputs'),
        headers: {
          'Authorization': 'Key $clarifaiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': [
            {
              'data': {
                'image': {'url': imageUrl},
              },
            },
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final concepts = data['outputs'][0]['data']['concepts'] as List;
        return concepts.take(5).map((c) => c['name'] as String).toList();
      } else {
        print('Clarifai error: ${response.statusCode} ${response.body}');
      }
      return [];
    } catch (e) {
      print('Tagging error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> insertEntry(Map<String, dynamic> entry) async {
    final photos = entry['photos'] as List<String>? ?? [];
    final allTags = <String>[];
    for (final url in photos) {
      final tags = await getTagsForImage(url);
      allTags.addAll(tags);
    }
    entry['tags'] = allTags.toSet().toList().take(5).toList();

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
}
