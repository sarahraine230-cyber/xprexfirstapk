import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/theme.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedBank;

  // Static list for MVP - We can make this dynamic later
  final List<String> _nigerianBanks = [
    'Access Bank',
    'GTBank',
    'Zenith Bank',
    'UBA',
    'First Bank',
    'Kuda Bank',
    'OPay',
    'PalmPay',
    'Fidelity Bank',
    'Stanbic IBTC',
    'Sterling Bank',
    'Union Bank',
    'Wema Bank',
    'Moniepoint',
  ];

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your bank')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final uid = supabase.auth.currentUser?.id;

    if (uid == null) return;

    try {
      // "Wizard of Oz" - We save it to the DB so the Admin can see it.
      await supabase.from('creator_bank_accounts').upsert({
        'user_id': uid,
        'bank_name': _selectedBank,
        'account_number': _accountNumberCtrl.text.trim(),
        'account_name': _accountNameCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        // Success! The "Wizard" logic is complete.
        // We pop until we are back at the monetization screen (which will now show the dashboard)
        // Or specific route if you prefer.
        if (context.canPop()) {
           context.pop(); // Pop Bank Screen
           // If we came from Verification, we might need to pop again or use go_router to refresh
           context.go('/monetization'); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.extension<NeonAccentTheme>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Text(
                'Get Paid.',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Link your Nigerian bank account to receive your Revenue Pool earnings.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // --- BANK DROPDOWN ---
              Text('Bank Name', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBank,
                    hint: Text('Select your bank', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    isExpanded: true,
                    dropdownColor: theme.colorScheme.surfaceContainerHighest,
                    icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
                    items: _nigerianBanks.map((bank) {
                      return DropdownMenuItem(
                        value: bank,
                        child: Text(bank, style: theme.textTheme.bodyLarge),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBank = val),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- ACCOUNT NUMBER ---
              Text('Account Number', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '0123456789',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  prefixIcon: Icon(Icons.numbers, color: theme.colorScheme.onSurfaceVariant),
                ),
                validator: (val) {
                  if (val == null || val.length != 10) return 'Enter a valid 10-digit account number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // --- ACCOUNT NAME ---
              Text('Account Name', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'e.g. Chukwudi Tochi',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.onSurfaceVariant),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Please enter the account name' : null,
              ),

              const SizedBox(height: 48),

              // --- ACTION BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveBankDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    elevation: 4,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2)
                        )
                      : const Text(
                          'Save & Finish',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Your details are encrypted and secure.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
