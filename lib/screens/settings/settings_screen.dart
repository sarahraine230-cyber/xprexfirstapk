import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/screens/settings/account_screen.dart'; // We will create this next
import 'package:xprex/screens/settings/notifications_screen.dart'; // And this

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // GROUP 1: ACCOUNT
            _buildSectionHeader(theme, 'Account'),
            _buildSettingsTile(
              theme,
              icon: Icons.person_outline,
              title: 'Personal Information',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen(initialTab: 0)),
              ),
            ),
            _buildSettingsTile(
              theme,
              icon: Icons.lock_outline,
              title: 'Password & Security',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen(initialTab: 1)),
              ),
            ),
            _buildSettingsTile(
              theme,
              icon: Icons.manage_accounts_outlined,
              title: 'Account Management',
              subtitle: 'Deactivate or delete account',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen(initialTab: 2)),
              ),
            ),

            const SizedBox(height: 24),

            // GROUP 2: PREFERENCES
            _buildSectionHeader(theme, 'Preferences'),
            _buildSettingsTile(
              theme,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            // Easy win: Dark Mode toggle could go here in v1.1

            const SizedBox(height: 24),

            // GROUP 3: LEGAL & SUPPORT
            _buildSectionHeader(theme, 'Support & Legal'),
            _buildSettingsTile(
              theme,
              icon: Icons.help_outline,
              title: 'Help Center',
              onTap: () => _launchURL(context, 'https://xprex.vercel.app/help'),
            ),
            _buildSettingsTile(
              theme,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => _launchURL(context, 'https://xprex.vercel.app/privacy'),
            ),
            _buildSettingsTile(
              theme,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () => _launchURL(context, 'https://xprex.vercel.app/terms'),
            ),

            const SizedBox(height: 24),

            // GROUP 4: ACTIONS
            _buildSectionHeader(theme, 'Login'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout, color: theme.colorScheme.error),
              ),
              title: Text(
                'Log out', 
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text('You will need to sign in again to access your account.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),

            const SizedBox(height: 40),
            Text(
              'XpreX v1.0.0',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: theme.colorScheme.onSurface),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: theme.textTheme.bodySmall) : null,
      trailing: Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
