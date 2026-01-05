import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/theme.dart';

class VerificationRequestScreen extends StatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  State<VerificationRequestScreen> createState() => _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  File? _imageFile;
  bool _isUploading = false;
  bool _isLoadingStatus = true;
  
  // 'none', 'pending', 'verified', 'rejected'
  String _currentStatus = 'none';
  
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Check Profile Status first (Source of Truth)
      final profile = await supabase
          .from('profiles')
          .select('monetization_status, is_verified')
          .eq('auth_user_id', uid)
          .single();
      
      if (mounted) {
        setState(() {
          if (profile['is_verified'] == true) {
            _currentStatus = 'verified';
          } else {
            _currentStatus = profile['monetization_status'] ?? 'none';
            // Default to 'none' if it's 'locked' so they can apply
            if (_currentStatus == 'locked') _currentStatus = 'none';
          }
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

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
      
      // 2. Get Public URL
      final imageUrl = supabase.storage.from('verifications').getPublicUrl(path);
      
      // 3. Create Request Record in Database
      // Note: Triggers should update profile status to 'pending' automatically
      await supabase.from('verification_requests').insert({
        'user_id': uid,
        'id_document_url': imageUrl,
        'status': 'pending',
      });
      
      // 4. Force update local profile status to pending for immediate UI feedback
      await supabase.from('profiles').update({'monetization_status': 'pending'}).eq('auth_user_id', uid);

      if (mounted) {
        // --- THE NEXT STEP IN THE SEQUENCE ---
        context.push('/setup/bank');
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
      body: _isLoadingStatus 
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // --- SCENARIO 1: PENDING ---
    if (_currentStatus == 'pending') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Application Under Review',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We have received your ID and our team is reviewing it. This usually takes 24-48 hours.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    // --- SCENARIO 2: VERIFIED ---
    if (_currentStatus == 'verified') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'You are Verified!',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account is fully verified and monetized. Keep creating!',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/monetization'),
                child: const Text('Go to Revenue Studio'),
              ),
            ],
          ),
        ),
      );
    }

    // --- SCENARIO 3: REJECTED (Show Reason + Upload) ---
    // (We treat Rejected similarly to 'none', but with a warning message)
    
    // --- SCENARIO 4: NONE (Show Form) ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStatus == 'rejected')
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your previous application was not approved. Please ensure your ID is clear and valid.',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            'Step 1 of 2: Identity',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
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
                  : const Text('Next: Bank Details'),
            ),
          ),
        ],
      ),
    );
  }
}
