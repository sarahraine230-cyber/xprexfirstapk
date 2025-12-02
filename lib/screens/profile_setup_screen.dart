import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/models/user_profile.dart'; // Needed to accept existing profile
import 'package:xprex/theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile? originalProfile; // Optional: If provided, we are in "Edit Mode"

  const ProfileSetupScreen({super.key, this.originalProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  final _picker = ImagePicker();
  
  File? _avatarFile;
  bool _isLoading = false;
  bool _ageConfirmed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing, or start empty if creating
    _usernameController = TextEditingController(text: widget.originalProfile?.username ?? '');
    _displayNameController = TextEditingController(text: widget.originalProfile?.displayName ?? '');
    _bioController = TextEditingController(text: widget.originalProfile?.bio ?? '');
    
    // If editing, age is already confirmed implicitly
    if (widget.originalProfile != null) {
      _ageConfirmed = true;
    }
  }

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
        const SnackBar(content: Text('Image picker not supported in web preview.')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (pickedFile != null) {
        setState(() => _avatarFile = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
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
      final userEmail = authService.currentUser?.email ?? '';

      // Check username availability ONLY if it changed
      final newUsername = _usernameController.text.trim();
      if (widget.originalProfile?.username != newUsername) {
        final isAvailable = await profileService.isUsernameAvailable(newUsername);
        if (!isAvailable) {
          setState(() {
            _errorMessage = 'Username already taken';
            _isLoading = false;
          });
          return;
        }
      }

      // Handle Avatar Upload
      String? avatarUrl = widget.originalProfile?.avatarUrl;
      if (_avatarFile != null && !kIsWeb) {
        avatarUrl = await storageService.uploadAvatar(userId: userId, file: _avatarFile!);
      }

      if (widget.originalProfile == null) {
        // --- CREATE MODE ---
        await profileService.createProfile(
          authUserId: userId,
          email: userEmail,
          username: newUsername,
          displayName: _displayNameController.text.trim(),
          avatarUrl: avatarUrl,
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        );
        if (mounted) context.go('/'); // Go to Feed after create
      } else {
        // --- UPDATE MODE ---
        await profileService.updateProfile(
          authUserId: userId,
          username: newUsername,
          displayName: _displayNameController.text.trim(),
          avatarUrl: avatarUrl,
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        );
        // Refresh the provider so the Profile Screen updates immediately
        ref.invalidate(currentUserProfileProvider);
        if (mounted) Navigator.of(context).pop(); // Go back to Profile after edit
      }

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
    final isEditing = widget.originalProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Set Up Profile'),
        centerTitle: true,
        actions: [
          // Pinterest Style "Done" Button
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Avatar Section
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest,
                          image: _avatarFile != null
                              ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover)
                              : (widget.originalProfile?.avatarUrl != null
                                  ? DecorationImage(image: NetworkImage(widget.originalProfile!.avatarUrl!), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: (_avatarFile == null && widget.originalProfile?.avatarUrl == null)
                            ? Icon(Icons.add_a_photo, size: 32, color: theme.colorScheme.onSurfaceVariant)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // Pinterest style "Edit" label below image
                      Text('Edit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Fields
                _buildPinterestField(
                  label: 'Name',
                  controller: _displayNameController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                
                const SizedBox(height: 16),
                
                _buildPinterestField(
                  label: 'Username',
                  controller: _usernameController,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Username is required';
                    if (v.length < 3) return 'Min 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Alphanumeric only';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildPinterestField(
                  label: 'Bio',
                  controller: _bioController,
                  maxLines: 3,
                  hint: 'Write a short bio...',
                ),

                const SizedBox(height: 24),

                // Only show age checkbox if creating a new profile
                if (!isEditing) ...[
                  CheckboxListTile(
                    value: _ageConfirmed,
                    onChanged: (value) => setState(() => _ageConfirmed = value ?? false),
                    title: Text('I confirm I am 18 years or older', style: theme.textTheme.bodyMedium),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for cleaner UI
  Widget _buildPinterestField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
