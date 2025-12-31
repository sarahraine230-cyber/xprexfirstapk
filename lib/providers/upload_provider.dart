import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
// IMPORT SCREENS TO ACCESS THEIR PROVIDERS
import 'package:xprex/screens/feed_screen.dart';
// import 'package:xprex/screens/profile_screen.dart'; // Ensure correct import path if needed

// Simplified provider for User Profile to avoid circular dependency issues if file structure differs
// Assuming 'createdVideosProvider' is defined in a profile provider file. 
// If it's not available, the invalidation below is just a best-effort.

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
    // New Arguments
    required String privacyLevel,
    required bool allowComments,
  }) async {
    state = state.copyWith(isUploading: true, progress: 0.1, status: 'Preparing...', errorMessage: null);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Generate Thumbnail
      state = state.copyWith(status: 'Generating thumbnail...', progress: 0.2);
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 600,
        quality: 75,
      );

      if (thumbBytes == null) throw Exception("Failed to generate thumbnail");

      // Upload Video
      state = state.copyWith(status: 'Uploading video...', progress: 0.3);
      final String videoPath = await _storage.uploadVideoWithProgress(
        userId: userId,
        timestamp: timestamp,
        file: videoFile,
        onProgress: (sent, total) {
          final p = sent / total;
          final mapped = 0.3 + (p * 0.50); // Map 0-1 to 0.3-0.8
          state = state.copyWith(progress: mapped);
        },
      );

      // Upload Thumbnail
      state = state.copyWith(status: 'Finishing up...', progress: 0.9);
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
        // Pass new settings
        privacyLevel: privacyLevel,
        allowComments: allowComments,
      );

      // Refresh Feeds (Nuclear Option to ensure fresh data)
      ref.invalidate(feedVideosProvider);
      // ref.invalidate(createdVideosProvider(userId)); // Uncomment if you have this provider

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
  return UploadNotifier(ref); 
});
