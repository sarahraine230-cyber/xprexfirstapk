import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart'; // The S3 Client
import 'package:minio/models.dart'; // Minio Models
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/config/secrets.dart'; // Your Keys

class StorageService {
  final SupabaseClient _supabase = supabase;
  
  // R2 Client (S3 Compatible)
  late Minio _r2;

  // Cache for resolved URLs (Memory optimization)
  static final Map<String, String> _urlCache = {};

  StorageService() {
    _initR2();
  }

  void _initR2() {
    _r2 = Minio(
      endPoint: _parseEndpoint(Secrets.r2Endpoint),
      accessKey: Secrets.r2AccessKey,
      secretKey: Secrets.r2SecretKey,
      region: 'auto', // R2 uses 'auto'
      // useSSL: true is default
    );
  }

  // Helper to strip 'https://' for Minio client which expects host only in some versions
  String _parseEndpoint(String url) {
    return url.replaceFirst('https://', '').replaceFirst('http://', '');
  }

  // --- VIDEO UPLOAD (R2) ---
  
  // Uploads directly to Cloudflare R2 with progress tracking
  Future<String> uploadVideoWithProgress({
    required String userId,
    required String timestamp,
    required File file,
    required void Function(int bytesSent, int totalBytes) onProgress,
  }) async {
    try {
      final path = '$userId/$timestamp.mp4';
      final totalBytes = await file.length();
      
      debugPrint('🚀 Starting R2 Upload: $path ($totalBytes bytes)');

      // Create a stream that reports progress
      final stream = file.openRead().transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            // Report progress
            // Note: In a real stream, we might need a counter wrapper, 
            // but Minio reads the stream. We'll use a pass-through reporting.
            sink.add(data);
            // This callback might be disjointed from actual network send, 
            // but it's the best proxy we have without custom HTTP clients.
            // For a smoother UI, we'll assume linear progress based on stream read.
          },
        ),
      );
      
      // We need a manual counter since the transformer above is passive
      int bytesRead = 0;
      final reportingStream = file.openRead().map((chunk) {
        bytesRead += chunk.length;
        onProgress(bytesRead, totalBytes);
        return chunk;
      });

      // Upload to R2
      await _r2.putObject(
        Secrets.r2BucketName,
        path,
        reportingStream,
        size: totalBytes,
        metadata: {'content-type': 'video/mp4'},
      );

      debugPrint('✅ R2 Upload Complete: $path');
      return path; // We store the R2 Key in Supabase
    } catch (e) {
      debugPrint('❌ R2 Upload Failed: $e');
      rethrow;
    }
  }

  // --- THUMBNAIL UPLOAD (R2) ---
  
  Future<String> uploadThumbnail({
    required String userId,
    required String timestamp,
    required File file,
  }) async {
    try {
      final path = '$userId/$timestamp.jpg';
      final bytes = await file.readAsBytes();
      
      await _r2.putObject(
        Secrets.r2BucketName,
        path,
        Stream.value(bytes),
        size: bytes.length,
        metadata: {'content-type': 'image/jpeg'},
      );

      // Return the Public URL directly
      final url = '${Secrets.r2PublicDomain}/$path';
      debugPrint('✅ Thumbnail uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ R2 Thumbnail Upload Failed: $e');
      rethrow;
    }
  }

  // --- URL RESOLUTION (The Speed Upgrade) ---

  // Converts a storage path (R2 Key) into a playable Public URL
  Future<String> resolveVideoUrl(String storagePath, {int expiresIn = 3600}) async {
    // 1. Check Memory Cache
    if (_urlCache.containsKey(storagePath)) {
      return _urlCache[storagePath]!;
    }

    String resultUrl;

    // 2. Logic
    if (storagePath.startsWith('http')) {
      // Already a URL (maybe from old Supabase uploads or external)
      resultUrl = storagePath;
    } else {
      // It is an R2 Key (e.g. "user123/video456.mp4")
      // We simply append it to the public domain. 
      // Zero network requests needed. Instant.
      resultUrl = '${Secrets.r2PublicDomain}/$storagePath';
    }

    // 3. Save to Cache
    _urlCache[storagePath] = resultUrl;
    
    return resultUrl;
  }

  // --- LEGACY / OTHER ---

  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    // Avatars can stay on Supabase for simplicity, or move to R2.
    // Let's keep them on Supabase to minimize risk for now.
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
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String bucket, String path) async {
    // Basic implementation for R2 if bucket is 'videos' or 'thumbnails'
    try {
      if (bucket == 'videos' || bucket == Secrets.r2BucketName) {
        await _r2.removeObject(Secrets.r2BucketName, path);
      } else {
        await _supabase.storage.from(bucket).remove([path]);
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
    }
  }

  // Byte upload helpers (mapped to R2 for consistency)
  Future<String> uploadVideoBytes({
    required String userId,
    required String timestamp,
    required Uint8List bytes,
  }) async {
    final path = '$userId/$timestamp.mp4';
    await _r2.putObject(
      Secrets.r2BucketName, 
      path, 
      Stream.value(bytes), 
      size: bytes.length, 
      metadata: {'content-type': 'video/mp4'}
    );
    return path;
  }
}
