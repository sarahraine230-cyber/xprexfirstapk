import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/auth_service.dart';
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
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _videoService = VideoService();
  final _authService = AuthService();
  // Using video_compress (null-safe) instead of flutter_video_compress

  XFile? _pickedVideo;
  VideoPlayerController? _playerController;
  bool _isUploading = false;
  double _progress = 0.0; // 0..1 visual step progress
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _playerController?.dispose();
    VideoCompress.dispose();
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
    if (kIsWeb) {
      setState(() => _error = 'Upload requires a mobile device');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0.06;
      _error = null;
    });

    final userId = _authService.currentUserId!;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // 1) Compress (mp4) using flutter_video_compress
      _setProgress(0.2);
      final info = await VideoCompress.compressVideo(
        _pickedVideo!.path,
        quality: VideoQuality.MediumQuality,
      );
      if (info == null || info.path == null) {
        throw Exception('Compression failed.');
      }
      final File compressedFile = File(info.path!);
      final int durationMs = (info.duration?.toInt() ?? 0);
      _setProgress(0.45);

      // 2) Thumbnail (JPEG bytes) using video_thumbnail
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: compressedFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
      );
      if (thumbBytes == null) {
        throw Exception('Failed to generate thumbnail');
      }
      _setProgress(0.62);

      // 3) Upload to Supabase Storage
      final String videoUrl = await _storage.uploadVideo(
        userId: userId,
        timestamp: timestamp,
        file: compressedFile,
      );
      _setProgress(0.85);

      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: userId,
        timestamp: timestamp,
        bytes: thumbBytes,
      );
      _setProgress(0.92);

      // 4) Insert into videos table
      await _videoService.createVideo(
        authorAuthUserId: userId,
        storagePath: videoUrl, // storing public URL in storage_path for MVP
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        coverImageUrl: thumbnailUrl,
        duration: (durationMs / 1000).ceil(),
      );

      _setProgress(1.0);

      if (!mounted) return;
      // Refresh feed provider to show the new video and jump to Feed tab
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        container.invalidate(feedVideosProvider);
      } catch (e) {
        debugPrint('⚠️ Could not invalidate feed provider: $e');
      }

      setMainTabIndex(0);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload complete')));

      // Reset UI
      setState(() {
        _pickedVideo = null;
        _playerController?.dispose();
        _playerController = null;
        _titleController.clear();
        _descController.clear();
        _isUploading = false;
        _progress = 0.0;
      });
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = 'Upload failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  void _setProgress(double value) {
    setState(() => _progress = value.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Video')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mobile_off, size: 100, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Upload requires a mobile device', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Please run on Android or iOS to select, compress, and upload videos.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview or Centered pick prompt
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
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
                              ),
                              onPressed: _isUploading
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
                        child: FilledButton.icon(
                          onPressed: _isUploading ? null : _pickVideo,
                          icon: const Icon(Icons.video_library),
                          label: const Text('Pick Video'),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Fields
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              maxLength: 2200,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_pickedVideo != null)
              Text(
                p.basename(_pickedVideo!.path),
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isUploading ? null : _upload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload'),
            ),
            const SizedBox(height: 12),
            if (_isUploading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 6),
                  Text('${(_progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
