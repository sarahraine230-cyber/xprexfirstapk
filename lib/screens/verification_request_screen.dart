import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart'; // Ensure you have this
import 'package:xprex/theme.dart';

class VerificationRequestScreen extends StatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  State<VerificationRequestScreen> createState() => _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  File? _imageFile;
  bool _isUploading = false;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submitRequest() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Upload Image to Supabase Storage
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '$uid-verification.$fileExt';
      final path = 'verifications/$fileName';

      await supabase.storage.from('verifications').upload(
        path,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      // 2. Get Public URL (or just save path if bucket is private)
      final imageUrl = supabase.storage.from('verifications').getPublicUrl(path);

      // 3. Create Request Record in Database
      await supabase.from('verification_requests').insert({
        'user_id': uid,
        'id_document_url': imageUrl,
        'status': 'pending',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Request Sent'),
            content: const Text('We have received your verification request. Our team will review it within 24-48 hours.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close Dialog
                  Navigator.of(context).pop(); // Go Back
                },
                child: const Text('Done'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Request Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get Verified',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a clear photo of your Government ID (Driver\'s License, NIN, or Passport) to confirm your identity.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            
            // Image Picker Area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  image: _imageFile != null 
                      ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('Tap to upload ID', style: theme.textTheme.titleMedium),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (_imageFile != null)
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage, 
                  icon: const Icon(Icons.refresh), 
                  label: const Text('Change Photo')
                ),
              ),

            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: (_imageFile == null || _isUploading) ? null : _submitRequest,
                child: _isUploading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
