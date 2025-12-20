import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _supabase = supabase;
  
  // --- CACHE: Stores resolved URLs to prevent repeated network calls ---
  static final Map<String, String> _urlCache = {};

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

  // Direct upload using HTTP with byte-level progress callback.
  // Falls back to anon key if no user session is available.
  // Returns the storage path (e.g., "$userId/$timestamp.mp4").
  // Use resolveVideoUrl() to turn it into a playable URL when needed.
  Future<String> uploadVideoWithProgress({
    required String userId,
    required String timestamp,
    required File file,
    required void Function(int bytesSent, int totalBytes) onProgress,
  }) async {
    final bucket = 'videos';
    final path = '$userId/$timestamp.mp4';
    final storageEndpoint = '${SupabaseConfig.urlValue}/storage/v1/object/$bucket/$path';
    final token = _supabase.auth.currentSession?.accessToken ?? SupabaseConfig.anonKeyValue;

    try {
      if (_supabase.auth.currentSession == null) {
        debugPrint('⚠️ No Supabase session found. Falling back to anon key for storage upload. For private buckets this will be denied by RLS (403).');
      } else {
        debugPrint('🔐 Using user JWT for storage upload. uid=${_supabase.auth.currentUser?.id}');
      }
      debugPrint('📦 Storage upload target -> bucket=$bucket path=$path');

      final totalBytes = await file.length();
      int sent = 0;

      final uri = Uri.parse(storageEndpoint);
      final request = http.StreamedRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'x-upsert': 'false',
        'Content-Type': 'video/mp4',
      });
      request.contentLength = totalBytes;

      // Start pumping file bytes into the request sink while sending the request.
      // This ensures progress reflects actual transfer time instead of pre-buffering.
      final fileStream = file.openRead();
      final pump = fileStream.listen(
        (chunk) {
          sent += chunk.length;
          request.sink.add(chunk);
          try {
            onProgress(sent, totalBytes);
          } catch (_) {}
        },
        onError: (err, st) async {
          try {
            await request.sink.close();
          } catch (_) {}
        },
        onDone: () async {
          try {
            await request.sink.close();
          } catch (_) {}
        },
        cancelOnError: true,
      );

      final client = http.Client();
      http.StreamedResponse response;
      try {
        response = await client.send(request);
      } finally {
        // Do not close client until we read the stream below
      }

      // Drain the response body to completion to avoid socket leaks
      final responseBody = await response.stream.bytesToString();
      await pump.cancel();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Return the storage path; playback should use a signed URL for private buckets.
        debugPrint('✅ Video uploaded (streamed) to path=$path');
        return path;
      }
      throw Exception('Upload failed: ${response.statusCode} $responseBody');
    } catch (e) {
      debugPrint('❌ Error uploading video with progress: $e');
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

  // Resolve a storage_path or a public URL into a playable URL.
  // - If storagePath already looks like an http(s) URL, return as-is.
  // - Otherwise, generate a signed URL from the private videos bucket.
  Future<String> resolveVideoUrl(String storagePath, {int expiresIn = 3600}) async {
    // 1. Check Memory Cache
    if (_urlCache.containsKey(storagePath)) {
      return _urlCache[storagePath]!;
    }

    String resultUrl;

    // If it's already a URL, try to normalize public URLs back to a signed path when possible
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      // Handle Supabase "public URL" form: /storage/v1/object/public/videos/<path>
      final marker = '/storage/v1/object/public/videos/';
      final i = storagePath.indexOf(marker);
      if (i != -1) {
        final path = storagePath.substring(i + marker.length);
        resultUrl = await getSignedVideoUrl(path, expiresIn: expiresIn);
      } else {
        resultUrl = storagePath;
      }
    } else {
      resultUrl = await getSignedVideoUrl(storagePath, expiresIn: expiresIn);
    }

    // 2. Save to Memory Cache
    _urlCache[storagePath] = resultUrl;
    
    return resultUrl;
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
