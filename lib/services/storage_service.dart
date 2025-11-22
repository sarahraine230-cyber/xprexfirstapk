import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _supabase = supabase;

  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final fileName = 'avatar_$timestamp.$extension';
      final path = '$userId/$fileName';

      await _supabase.storage.from('avatars').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = _supabase.storage.from('avatars').getPublicUrl(path);
      debugPrint('✅ Avatar uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<String> uploadVideo({
    required String userId,
    required String timestamp,
    required File file,
  }) async {
    try {
      // Always store as .mp4 to meet the implementation guide
      final path = '${userId}/${timestamp}.mp4';

      await _supabase.storage.from('videos').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: false),
      );

      final url = _supabase.storage.from('videos').getPublicUrl(path);
      debugPrint('✅ Video uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading video: $e');
      rethrow;
    }
  }

  Future<String> uploadThumbnail({
    required String userId,
    required String timestamp,
    required File file,
  }) async {
    try {
      // Always store as .jpg to meet the implementation guide
      final path = '${userId}/${timestamp}.jpg';

      await _supabase.storage.from('thumbnails').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = _supabase.storage.from('thumbnails').getPublicUrl(path);
      debugPrint('✅ Thumbnail uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading thumbnail: $e');
      rethrow;
    }
  }

  Future<String> getSignedVideoUrl(String storagePath, {int expiresIn = 3600}) async {
    try {
      final url = await _supabase.storage
          .from('videos')
          .createSignedUrl(storagePath, expiresIn);
      return url;
    } catch (e) {
      debugPrint('❌ Error getting signed URL: $e');
      rethrow;
    }
  }

  String getPublicUrl(String bucket, String path) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
      debugPrint('✅ File deleted: $path');
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      rethrow;
    }
  }

  // Convenience: upload raw bytes and return public URL (no upsert for videos, upsert for thumbs)
  Future<String> uploadVideoBytes({
    required String userId,
    required String timestamp,
    required Uint8List bytes,
  }) async {
    try {
      final path = '${userId}/${timestamp}.mp4';
      await _supabase.storage.from('videos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false, contentType: 'video/mp4'),
          );
      final url = _supabase.storage.from('videos').getPublicUrl(path);
      debugPrint('✅ Video uploaded (bytes): $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading video bytes: $e');
      rethrow;
    }
  }

  Future<String> uploadThumbnailBytes({
    required String userId,
    required String timestamp,
    required Uint8List bytes,
  }) async {
    try {
      final path = '${userId}/${timestamp}.jpg';
      await _supabase.storage.from('thumbnails').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = _supabase.storage.from('thumbnails').getPublicUrl(path);
      debugPrint('✅ Thumbnail uploaded (bytes): $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading thumbnail bytes: $e');
      rethrow;
    }
  }
}
