import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile? originalProfile; 

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
    _usernameController = TextEditingController(text: widget.originalProfile?.username ?? '');
    _displayNameController = TextEditingController(text: widget.originalProfile?.displayName ?? '');
    _bioController = TextEditingController(text: widget.originalProfile?.bio ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.originalProfile == null && !_ageConfirmed) {
      setState(() => _errorMessage = "You must confirm you are over 18.");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final authService = ref.read(authServiceProvider);
      final profileService = ref.read(profileServiceProvider);
      final storageService = StorageService();
      final uid = authService.currentUserId;
      if (uid == null) throw Exception("Not authenticated");
      
      // Check username uniqueness if changed
      if (widget.originalProfile?.username != _usernameController.text) {
        final available = await profileService.isUsernameAvailable(_usernameController.text);
        if (!available) {
          throw Exception("Username is already taken.");
        }
      }

      String? avatarUrl = widget.originalProfile?.avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await storageService.uploadAvatar(userId: uid, file: _avatarFile!);
      }

      if (widget.originalProfile == null) {
        // CREATE:
        final newProfile = UserProfile(
          id: uid, 
          authUserId: uid,
          email: authService.currentUser?.email ?? '',
          username: _usernameController.text,
          displayName: _displayNameController.text,
          bio: _bioController.text,
          avatarUrl: avatarUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await profileService.createProfile(newProfile);
      } else {
        // UPDATE:
        await profileService.updateProfile(
          uid, 
          {
            'username': _usernameController.text,
            'display_name': _displayNameController.text,
            'bio': _bioController.text,
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }
        );
      }

      if (mounted) {
        // Refresh local profile provider
        ref.invalidate(currentUserProfileProvider);
        
        // [PROTOCOL UPDATE] Handling Navigation & Feedback
        if (widget.originalProfile != null) {
          // EDIT MODE: Show success + Go back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            )
          );
          Navigator.of(context).pop(); 
        } else {
          // SETUP MODE: Go to Home
          context.go('/'); 
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.originalProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Setup Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Picker
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _avatarFile != null 
                      ? FileImage(_avatarFile!) 
                      : (widget.originalProfile?.avatarUrl != null 
                          ? NetworkImage(widget.originalProfile!.avatarUrl!) 
                          : null) as ImageProvider?,
                  child: (_avatarFile == null && widget.originalProfile?.avatarUrl == null)
                      ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 32),

              _buildPinterestField(
                label: "Username",
                controller: _usernameController,
                hint: "@username",
                validator: (val) {
                  if (val == null || val.isEmpty) return "Required";
                  if (val.length < 3) return "Too short";
                  return null;
                }
              ),
              const SizedBox(height: 20),

              _buildPinterestField(
                label: "Display Name",
                controller: _displayNameController,
                hint: "Your Name",
                validator: (val) => val == null || val.isEmpty ? "Required" : null
              ),
              const SizedBox(height: 20),

              _buildPinterestField(
                label: "Bio",
                controller: _bioController,
                hint: "Tell us about yourself...",
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              if (!isEditing) ...[
                CheckboxListTile(
                  title: const Text("I confirm I am 18 years or older"),
                  value: _ageConfirmed,
                  onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _onSubmit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Save Changes' : 'Complete Setup', style: const TextStyle(fontSize: 16)),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
