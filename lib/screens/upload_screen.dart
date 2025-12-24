import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/providers/upload_provider.dart';
// IMPORT FEED SCREEN TO ACCESS THE KEY PROVIDER
import 'package:xprex/screens/feed_screen.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final File videoFile;
  const UploadScreen({super.key, required this.videoFile});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _authService = AuthService();

  VideoPlayerController? _playerController;
  final List<String> _tags = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

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
      debugPrint('Error fetching categories: $e');
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _handlePost() async {
    if (_titleController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a Title and Category')));
      return;
    }
    
    final user = _authService.currentUser;
    if (user == null) return;

    // --- NUCLEAR FIX: HARD RESET THE FEED ---
    // 1. Invalidate the data (fetch new videos)
    ref.invalidate(feedVideosProvider);
    // 2. Increment the Key (Force PageView Rebuild to kill blank screen)
    ref.read(feedRefreshKeyProvider.notifier).state++;

    // Trigger Upload
    ref.read(uploadProvider.notifier).startUpload(
      videoFile: widget.videoFile, 
      title: _titleController.text.trim(), 
      description: _descController.text.trim(), 
      tags: _tags, 
      userId: user.id, 
      categoryId: _selectedCategoryId!,
      durationSeconds: _playerController?.value.duration.inSeconds ?? 0,
    );

    _playerController?.pause();
    if (mounted) {
      Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posting video...')));
    }
  }

  Future<void> _launchHelp() async {
    final Uri url = Uri.parse('https://creator-guide.pages.dev');
    if (!await launchUrl(url)) debugPrint("Could not launch guide");
  }

  void _addTag(String value) {
    if (value.isNotEmpty && _tags.length < 5) {
      setState(() { _tags.add(value.trim()); _tagController.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Details'),
        actions: [
            TextButton(
              onPressed: (_playerController != null && _playerController!.value.isInitialized) ? _handlePost : null,
              child: const Text("POST", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100, height: 150,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                    child: _playerController != null && _playerController!.value.isInitialized
                       ? ClipRRect(borderRadius: BorderRadius.circular(8), child: VideoPlayer(_playerController!))
                       : const Center(child: CircularProgressIndicator()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'Write a catchy title...', border: InputBorder.none),
                      maxLines: 3,
                    ),
                  )
                ],
              ),
              const Divider(height: 32),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category (Required)', border: OutlineInputBorder()),
                value: _selectedCategoryId,
                items: _categories.map((cat) => DropdownMenuItem<int>(
                  value: cat['id'] as int,
                  child: Text(cat['name']),
                )).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                hint: _isLoadingCategories ? const Text("Loading...") : const Text("Select Category"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Tags (Optional)',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _addTag(_tagController.text)),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),
              if (_tags.isNotEmpty) Wrap(spacing: 8, children: _tags.map((t) => Chip(label: Text('#$t'), onDeleted: () => setState(() => _tags.remove(t)))).toList()),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _launchHelp,
                child: const Text("💡 Tips for going viral", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
