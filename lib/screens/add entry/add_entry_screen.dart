import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
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
  late List<String> _displayPhotos;

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
      _longitude = double.tryParse(
        widget.entry!['longitude']?.toString() ?? '',
      );
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
    _displayPhotos = [..._localPhotos, ..._existingPhotos];
  }

  Future<void> _pick(ImageSource src) async {
    if (_displayPhotos.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max 5 photos allowed')));
      return;
    }
    final XFile? f = await _picker.pickImage(source: src, imageQuality: 80);
    if (f != null)
      setState(() {
        _displayPhotos.add(f.path);
      });
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
    _localPhotos.clear();
    _existingPhotos.clear();
    for (var photo in _displayPhotos) {
      if (photo.startsWith('http')) {
        _existingPhotos.add(photo);
      } else {
        _localPhotos.add(photo);
      }
    }
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

  void _reorderPhotos(int oldIndex, int newIndex) {
    if (newIndex > _displayPhotos.length) newIndex = _displayPhotos.length;
    if (oldIndex < newIndex) newIndex--;
    setState(() {
      final item = _displayPhotos.removeAt(oldIndex);
      _displayPhotos.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access current theme

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.entry != null ? 'Edit Journey' : 'New Journey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white, // Dynamic color
            fontFamily: 'Roboto',
          ),
        ),
        actions: [
          if (!_saving)
            IconButton(
              icon: Icon(Icons.save, color: Colors.white),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface.withOpacity(0.9),
              theme.colorScheme.background,
            ],
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
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: 'Journey Title',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
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
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _desc,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
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
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    _selectedDateTime != null
                        ? DateTime.parse(
                            _selectedDateTime!,
                          ).toLocal().toString().split('.')[0]
                        : 'Select Date & Time',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Icon(Icons.edit, color: theme.colorScheme.primary),
                  onTap: _selectDateTime,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'Location (e.g., City or Address)',
                            labelStyle: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                            border: InputBorder.none,
                          ),
                          controller: _addressController,
                          onChanged: (value) {
                            _address = value;
                            _latitude = null;
                            _longitude = null;
                          },
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.my_location,
                          color: theme.colorScheme.primary,
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
                        backgroundColor: Colors.lightBlue,
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
                        backgroundColor: Colors.lightBlue,
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
              if (_displayPhotos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _displayPhotos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _displayPhotos.length) {
                      return DragTarget<int>(
                        builder: (context, candidateData, rejectedData) {
                          return SizedBox(
                            width: double.infinity,
                            height: 100, // Match approximate image height
                            child: Container(color: Colors.transparent),
                          );
                        },
                        onAccept: (oldIndex) {
                          _reorderPhotos(oldIndex, index);
                        },
                      );
                    }
                    final photo = _displayPhotos[index];
                    final isLocal = !photo.startsWith('http');
                    return DragTarget<int>(
                      onAccept: (oldIndex) {
                        _reorderPhotos(oldIndex, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return LongPressDraggable<int>(
                          data: index,
                          feedback: Opacity(
                            opacity: 0.7,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: isLocal
                                  ? Image.file(
                                      File(photo),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: photo,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          child: Stack(
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
                                            Container(
                                              color: theme.colorScheme.surface
                                                  .withOpacity(0.2),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                            ),
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _displayPhotos.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: _saving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.save, size: 20),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : widget.entry != null
                        ? 'Update Journey'
                        : 'Save Journey',
                    style: TextStyle(fontSize: 16),
                  ),
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    elevation: 6,
                    shadowColor: theme.colorScheme.shadow,
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
