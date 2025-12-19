import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart'; // NEW: The Compression Engine
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/main_shell.dart';
import 'package:xprex/theme.dart'; // Ensure theme is imported

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _videoService = VideoService();
  final _authService = AuthService();
  final _profileService = ProfileService();
  
  XFile? _pickedVideo;
  VideoPlayerController? _playerController;
  
  // State
  bool _isProcessing = false;
  String _statusMessage = ''; // "Compressing...", "Uploading..."
  double _progress = 0.0;
  String? _error;
  
  // Tags
  List<String> _selectedTags = [];

  // Compression Subscription
  Subscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Listen to compression progress
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      if (_isProcessing && _statusMessage.contains('Compressing')) {
        setState(() {
          _progress = progress / 100;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _playerController?.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      setState(() => _error = 'Upload requires a mobile device');
      return;
    }
    try {
      final xfile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      if (xfile == null) return;

      _playerController?.dispose();
      final controller = VideoPlayerController.file(File(xfile.path));
      await controller.initialize();
      
      setState(() {
        _pickedVideo = xfile;
        _playerController = controller;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick video: $e');
    }
  }

  Future<void> _upload() async {
    if (_pickedVideo == null) {
      setState(() => _error = 'Please select a video to upload');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }
    if (_authService.currentUserId == null) {
      setState(() => _error = 'You must be signed in to upload');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparing...';
      _progress = 0.0;
      _error = null;
    });

    final userId = _authService.currentUserId!;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // 0) Ensure Profile
      try {
        final email = _authService.currentUser?.email ?? '';
        await _profileService.ensureProfileExists(authUserId: userId, email: email);
      } catch (e) {
        debugPrint('⚠️ Profile check warning: $e');
      }

      // 1) COMPRESSION STEP (The Magic Fix)
      setState(() => _statusMessage = 'Compressing video...');
      debugPrint('🔨 Starting Compression...');
      
      final MediaInfo? compressedMedia = await VideoCompress.compressVideo(
        _pickedVideo!.path,
        quality: VideoQuality.MediumQuality, // Good balance: 720p/1080p optimized
        deleteOrigin: false, 
        includeAudio: true,
      );

      if (compressedMedia == null || compressedMedia.file == null) {
        throw Exception('Compression failed');
      }

      final File fileToUpload = compressedMedia.file!;
      final int durationMs = compressedMedia.duration?.toInt() ?? 0;
      debugPrint('✅ Compression done. New size: ${(fileToUpload.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');

      // 2) Generate Thumbnail (From compressed file)
      setState(() => _statusMessage = 'Generating thumbnail...');
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: fileToUpload.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
      );
      if (thumbBytes == null) throw Exception('Failed to generate thumbnail');

      // 3) Upload Video to Supabase
      setState(() {
        _statusMessage = 'Uploading video...';
        _progress = 0.0; 
      });

      final String storagePath = await _storage.uploadVideoWithProgress(
        userId: userId,
        timestamp: timestamp,
        file: fileToUpload,
        onProgress: (sent, total) {
          final fraction = total > 0 ? sent / total : 0.0;
          if (mounted) setState(() => _progress = fraction);
        },
      );

      // 4) Upload Thumbnail
      setState(() => _statusMessage = 'Finalizing...');
      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: userId,
        timestamp: timestamp,
        bytes: thumbBytes,
      );

      // 5) Save to Database
      await _videoService.createVideo(
        authorAuthUserId: userId,
        storagePath: storagePath,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        coverImageUrl: thumbnailUrl,
        duration: (durationMs / 1000).ceil(),
        tags: _selectedTags,
      );

      // Clean up compressed cache
      await VideoCompress.deleteAllCache();

      if (!mounted) return;
      
      // Refresh feed
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        container.invalidate(feedVideosProvider);
      } catch (e) {
        debugPrint('⚠️ Provider refresh warning: $e');
      }

      setMainTabIndex(0); // Jump to Feed
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload complete!')));

      // Reset
      setState(() {
        _pickedVideo = null;
        _playerController?.dispose();
        _playerController = null;
        _titleController.clear();
        _descController.clear();
        _selectedTags = [];
        _isProcessing = false;
        _progress = 0.0;
      });

    } catch (e) {
      debugPrint('❌ Upload error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (kIsWeb) {
      return const Scaffold(body: Center(child: Text("Mobile only")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PREVIEW AREA
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _playerController != null && _playerController!.value.isInitialized
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _playerController!.value.size.width,
                              height: _playerController!.value.size.height,
                              child: VideoPlayer(_playerController!),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: IconButton(
                              icon: Icon(
                                _playerController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                                color: Colors.white,
                                size: 48,
                              ),
                              onPressed: _isProcessing
                                  ? null
                                  : () async {
                                      if (_playerController!.value.isPlaying) {
                                        await _playerController!.pause();
                                      } else {
                                        await _playerController!.play();
                                      }
                                      setState(() {});
                                    },
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined, size: 48, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _isProcessing ? null : _pickVideo,
                              child: const Text('Select from Gallery'),
                            ),
                          ],
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),
        
              // INPUT FIELDS
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                enabled: !_isProcessing,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                textInputAction: TextInputAction.done,
                maxLines: 3,
                maxLength: 2200,
                enabled: !_isProcessing,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              
              // TAGS
              TagInputWidget(
                maxTags: 5,
                onChanged: (tags) => _selectedTags = tags,
              ),
              const SizedBox(height: 24),
        
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
        
              // UPLOAD BUTTON / PROGRESS
              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _upload,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Post Video'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TAG INPUT WIDGET ---
class TagInputWidget extends StatefulWidget {
  final ValueChanged<List<String>> onChanged;
  final int maxTags;
  const TagInputWidget({super.key, required this.onChanged, this.maxTags = 5});

  @override
  State<TagInputWidget> createState() => _TagInputWidgetState();
}

class _TagInputWidgetState extends State<TagInputWidget> {
  final _controller = TextEditingController();
  final List<String> _tags = [];

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < widget.maxTags) {
      setState(() {
        _tags.add(tag);
      });
      widget.onChanged(_tags);
      _controller.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onChanged(_tags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: _tags.length < widget.maxTags,
          decoration: InputDecoration(
            labelText: _tags.length < widget.maxTags ? 'Tags (Optional)' : 'Max tags reached',
            hintText: 'Add tag (e.g. comedy, dance)',
            prefixIcon: const Icon(Icons.tag),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(_controller.text),
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: _addTag,
        ),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                backgroundColor: theme.colorScheme.secondaryContainer,
                labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
      ],
    );
  }
}
