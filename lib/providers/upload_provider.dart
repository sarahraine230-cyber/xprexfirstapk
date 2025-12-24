import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
// IMPORT SCREENS TO ACCESS THEIR PROVIDERS
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/profile_screen.dart';

class UploadState {
  final bool isUploading;
  final double progress;
  final String status;
  final String? errorMessage;

  UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.status = '',
    this.errorMessage,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? status,
    String? errorMessage,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  // We need 'Ref' to invalidate other providers
  final Ref ref; 
  UploadNotifier(this.ref) : super(UploadState());

  final _storage = StorageService();
  final _videoService = VideoService();

  Future<void> startUpload({
    required File videoFile,
    required String title,
    required String description,
    required List<String> tags,
    required String userId,
    required int categoryId,
    required int durationSeconds,
  }) async {
    state = UploadState(isUploading: true, progress: 0.05, status: 'Preparing...');
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Main Thread Thumbnail Generation
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
      );
      if (thumbBytes == null) throw Exception('Failed to generate thumbnail');

      // Upload Video
      state = state.copyWith(status: 'Uploading Video...', progress: 0.10);
      final String videoPath = await _storage.uploadVideoWithProgress(
        userId: userId,
        timestamp: timestamp,
        file: videoFile,
        onProgress: (sent, total) {
          final mapped = 0.10 + ((sent / total) * 0.80);
          state = state.copyWith(progress: mapped);
        },
      );

      // Upload Thumbnail
      state = state.copyWith(status: 'Finishing up...', progress: 0.95);
      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: userId,
        timestamp: timestamp,
        bytes: thumbBytes,
      );

      // Save Metadata
      await _videoService.createVideo(
        authorAuthUserId: userId,
        storagePath: videoPath,
        title: title,
        description: description,
        coverImageUrl: thumbnailUrl,
        duration: durationSeconds,
        tags: tags,
        categoryId: categoryId,
      );

      // --- AUTO-REFRESH TRIGGER ---
      
      // NOTE: We REMOVED the Feed refresh here.
      // This prevents the feed from pulling the video while it's still processing.
      // The feed was already refreshed immediately when the user tapped "Post".
      
      // 2. Refresh the User's Profile (This DOES show the processing video, which is good)
      ref.invalidate(createdVideosProvider(userId));

      state = state.copyWith(isUploading: false, status: 'Done', progress: 1.0);
    } catch (e) {
      debugPrint('❌ Critical Upload Failure: $e');
      state = state.copyWith(
        isUploading: false, 
        errorMessage: 'Upload failed: ${e.toString()}'
      );
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref); // Pass Ref to Notifier
});
