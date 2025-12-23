import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xprex/screens/main_shell.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/providers/upload_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});
  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _picker = ImagePicker();
  final _authService = AuthService();

  File? _videoFile; // We store the File directly now
  VideoPlayerController? _playerController;
  final List<String> _tags = [];
  
  // Categories Logic
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    // ⚡ AUTO-LAUNCH GALLERY ON OPEN ⚡
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickVideo();
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

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), 
    );

    if (video == null) {
      // User cancelled picker -> Go back to Feed
      if (mounted) setMainTabIndex(0); 
      return;
    }

    final file = File(video.path);
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    
    final duration = controller.value.duration.inSeconds;
    final sizeInMb = file.lengthSync() / (1024 * 1024);

    // --- THE BOUNCER ---
    if (duration > 61) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             backgroundColor: Colors.red,
             content: Text('Video is ${duration}s. Max 60s allowed.'),
             duration: const Duration(seconds: 4),
           ),
         );
         // Failed -> Go back to Feed (or try again)
         setMainTabIndex(0);
       }
       await controller.dispose();
       return;
    }

    if (sizeInMb > 500) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large (>500MB)')));
         setMainTabIndex(0);
       }
       await controller.dispose();
       return;
    }

    // Success! Show the Form
    setState(() {
      _videoFile = file;
      _playerController = controller;
      _playerController!.setLooping(true);
      _playerController!.play();
    });
  }

  Future<void> _handlePost() async {
    if (_videoFile == null || _titleController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    
    final user = _authService.currentUser;
    if (user == null) return;

    // Trigger Upload
    ref.read(uploadProvider.notifier).startUpload(
      videoFile: _videoFile!, 
      title: _titleController.text.trim(), 
      description: _descController.text.trim(), 
      tags: _tags, 
      userId: user.id, 
      categoryId: _selectedCategoryId!,
      durationSeconds: _playerController?.value.duration.inSeconds ?? 0,
    );

    // Clear and Leave
    _playerController?.pause();
    setState(() {
      _videoFile = null;
    });
    setMainTabIndex(0); // Back to Feed
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posting video...')));
  }

  // Help Link
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
    // If no video selected yet (and not picking), show empty or loading
    if (_videoFile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Details'),
        actions: [
            TextButton(
              onPressed: _handlePost,
              child: const Text("POST", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- ROW: Preview + Title ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiny Preview
                  Container(
                    width: 100, height: 150,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                    child: _playerController != null && _playerController!.value.isInitialized
                       ? ClipRRect(borderRadius: BorderRadius.circular(8), child: VideoPlayer(_playerController!))
                       : const Center(child: Icon(Icons.videocam)),
                  ),
                  const SizedBox(width: 16),
                  // Title Input
                  Expanded(
                    child: Column(
                      children: [
                         TextField(
                           controller: _titleController,
                           decoration: const InputDecoration(hintText: 'Write a catchy title...', border: InputBorder.none),
                           maxLines: 3,
                         ),
                      ],
                    ),
                  )
                ],
              ),
              const Divider(height: 32),

              // --- CATEGORY ---
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category (Required)', border: OutlineInputBorder()),
                value: _selectedCategoryId,
                items: _categories.map((cat) => DropdownMenuItem<int>(
                  value: cat['id'] as int,
                  child: Text(cat['name']),
                )).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 16),

              // --- TAGS ---
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Tags (Optional)',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _addTag(_tagController.text)),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),
              if (_tags.isNotEmpty) Wrap(children: _tags.map((t) => Chip(label: Text('#$t'), onDeleted: () => setState(() => _tags.remove(t)))).toList()),
              
              const SizedBox(height: 20),
              // Help Text
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
