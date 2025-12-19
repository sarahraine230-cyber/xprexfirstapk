import 'package:flutter/material.dart';
import 'package:xprex/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Mock State
  bool _likes = true;
  bool _comments = true;
  bool _follows = true;
  bool _mentions = true;
  bool _news = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: AppSpacing.paddingMd,
        children: [
          _buildSwitch('Likes', 'Notify me when someone likes my videos', _likes, (v) => setState(() => _likes = v)),
          _buildSwitch('Comments', 'Notify me on new comments', _comments, (v) => setState(() => _comments = v)),
          _buildSwitch('New Followers', 'Notify me when I get a new follower', _follows, (v) => setState(() => _follows = v)),
          _buildSwitch('Mentions', 'Notify me when I am mentioned', _mentions, (v) => setState(() => _mentions = v)),
          const Divider(height: 32),
          _buildSwitch('Product Updates', 'News about XpreX features', _news, (v) => setState(() => _news = v)),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
