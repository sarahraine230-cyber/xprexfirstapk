import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/providers/upload_provider.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/theme.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final File videoFile;
  const UploadScreen({super.key, required this.videoFile});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _captionController = TextEditingController();
  final _authService = AuthService();

  VideoPlayerController? _playerController;
  
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  
  // --- NEW STATE ---
  String _privacyLevel = 'public'; // 'public', 'followers', 'private'
  bool _allowComments = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); 
    _playerController = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _playerController!.setLooping(true);
        _playerController!.play();
      });
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');
      
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  void _insertText(String text) {
    final currentText = _captionController.text;
    final selection = _captionController.selection;

    if (selection.baseOffset >= 0) {
      final newText = currentText.replaceRange(selection.start, selection.end, text);
      _captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + text.length),
      );
    } else {
      _captionController.text += text;
    }
  }

  Future<void> _handlePost() async {
    if (_isLoadingCategories && _categories.isEmpty) {
       await Future.delayed(const Duration(seconds: 1));
    }

    final user = _authService.currentUser;
    if (user == null) return;

    final categoryId = _categories.isNotEmpty ? _categories.first['id'] as int : 1;

    ref.invalidate(feedVideosProvider);
    ref.read(feedRefreshKeyProvider.notifier).state++;

    ref.read(uploadProvider.notifier).startUpload(
      videoFile: widget.videoFile, 
      title: _captionController.text.trim().isEmpty ? "New Video" : _captionController.text.trim(), 
      description: _captionController.text.trim(),
      tags: [],
      userId: user.id, 
      categoryId: categoryId,
      durationSeconds: _playerController?.value.duration.inSeconds ?? 0,
      // Pass Settings
      privacyLevel: _privacyLevel,
      allowComments: _allowComments,
    );
    
    _playerController?.pause();
    if (mounted) {
      Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posting video...')));
    }
  }

  void _handleDrafts() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Drafts coming soon!")));
  }

  Future<void> _launchHelp() async {
    // [UPDATED] Points to the Partner Playbook
    final Uri url = Uri.parse('https://creators.getxprex.com/playbook');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       debugPrint("Could not launch guide");
    }
  }
  
  // Privacy Selector Sheet
  void _showPrivacyOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Everyone'),
            subtitle: const Text('Anyone on XpreX can watch'),
            trailing: _privacyLevel == 'public' ? const Icon(Icons.check, color: Colors.purple) : null,
            onTap: () {
              setState(() => _privacyLevel = 'public');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Followers'),
            subtitle: const Text('Only people who follow you'),
            trailing: _privacyLevel == 'followers' ? const Icon(Icons.check, color: Colors.purple) : null,
            onTap: () {
              setState(() => _privacyLevel = 'followers');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Only Me'),
            subtitle: const Text('Private video'),
            trailing: _privacyLevel == 'private' ? const Icon(Icons.check, color: Colors.purple) : null,
            onTap: () {
              setState(() => _privacyLevel = 'private');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getPrivacyLabel() {
    switch (_privacyLevel) {
      case 'followers': return 'Followers';
      case 'private': return 'Only Me';
      default: return 'Everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP AREA ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _captionController,
                              maxLines: 5,
                              minLines: 3,
                              decoration: const InputDecoration(
                                hintText: "Add a catchy title...",
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildShortcutButton(context, "# Hashtag", () => _insertText(" #")),
                                const SizedBox(width: 8),
                                _buildShortcutButton(context, "@ Mention", () => _insertText(" @")),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 85, 
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: _playerController != null && _playerController!.value.isInitialized
                            ? ClipRRect(
                               borderRadius: BorderRadius.circular(8), 
                               child: VideoPlayer(_playerController!)
                             )
                            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 40),

                  // --- SETTINGS LIST ---
                  
                  // 1. Privacy (Functional)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.public, color: Colors.grey.shade600),
                    title: const Text("Who can watch this video", style: TextStyle(fontSize: 15)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_getPrivacyLabel(), style: const TextStyle(color: Colors.grey)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                    onTap: _showPrivacyOptions,
                  ),

                  // 2. Comments (Functional)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.comment, color: Colors.grey.shade600),
                    title: const Text("Allow Comments", style: TextStyle(fontSize: 15)),
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _allowComments, 
                        onChanged: (v) => setState(() => _allowComments = v),
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  // 3. Downloads (HIDDEN as discussed)
                  
                  const SizedBox(height: 20),
                  
                  // --- PRO TIP (UPDATED) ---
                  GestureDetector(
                    onTap: _launchHelp,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.rocket_launch, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Growth Tip: Posting consistently helps you find your audience faster!", 
                              style: TextStyle(
                                fontSize: 13, 
                                color: theme.colorScheme.onSurfaceVariant
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM BAR ---
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDrafts,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_outlined, size: 20, color: theme.iconTheme.color),
                        const SizedBox(width: 8),
                        Text("Drafts", style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: (_playerController != null && _playerController!.value.isInitialized) 
                        ? _handlePost 
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text("Post", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
