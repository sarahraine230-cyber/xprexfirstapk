import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart'; // ENABLED
import 'package:path/path.dart' as p;
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/main_shell.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController(); // Fixed controller name
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _videoService = VideoService();
  final _authService = AuthService();
  final _profileService = ProfileService();
  
  // Compression Subscription
  Subscription? _subscription;

  XFile? _pickedVideo;
  VideoPlayerController? _playerController;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // Tagging State
  final List<String> _tags = [];
  static const int _maxTags = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _playerController?.dispose();
    _subscription?.unsubscribe(); // Clean up compression listener
    VideoCompress.cancelCompression(); 
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _pickedVideo = video;
        _playerController = VideoPlayerController.file(File(video.path))
          ..initialize().then((_) {
            setState(() {});
            _playerController!.play();
            _playerController!.setLooping(true);
          });
      });
    }
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

  Future<void> _uploadVideo() async {
    if (_pickedVideo == null || _titleController.text.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // 1. GENERATE THUMBNAIL (From Original)
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: _pickedVideo!.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
      
      if (thumbBytes == null) throw Exception('Failed to generate thumbnail');
      
      // 2. COMPRESS VIDEO (The Optimization)
      debugPrint('⏳ Starting Compression...');
      
      // Listen to compression progress
      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        // We map compression (0-100) to the first 30% of our total progress bar
        setState(() {
          _uploadProgress = (progress / 100) * 0.30;
        });
        debugPrint('Compression: $progress%');
      });

      final MediaInfo? info = await VideoCompress.compressVideo(
        _pickedVideo!.path,
        quality: VideoQuality.MediumQuality, // Good balance (720p/1080p optimized)
        deleteOrigin: false, 
        includeAudio: true,
      );

      if (info == null || info.file == null) {
        throw Exception('Compression failed');
      }

      final File fileToUpload = info.file!;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      debugPrint('🚀 Starting Upload of ${fileToUpload.lengthSync()} bytes (Compressed)');

      // 3. UPLOAD VIDEO TO R2
      // We map upload progress to the remaining 70% (from 0.30 to 1.0)
      final String videoPath = await _storage.uploadVideoWithProgress(
        userId: user.id,
        timestamp: timestamp,
        file: fileToUpload,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              // Base 0.30 + (Percentage of Upload * 0.70)
              _uploadProgress = 0.30 + ((sent / total) * 0.70);
            });
          }
        },
      );

      // 4. UPLOAD THUMBNAIL TO R2
      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: user.id,
        timestamp: timestamp,
        bytes: thumbBytes,
      );

      // 5. SAVE METADATA TO SUPABASE
      await _videoService.createVideo(
        authorAuthUserId: user.id,
        storagePath: videoPath, // R2 Key
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverImageUrl: thumbnailUrl,
        duration: (_playerController!.value.duration.inSeconds),
        tags: _tags,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        // Clear cleanup cache
        await VideoCompress.deleteAllCache();
        
        // Navigate
        context.pushReplacement('/main'); 
      }
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      _subscription?.unsubscribe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isUploading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: _uploadProgress, 
                color: theme.colorScheme.primary,
                backgroundColor: Colors.grey[800],
              ),
              const SizedBox(height: 24),
              Text(
                _uploadProgress < 0.30 
                   ? 'Compressing Video...' 
                   : 'Uploading to Cloud...',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _pickedVideo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: _playerController?.value.aspectRatio ?? 16/9,
                            child: VideoPlayer(_playerController!),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to select video'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // TAGS INPUT
              TextField(
                controller: _tagController,
                enabled: _tags.length < _maxTags,
                decoration: InputDecoration(
                  labelText: _tags.length < _maxTags 
                      ? 'Tags (Optional)' 
                      : 'Max tags reached',
                  hintText: 'Add tag (e.g. comedy, dance)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTag(_tagController.text),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),
              const SizedBox(height: 8),
              
              // Chips Display
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
              
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${_tags.length}/$_maxTags tags',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _uploadVideo,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Upload Video'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
