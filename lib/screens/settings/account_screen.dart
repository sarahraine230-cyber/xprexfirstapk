import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

class AccountScreen extends StatefulWidget {
  final int initialTab;
  const AccountScreen({super.key, this.initialTab = 0});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Form Controllers
  final _fullNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final data = await supabase.from('profiles').select().eq('auth_user_id', uid).single();
    setState(() {
      _fullNameCtrl.text = data['full_name'] ?? '';
      _addressCtrl.text = data['address'] ?? '';
      _phoneCtrl.text = data['phone_number'] ?? '';
      _dobCtrl.text = data['date_of_birth'] ?? '';
    });
  }

  Future<void> _savePersonalInfo() async {
    setState(() => _isLoading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        await supabase.from('profiles').update({
          'full_name': _fullNameCtrl.text,
          'address': _addressCtrl.text,
          'phone_number': _phoneCtrl.text,
          'date_of_birth': _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
        }).eq('auth_user_id', uid);
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return;
    
    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Email Sent'),
            content: Text('A password reset link has been sent to $email'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      // Call the secure Database Function
      await supabase.rpc('delete_own_account');
      
      // Navigate to login
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Security'),
            Tab(text: 'Manage'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. PERSONAL INFO TAB
          SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                _buildTextField(theme, 'Official Name', _fullNameCtrl, Icons.badge),
                const SizedBox(height: 16),
                _buildTextField(theme, 'Date of Birth (YYYY-MM-DD)', _dobCtrl, Icons.calendar_today),
                const SizedBox(height: 16),
                _buildTextField(theme, 'Phone Number', _phoneCtrl, Icons.phone),
                const SizedBox(height: 16),
                _buildTextField(theme, 'Residential Address', _addressCtrl, Icons.home),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _savePersonalInfo,
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),

          // 2. SECURITY TAB
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                const Icon(Icons.lock_reset, size: 64, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'Change Password',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'We will send a secure link to your email address to reset your password.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Send Reset Link'),
                  ),
                ),
              ],
            ),
          ),

          // 3. MANAGE (DANGER ZONE)
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Danger Zone', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 16),
                Text('Delete Account', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Permanently delete your account and all your content. This action cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Account?'),
                          content: const Text('Are you absolutely sure? All your videos, earnings, and followers will be lost forever.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteAccount();
                              }, 
                              child: const Text('Delete Forever')
                            ),
                          ],
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Delete Account'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }
}
