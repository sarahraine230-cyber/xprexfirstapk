import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/auth_service.dart';

// State class to hold UI data
class UploadState {
  final bool isUploading;
  final double progress;
  final String status; // "Uploading...", "Success"
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
      errorMessage: errorMessage, // Null resets error
    );
  }
}

// The Background Worker
class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier() : super(UploadState());

  final _storage = StorageService();
  final _videoService = VideoService();

  Future<void> startUpload({
    required File videoFile,
    required String title,
    required String description,
    required List<String> tags,
    required String userId,
    required int durationSeconds,
  }) async {
    // 1. Reset State
    state = UploadState(isUploading: true, progress: 0.05, status: 'Preparing...');
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 2. GENERATE THUMBNAIL (From original)
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
      );
      if (thumbBytes == null) throw Exception('Failed to generate thumbnail');

      // 3. UPLOAD RAW VIDEO (R2)
      // No compression. Pure speed.
      state = state.copyWith(status: 'Uploading Video...', progress: 0.10);

      final String videoPath = await _storage.uploadVideoWithProgress(
        userId: userId,
        timestamp: timestamp,
        file: videoFile,
        onProgress: (sent, total) {
          // Map upload to 0.10 -> 0.90 global progress
          final mapped = 0.10 + ((sent / total) * 0.80);
          state = state.copyWith(progress: mapped);
        },
      );

      // 4. UPLOAD THUMBNAIL
      state = state.copyWith(status: 'Finishing up...', progress: 0.95);
      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: userId,
        timestamp: timestamp,
        bytes: thumbBytes,
      );

      // 5. SAVE METADATA
      await _videoService.createVideo(
        authorAuthUserId: userId,
        storagePath: videoPath,
        title: title,
        description: description,
        coverImageUrl: thumbnailUrl,
        duration: durationSeconds,
        tags: tags,
      );

      // 6. SUCCESS
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

// Global Provider Definition
final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier();
});
