# Supabase Storage Setup Instructions

## Create Storage Buckets

Follow these steps in your Supabase dashboard:

### 1. Navigate to Storage
Go to: **Storage** → **Buckets** in your Supabase dashboard

### 2. Create Avatars Bucket
- Click **"New bucket"**
- Name: `avatars`
- Public: **Yes** (avatars will be publicly accessible)
- File size limit: `2 MB`
- Allowed MIME types: `image/jpeg, image/png, image/webp`
- Click **Create bucket**

#### Avatars Bucket Policies
Go to **Policies** tab for `avatars` bucket and add:

```sql
-- Policy 1: Anyone can view avatars
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Policy 2: Authenticated users can upload avatars
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Users can update their own avatars
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Users can delete their own avatars
CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

### 3. Create Videos Bucket
- Click **"New bucket"**
- Name: `videos`
- Public: **No** (videos will use signed URLs for security)
- File size limit: `100 MB`
- Allowed MIME types: `video/mp4, video/quicktime, video/x-msvideo`
- Click **Create bucket**

#### Videos Bucket Policies
Go to **Policies** tab for `videos` bucket and add:

```sql
-- Policy 1: Authenticated users can upload videos
CREATE POLICY "Authenticated users can upload videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Users can update their own videos
CREATE POLICY "Users can update their own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Users can delete their own videos
CREATE POLICY "Users can delete their own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Anyone can download videos (via signed URL)
CREATE POLICY "Anyone can download videos"
ON storage.objects FOR SELECT
USING (bucket_id = 'videos');
```

### 4. Create Thumbnails Bucket
- Click **"New bucket"**
- Name: `thumbnails`
- Public: **Yes** (thumbnails should load quickly)
- File size limit: `1 MB`
- Allowed MIME types: `image/jpeg, image/png, image/webp`
- Click **Create bucket**

#### Thumbnails Bucket Policies
Go to **Policies** tab for `thumbnails` bucket and add:

```sql
-- Policy 1: Anyone can view thumbnails
CREATE POLICY "Thumbnails are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'thumbnails');

-- Policy 2: Authenticated users can upload thumbnails
CREATE POLICY "Authenticated users can upload thumbnails"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Users can update their own thumbnails
CREATE POLICY "Users can update their own thumbnails"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Users can delete their own thumbnails
CREATE POLICY "Users can delete their own thumbnails"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## File Path Convention

### Avatars
- Path format: `{user_id}/avatar_{timestamp}.{ext}`
- Example: `550e8400-e29b-41d4-a716-446655440000/avatar_1704067200.jpg`

### Videos
- Path format: `{user_id}/{video_id}.{ext}`
- Example: `550e8400-e29b-41d4-a716-446655440000/abc123-video.mp4`

### Thumbnails
- Path format: `{user_id}/{video_id}_thumb.{ext}`
- Example: `550e8400-e29b-41d4-a716-446655440000/abc123-video_thumb.jpg`

## Accessing Files

### Public URLs (Avatars & Thumbnails)
```dart
final url = supabase.storage
  .from('avatars')
  .getPublicUrl('user_id/avatar.jpg');
```

### Signed URLs (Videos)
```dart
final url = await supabase.storage
  .from('videos')
  .createSignedUrl('user_id/video.mp4', 3600); // 1 hour expiry
```

## File Upload Example

```dart
// Upload avatar
final avatarFile = File('path/to/image.jpg');
final userId = supabase.auth.currentUser!.id;
final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
final path = '$userId/$fileName';

await supabase.storage
  .from('avatars')
  .upload(path, avatarFile);

final publicUrl = supabase.storage
  .from('avatars')
  .getPublicUrl(path);
```

## CORS Configuration

If accessing storage from web, ensure CORS is configured in Supabase dashboard:

1. Go to **Settings** → **API**
2. Add your app's URL to **Allowed origins**
3. Example: `http://localhost:3000` for local dev

## Storage Quotas

Free tier limits:
- Storage: 1 GB
- Bandwidth: 2 GB/month
- File uploads: 50 MB max per file

For production, consider upgrading to Pro plan or using CDN caching.

## Optimization Tips

1. **Compress videos** on client before upload (use flutter_video_compress)
2. **Generate thumbnails** from first frame before upload
3. **Use signed URLs** with appropriate expiry times
4. **Implement CDN** (Cloudflare, CloudFront) for better performance
5. **Clean up old files** periodically to manage storage costs
