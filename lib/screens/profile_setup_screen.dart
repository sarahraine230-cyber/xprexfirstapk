import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  
  File? _avatarFile;
  bool _isLoading = false;
  bool _ageConfirmed = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker not supported in web preview. Please test on device.')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (pickedFile != null) {
        setState(() => _avatarFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_ageConfirmed) {
      setState(() => _errorMessage = 'You must confirm you are 18 or older');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final profileService = ref.read(profileServiceProvider);
      final storageService = StorageService();
      
      final userId = authService.currentUserId!;
      final userEmail = authService.currentUser!.email!;

      final isAvailable = await profileService.isUsernameAvailable(_usernameController.text.trim());
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Username already taken';
          _isLoading = false;
        });
        return;
      }

      String? avatarUrl;
      if (_avatarFile != null && !kIsWeb) {
        avatarUrl = await storageService.uploadAvatar(userId: userId, file: _avatarFile!);
      }

      await profileService.createProfile(
        authUserId: userId,
        email: userEmail,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        avatarUrl: avatarUrl,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(color: theme.colorScheme.primary, width: 2),
                    ),
                    child: _avatarFile != null
                        ? ClipOval(child: Image.file(_avatarFile!, fit: BoxFit.cover))
                        : Icon(Icons.add_a_photo, size: 40, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: Icon(Icons.edit),
                  label: Text('Choose Avatar'),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    helperText: 'Unique identifier for your profile',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Username is required';
                    if (value.length < 3) return 'Username must be at least 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return 'Only letters, numbers, and underscores';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    helperText: 'Your public name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Display name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Bio (optional)',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    helperText: 'Tell people about yourself',
                  ),
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _ageConfirmed,
                  onChanged: (value) => setState(() => _ageConfirmed = value ?? false),
                  title: Text('I confirm I am 18 years or older', style: theme.textTheme.bodyMedium),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _handleSetup,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
