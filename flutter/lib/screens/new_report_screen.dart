import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../models/report.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _descCtrl = TextEditingController();
  String _selectedType = 'street_light';
  File? _photo;
  Position? _position;
  bool _loadingGps = false;
  bool _submitting = false;
  String? _error;

  final _types = [
    ('street_light', 'Street Light', Icons.lightbulb_outline),
    ('road_damage', 'Road Damage', Icons.construction),
    ('hazard', 'Hazard', Icons.warning_amber_outlined),
    ('announcement', 'Announcement', Icons.campaign_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() {
      _loadingGps = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied)
          throw Exception('Location permission denied');
      }
      if (perm == LocationPermission.deniedForever)
        throw Exception('Location permission permanently denied');

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
      });
    } catch (e) {
      setState(() {
        _error = 'GPS: ${e.toString()}';
      });
    } finally {
      if (mounted)
        setState(() {
          _loadingGps = false;
        });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 70, maxWidth: 1280);
    if (picked != null)
      setState(() {
        _photo = File(picked.path);
      });
  }

  Future<void> _submit() async {
    if (_position == null) {
      setState(() {
        _error = 'Waiting for GPS location...';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await SupabaseService.submitReport(
        type: _selectedType,
        lat: _position!.latitude,
        lng: _position!.longitude,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photo: _photo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report submitted!'), backgroundColor: Colors.teal),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // If offline, cache it locally
      final offlineReport = OfflineReport(
        localId: const Uuid().v4(),
        type: _selectedType,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        lat: _position!.latitude,
        lng: _position!.longitude,
        localPhotoPath: _photo?.path,
        createdAt: DateTime.now(),
      );
      SupabaseService.cacheOfflineReport(offlineReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No internet. Report saved offline — will sync automatically.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted)
        setState(() {
          _submitting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Report'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Issue type
            const Text('Issue type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _selectedType == t.$1;
                return FilterChip(
                  avatar: Icon(t.$3, size: 16),
                  label: Text(t.$2),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedType = t.$1;
                  }),
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // GPS status
            Row(
              children: [
                const Text('Location: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                if (_loadingGps)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else if (_position != null)
                  Expanded(
                    child: Text(
                      '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.teal),
                    ),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Retry GPS'),
                    onPressed: _getLocation,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo
            const Text('Photo (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_photo!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _photo = null;
                }),
                child: const Text('Remove photo'),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Description
            const Text('Description (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the issue...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
