import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:uuid/uuid.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? entry;
  final int? index;

  const AddEntryScreen({super.key, this.entry, this.index});

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _addressController = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _localPhotos = [];
  bool _saving = false;
  String? _selectedDateTime;
  String? _address;
  double? _latitude;
  double? _longitude;
  List<String> _existingPhotos = [];

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _title.text = widget.entry!['title'] ?? '';
      _desc.text = widget.entry!['description'] ?? '';
      _selectedDateTime =
          widget.entry!['date_time'] ?? DateTime.now().toIso8601String();
      _address = widget.entry!['address'] ?? '';
      _latitude = double.tryParse(widget.entry!['latitude']?.toString() ?? '');
      _longitude = double.tryParse(widget.entry!['longitude']?.toString() ?? '');
      _localPhotos.addAll(
        (widget.entry!['local_photos'] as List<dynamic>?)?.cast<String>() ?? [],
      );
      _existingPhotos.addAll(
        (widget.entry!['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      );
    } else {
      _selectedDateTime = DateTime.now().toIso8601String();
      _address = '';
      _latitude = null;
      _longitude = null;
    }
    _addressController.text = _address ?? '';
  }

  Future<void> _pick(ImageSource src) async {
    if (_localPhotos.length + _existingPhotos.length >= 5) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
        if (p == LocationPermission.deniedForever) {
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
      final address = await getAddressFromLatLong(pos.latitude, pos.longitude);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _address = address;
        _addressController.text = address;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location error: $e')));
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime != null
          ? DateTime.parse(_selectedDateTime!)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDateTime != null
              ? DateTime.parse(_selectedDateTime!)
              : DateTime.now(),
        ),
      );
      if (pickedTime != null) {
        final combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _selectedDateTime = combinedDateTime.toIso8601String();
        });
      }
    }
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    if (userId == 'anonymous') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login required to sync')));
      return;
    }
    final id = widget.entry != null ? widget.entry!['id'] : const Uuid().v4();
    final Map<String, dynamic> entry = {
      'id': id,
      'user_id': userId,
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'local_photos': _localPhotos,
      'photos': _existingPhotos,
      'tags':
          (widget.entry != null
              ? (widget.entry!['tags'] as List<dynamic>?)?.cast<String>()
              : <String>[]) ??
          [],
      'date_time': _selectedDateTime,
      'latitude': _latitude,
      'longitude': _longitude,
      'address': _address,
      'synced': false,
    };

    final files = _localPhotos.map((p) => File(p)).toList();
    setState(() => _saving = true);
    try {
      if (widget.entry != null && widget.index != null) {
        await ref
            .read(entriesNotifierProvider.notifier)
            .updateEntry(
              widget.index!,
              entry,
              images: files,
              existingPhotos: _existingPhotos,
            );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry updated successfully')),
          );
        }
      } else {
        await ref
            .read(entriesNotifierProvider.notifier)
            .addEntry(entry, images: files);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry saved successfully')),
          );
        }
      }
    } catch (e) {
      String errorMessage = widget.entry != null
          ? 'Error updating entry: $e'
          : 'Error saving entry: $e';
      if (e.toString().contains('Billing not enabled')) {
        errorMessage =
            'Image tagging failed: Enable billing for Google Cloud Vision API at https://console.developers.google.com/billing/enable?project=695801669377';
      } else if (e.toString().contains('User not authenticated')) {
        errorMessage = 'Please log in to save or update your entry.';
      } else if (e.toString().contains('Failed to save entry') ||
          e.toString().contains('Failed to update entry')) {
        errorMessage =
            'Failed to save to Supabase. Check your connection or database settings.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.entry != null ? 'Edit Journey' : 'New Journey',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            fontFamily: 'Roboto',
          ),
        ),
        actions: [
          if (!_saving)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _save,
            ),
        ],
        elevation: 6,
        shadowColor: Colors.black26,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFEAF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: 'Journey Title',
                      labelStyle: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _desc,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF34495E),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF3498DB),
                  ),
                  title: Text(
                    _selectedDateTime != null
                        ? DateTime.parse(
                            _selectedDateTime!,
                          ).toLocal().toString().split('.')[0]
                        : 'Select Date & Time',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  trailing: const Icon(Icons.edit, color: Color(0xFF3498DB)),
                  onTap: _selectDateTime,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF3498DB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText:
                                'Location (e.g., City, Latitude,Longitude)',
                            labelStyle: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            _address = value;
                            _latitude = null;
                            _longitude = null;
                          },
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF34495E),
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.my_location,
                          color: Color(0xFF3498DB),
                        ),
                        onPressed: _getLocation,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo, size: 20),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_localPhotos.isNotEmpty || _existingPhotos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _localPhotos.length + _existingPhotos.length,
                  itemBuilder: (context, index) {
                    final isLocal = index < _localPhotos.length;
                    final photo = isLocal
                        ? _localPhotos[index]
                        : _existingPhotos[index - _localPhotos.length];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isLocal
                              ? Image.file(
                                  File(photo),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: photo,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.broken_image, size: 40),
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isLocal) {
                                  _localPhotos.removeAt(index);
                                } else {
                                  _existingPhotos.removeAt(
                                    index - _localPhotos.length,
                                  );
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : widget.entry != null
                        ? 'Update Journey'
                        : 'Save Journey',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    elevation: 6,
                    shadowColor: Colors.green[200],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
} 