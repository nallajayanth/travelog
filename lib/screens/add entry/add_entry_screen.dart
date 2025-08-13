import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:uuid/uuid.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  const AddEntryScreen({super.key});
  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _localPhotos = [];
  bool _saving = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    _getLocation(); // Auto-fetch
  }

  Future<void> _pick(ImageSource src) async {
    if (_localPhotos.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max 5 photos allowed')));
      return;
    }
    final XFile? f = await _picker.pickImage(source: src, imageQuality: 80);
    if (f != null) setState(() => _localPhotos.add(f.path));
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services disabled. Enable in settings.'),
          ),
        );
        return;
      }

      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied) {
          print('Location permission denied');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
        if (p == LocationPermission.deniedForever) {
          print('Location permissions permanently denied');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions permanently denied. Open app settings.',
              ),
            ),
          );
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      print('Location fetched successfully: $_lat, $_lng');
    } catch (e) {
      print('Location fetch error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location error: $e')));
    }
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    if (userId == 'anonymous') {
      print('User not logged in, cannot sync');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login required to sync')));
    }
    final id = const Uuid().v4();
    final Map<String, dynamic> entry = {
      'id': id,
      'user_id': userId,
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'local_photos': _localPhotos,
      'photos': <String>[],
      'tags': <String>[],
      'date_time': DateTime.now().toIso8601String(),
      'latitude': _lat,
      'longitude': _lng,
      'synced': false,
    };

    final files = _localPhotos.map((p) => File(p)).toList();
    setState(() => _saving = true);
    await ref
        .read(entriesNotifierProvider.notifier)
        .addEntry(entry, images: files);
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Gallery'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Location'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_localPhotos.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _localPhotos
                    .map(
                      (p) => Image.file(
                        File(p),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Entry'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
