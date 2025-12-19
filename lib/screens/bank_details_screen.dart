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
  
  bool _isSaving = false;
  bool _isFetching = true; // Start by loading data
  bool _isEditingMode = false; // Tracks if we are updating existing info
  String? _selectedBank;

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
  void initState() {
    super.initState();
    _fetchExistingDetails();
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  /// Check DB for existing bank details
  Future<void> _fetchExistingDetails() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await supabase
          .from('creator_bank_accounts')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _isEditingMode = true;
          _selectedBank = data['bank_name'];
          _accountNumberCtrl.text = data['account_number'] ?? '';
          _accountNameCtrl.text = data['account_name'] ?? '';
          
          // Safety check: ensure selected bank is in our list, else reset
          if (!_nigerianBanks.contains(_selectedBank)) {
            _selectedBank = null;
          }
        });
      }
    } catch (e) {
      // Fail silently on fetch errors, just show empty form
      debugPrint('Error fetching bank details: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your bank')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final uid = supabase.auth.currentUser?.id;

    if (uid == null) return;

    try {
      // Upsert handles both Insert (New) and Update (Edit)
      await supabase.from('creator_bank_accounts').upsert({
        'user_id': uid,
        'bank_name': _selectedBank,
        'account_number': _accountNumberCtrl.text.trim(),
        'account_name': _accountNameCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout details saved successfully')),
        );
        if (context.canPop()) {
           context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. LOADING STATE (While checking DB)
    if (_isFetching) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payout Setup')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditingMode ? 'Manage Payouts' : 'Payout Setup'),
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
              // Dynamic text based on mode
              Text(
                _isEditingMode ? 'Your Connected Account' : 'Get Paid.',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 32, // Slightly smaller than displayMedium default
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isEditingMode 
                    ? 'Update your banking details below. Future payouts will be sent to this account.'
                    : 'Link your Nigerian bank account to receive your Revenue Pool earnings.',
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
                  onPressed: _isSaving ? null : _saveBankDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    elevation: 4,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2)
                        )
                      : Text(
                          _isEditingMode ? 'Update Details' : 'Save & Finish',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
