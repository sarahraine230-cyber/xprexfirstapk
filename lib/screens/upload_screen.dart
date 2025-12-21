import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:xprex/screens/main_shell.dart'; // To switch tabs
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/providers/upload_provider.dart'; // IMPORT PROVIDER

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

  XFile? _pickedVideo;
  VideoPlayerController? _playerController;
  
  final List<String> _tags = [];
  static const int _maxTags = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    // 500MB SAFETY LIMIT + 60s Duration
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), 
    );
    
    if (video != null) {
      final file = File(video.path);
      final sizeInMb = file.lengthSync() / (1024 * 1024);
      
      if (sizeInMb > 500) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Video too large (${sizeInMb.toStringAsFixed(0)}MB). Limit is 500MB.')),
           );
         }
         return;
      }

      _playerController?.dispose();
      setState(() {
        _pickedVideo = video;
      });

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      
      setState(() {
        _playerController = controller;
        _playerController!.setLooping(true);
        _playerController!.play();
      });
    }
  }

  void _togglePlayPause() {
    if (_playerController == null || !_playerController!.value.isInitialized) return;
    setState(() {
      _playerController!.value.isPlaying ? _playerController!.pause() : _playerController!.play();
    });
  }

  void _addTag(String value) {
    final tag = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < _maxTags) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _handlePost() async {
    if (_pickedVideo == null || _titleController.text.isEmpty) return;
    
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    // 1. Trigger Background Upload
    ref.read(uploadProvider.notifier).startUpload(
      videoFile: File(_pickedVideo!.path), 
      title: _titleController.text.trim(), 
      description: _descController.text.trim(), 
      tags: _tags, 
      userId: user.id, 
      durationSeconds: _playerController?.value.duration.inSeconds ?? 0,
    );

    // 2. Clear UI
    _playerController?.pause();
    setState(() {
      _pickedVideo = null;
      _playerController = null;
      _titleController.clear();
      _descController.clear();
      _tags.clear();
    });

    // 3. Navigate AWAY immediately (TikTok Style)
    // Switch to Feed (Index 0)
    setMainTabIndex(0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Posting video... Check progress below.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- V5 VERTICAL PREVIEW UI ---
              GestureDetector(
                onTap: _pickedVideo == null ? _pickVideo : _togglePlayPause,
                child: Container(
                  height: 400, // Fixed height for vertical look
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: _pickedVideo != null && _playerController != null && _playerController!.value.isInitialized
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: _playerController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_playerController!),
                                if (!_playerController!.value.isPlaying)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 48, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            const Text('Select Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Max 500MB • 60s', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Tags
              TextField(
                controller: _tagController,
                enabled: _tags.length < _maxTags,
                decoration: InputDecoration(
                  labelText: _tags.length < _maxTags ? 'Tags (Optional)' : 'Max tags reached',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _addTag(_tagController.text)),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),
              const SizedBox(height: 8),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _tags.map((t) => Chip(
                    label: Text('#$t'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeTag(t),
                  )).toList(),
                ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _pickedVideo == null ? null : _handlePost,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('POST NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
