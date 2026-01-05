import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/theme.dart';

class VerificationPersonalInfoScreen extends StatefulWidget {
  const VerificationPersonalInfoScreen({super.key});

  @override
  State<VerificationPersonalInfoScreen> createState() => _VerificationPersonalInfoScreenState();
}

class _VerificationPersonalInfoScreenState extends State<VerificationPersonalInfoScreen> {
  final _fullNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await supabase.from('profiles').select().eq('auth_user_id', uid).single();
      if (mounted) {
        setState(() {
          _fullNameCtrl.text = data['full_name'] ?? '';
          _addressCtrl.text = data['address'] ?? '';
          _phoneCtrl.text = data['phone_number'] ?? '';
          _dobCtrl.text = data['date_of_birth'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAndContinue() async {
    if (_fullNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name')));
      return;
    }

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
        
        if (mounted) {
          // MOVE TO NEXT STEP: BANK DETAILS
          context.push('/setup/bank');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 3: Personal Info')),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us about yourself',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This information must match your Government ID for verification.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            
            _buildTextField(theme, 'Official Name', _fullNameCtrl, Icons.badge),
            const SizedBox(height: 16),
            _buildTextField(theme, 'Date of Birth (YYYY-MM-DD)', _dobCtrl, Icons.calendar_today),
            const SizedBox(height: 16),
            _buildTextField(theme, 'Phone Number', _phoneCtrl, Icons.phone),
            const SizedBox(height: 16),
            _buildTextField(theme, 'Residential Address', _addressCtrl, Icons.home),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Next: Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
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
