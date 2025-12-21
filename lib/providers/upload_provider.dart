import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/auth_service.dart';

// State class to hold UI data
class UploadState {
  final bool isUploading;
  final double progress;
  final String status; // "Compressing...", "Uploading...", "Success"
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
  Subscription? _subscription;

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
      File fileToUpload = videoFile;
      bool compressionSucceeded = false;

      // 2. GENERATE THUMBNAIL (Always from original)
      final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
      );
      if (thumbBytes == null) throw Exception('Failed to generate thumbnail');

      // 3. TRY COMPRESSION (The Fallback Strategy)
      state = state.copyWith(status: 'Optimizing...', progress: 0.10);
      try {
        await VideoCompress.deleteAllCache();
        
        // Listen to progress (maps 0-100 to 0.10-0.40 global progress)
        _subscription = VideoCompress.compressProgress$.subscribe((progress) {
          final mapped = 0.10 + (progress / 100 * 0.30);
          state = state.copyWith(progress: mapped);
        });

        final MediaInfo? info = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (info != null && info.file != null) {
          fileToUpload = info.file!;
          compressionSucceeded = true;
          debugPrint('✅ Compression success: ${videoFile.lengthSync()} -> ${fileToUpload.lengthSync()}');
        } else {
          debugPrint('⚠️ Compression returned null info. Using original.');
        }
      } catch (e) {
        debugPrint('⚠️ Compression Failed: $e. Fallback to original file.');
        // We do NOT stop. We proceed with the original file.
      } finally {
        _subscription?.unsubscribe();
        _subscription = null;
      }

      // 4. UPLOAD VIDEO (R2)
      state = state.copyWith(
        status: compressionSucceeded ? 'Uploading Optimized...' : 'Uploading Original...', 
        progress: 0.40
      );

      final String videoPath = await _storage.uploadVideoWithProgress(
        userId: userId,
        timestamp: timestamp,
        file: fileToUpload,
        onProgress: (sent, total) {
          // Map upload to 0.40 -> 0.90 global progress
          final mapped = 0.40 + ((sent / total) * 0.50);
          state = state.copyWith(progress: mapped);
        },
      );

      // 5. UPLOAD THUMBNAIL
      state = state.copyWith(status: 'Finishing up...', progress: 0.95);
      final String thumbnailUrl = await _storage.uploadThumbnailBytes(
        userId: userId,
        timestamp: timestamp,
        bytes: thumbBytes,
      );

      // 6. SAVE METADATA
      await _videoService.createVideo(
        authorAuthUserId: userId,
        storagePath: videoPath,
        title: title,
        description: description,
        coverImageUrl: thumbnailUrl,
        duration: durationSeconds,
        tags: tags,
      );

      // 7. CLEANUP
      if (compressionSucceeded) {
        await VideoCompress.deleteAllCache();
      }
      
      // 8. SUCCESS
      state = state.copyWith(isUploading: false, status: 'Done', progress: 1.0);
      
      // Auto-hide success message after 3 seconds could be handled by UI, 
      // but simpler to just reset state here or let UI handle it.

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
