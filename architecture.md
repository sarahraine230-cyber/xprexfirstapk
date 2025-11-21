# XpreX Mini-MVP Architecture

## Overview
XpreX is a vertical video sharing platform (TikTok-style) with monetization features, built with Flutter and Supabase.

## Technology Stack
- **Frontend**: Flutter (null-safety)
- **State Management**: Riverpod
- **Navigation**: go_router
- **Video**: video_player
- **Image**: image_picker
- **Compression**: flutter_video_compress
- **Backend**: Supabase (Auth, Database, Storage)
- **Admin API**: Node.js + Express

## Database Schema

### Tables
1. **profiles**
   - id (uuid, pk)
   - auth_user_id (uuid, unique, references auth.users)
   - email (text)
   - username (text, unique)
   - display_name (text)
   - avatar_url (text)
   - bio (text)
   - followers_count (int, default 0)
   - total_video_views (bigint, default 0)
   - is_premium (bool, default false)
   - monetization_status (text, default 'locked')
   - created_at (timestamptz)
   - updated_at (timestamptz)

2. **videos**
   - id (uuid, pk)
   - author_auth_user_id (uuid, references auth.users)
   - storage_path (text)
   - cover_image_url (text)
   - title (text)
   - description (text)
   - duration (int, seconds)
   - playback_count (bigint, default 0)
   - likes_count (int, default 0)
   - comments_count (int, default 0)
   - created_at (timestamptz)
   - updated_at (timestamptz)

3. **comments**
   - id (uuid, pk)
   - video_id (uuid, references videos)
   - author_auth_user_id (uuid, references auth.users)
   - text (text)
   - created_at (timestamptz)
   - updated_at (timestamptz)

4. **likes**
   - id (uuid, pk)
   - video_id (uuid, references videos)
   - user_auth_id (uuid, references auth.users)
   - created_at (timestamptz)

5. **flags**
   - id (uuid, pk)
   - resource_type (text: 'video', 'comment', 'profile')
   - resource_id (uuid)
   - reporter_auth_user_id (uuid, references auth.users)
   - reason (text)
   - status (text, default 'pending')
   - created_at (timestamptz)
   - updated_at (timestamptz)

### Storage Buckets
- **avatars**: Public bucket for profile pictures
- **videos**: Private bucket with signed URLs
- **thumbnails**: Public bucket for video thumbnails

## App Structure

### Models (`lib/models/`)
- `user_model.dart` - User profile data
- `video_model.dart` - Video metadata
- `comment_model.dart` - Comment data
- `flag_model.dart` - Report/flag data
- `monetization_model.dart` - Monetization eligibility data

### Services (`lib/services/`)
- `supabase_service.dart` - Supabase client initialization
- `auth_service.dart` - Authentication logic
- `profile_service.dart` - Profile CRUD operations
- `video_service.dart` - Video upload/fetch/update
- `comment_service.dart` - Comment operations
- `storage_service.dart` - File upload/download
- `monetization_service.dart` - Monetization logic

### Providers (`lib/providers/`)
- `auth_provider.dart` - Auth state management
- `profile_provider.dart` - User profile state
- `feed_provider.dart` - Video feed state
- `upload_provider.dart` - Upload flow state

### Screens (`lib/screens/`)
1. **Auth Flow**
   - `splash_screen.dart` - Welcome/Splash
   - `login_screen.dart` - Email/password login
   - `signup_screen.dart` - Email/password signup
   - `email_verification_screen.dart` - Email verification pending

2. **Profile Setup**
   - `profile_setup_screen.dart` - Initial profile creation

3. **Main App**
   - `main_shell.dart` - Bottom navigation shell
   - `feed_screen.dart` - Vertical video feed
   - `upload_screen.dart` - Video upload flow
   - `profile_screen.dart` - User profile
   - `monetization_screen.dart` - Monetization eligibility

4. **Secondary**
   - `video_detail_screen.dart` - Full video player with comments
   - `edit_profile_screen.dart` - Edit user profile

### Widgets (`lib/widgets/`)
- `video_player_widget.dart` - Custom video player
- `video_feed_item.dart` - Feed item with interactions
- `comment_sheet.dart` - Comments bottom sheet
- `upload_form.dart` - Upload metadata form
- `monetization_checklist.dart` - Eligibility checklist
- `custom_button.dart` - Themed buttons
- `custom_text_field.dart` - Themed input fields

## User Flows

### 1. Authentication Flow
```
Splash → Login/Signup → Email Verification → Profile Setup → Main Feed
```

### 2. Video Upload Flow
```
Upload Tab → Select/Record Video → Add Metadata (title, cover) → Compress → Upload → Feed
```

### 3. Monetization Flow
```
Profile → Monetization Status → Eligibility Page → Progress Checklist → Enable Premium
```

## Admin Backend (`/admin`)

### API Endpoints
- `GET /admin/flags?status=pending` - List flagged content
- `POST /admin/flags/:id/action` - Moderate flagged content
- `GET /admin/analytics/daily?days=30` - Daily analytics

### Structure
```
/admin
  /src
    /routes
      - flags.js
      - analytics.js
    /middleware
      - auth.js
    - server.js
  - package.json
  - .env.example
```

## Security
- Supabase Row Level Security (RLS) policies
- No hardcoded keys (use --dart-define)
- JWT validation for admin API
- Signed URLs for private video storage

## Performance Optimizations
- Lazy loading in feed
- Video prefetching
- Thumbnail-first loading
- Client-side video compression
- Pagination for comments and feed

## Deployment Checklist
1. Configure Supabase project (tables, RLS, storage)
2. Set up environment variables
3. Test auth flow end-to-end
4. Test video upload with compression
5. Verify signed URLs for videos
6. Deploy admin API
7. Configure CI/CD pipeline

## Monetization Eligibility Criteria
- Minimum 1000 followers
- Minimum 10,000 total video views
- Account age > 30 days
- No active content flags
- Email verified
- 18+ age confirmed
