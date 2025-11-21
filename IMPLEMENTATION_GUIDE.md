# XpreX Implementation Guide

## Current Status

### ✅ Completed
1. **Backend Infrastructure**
   - Supabase SQL schemas (`supabase/create_tables.sql`)
   - RLS policies (`supabase/rls_policies.sql`)
   - Storage setup guide (`supabase/storage_setup.md`)
   - Admin API (Node.js/Express) in `/admin` folder
   - Complete README with setup instructions

2. **Flutter Core**
   - Project configuration (`pubspec.yaml`)
   - Theme with vibrant colors (`lib/theme.dart`)
   - Supabase configuration (`lib/config/supabase_config.dart`)
   - Data models (User, Video, Comment)
   - Services (Auth, Profile, Storage, Video, Comment)
   - Riverpod providers
   - App router with authentication flow
   - Main app entry point

3. **Screens**
   - Splash screen (implemented)

### 🚧 To Be Implemented

The following screens need to be created to complete the MVP. Each screen's structure and key features are outlined below:

#### 1. Login Screen (`lib/screens/login_screen.dart`)
**Purpose**: Email/password login

**Key Features**:
- Email and password text fields
- "Log In" button
- "Don't have an account? Sign up" link
- Error handling for invalid credentials
- Loading state during authentication

**Implementation Guide**:
```dart
- Use AuthService.signIn()
- Navigate to email verification if not verified
- Navigate to profile setup if no profile exists
- Navigate to main shell if fully authenticated
```

#### 2. Signup Screen (`lib/screens/signup_screen.dart`)
**Purpose**: Email/password registration

**Key Features**:
- Email and password text fields
- Confirm password field
- "Sign Up" button
- "Already have an account? Log in" link
- Password strength indicator
- Terms acceptance checkbox

**Implementation Guide**:
```dart
- Use AuthService.signUp()
- Navigate to email verification screen after successful signup
- Show error messages for duplicate emails or weak passwords
```

#### 3. Email Verification Screen (`lib/screens/email_verification_screen.dart`)
**Purpose**: Wait for email confirmation

**Key Features**:
- Instructions to check email
- "Resend Email" button
- "I've Verified" button to refresh session
- "Open Email App" button (platform-specific)

**Implementation Guide**:
```dart
- Use AuthService.resendVerificationEmail()
- Use AuthService.refreshSession() on "I've Verified"
- Navigate to profile setup when verified
```

#### 4. Profile Setup Screen (`lib/screens/profile_setup_screen.dart`)
**Purpose**: Initial profile creation

**Key Features**:
- Avatar picker (image_picker)
- Username field with availability check
- Display name field
- Bio text area
- 18+ age confirmation checkbox
- "Continue" button

**Implementation Guide**:
```dart
- Use image_picker for avatar
- Use StorageService.uploadAvatar()
- Use ProfileService.isUsernameAvailable() for validation
- Use ProfileService.createProfile()
- Navigate to main shell after creation
```

#### 5. Main Shell (`lib/screens/main_shell.dart`)
**Purpose**: Bottom navigation container

**Key Features**:
- Bottom navigation bar with 3 tabs:
  - Feed (home icon)
  - Upload (add icon)
  - Profile (person icon)
- Persistent across tab switches
- Current tab highlighting

**Implementation Guide**:
```dart
- Use StatefulWidget with PageView or IndexedStack
- Show FeedScreen, UploadScreen, ProfileScreen based on index
```

#### 6. Feed Screen (`lib/screens/feed_screen.dart`)
**Purpose**: Vertical video feed (TikTok-style)

**Key Features**:
- PageView.builder for vertical scrolling
- Auto-play video when visible (muted)
- Like, comment, share buttons overlay
- Author info overlay (avatar, username)
- Lazy loading with pagination
- Video player controls

**Implementation Guide**:
```dart
- Use VideoService.getFeedVideos()
- Use video_player package
- Use PageController for vertical snap
- Preload next video for smooth scrolling
- Show loading indicator while fetching
```

#### 7. Upload Screen (`lib/screens/upload_screen.dart`)
**Purpose**: Video upload flow

**Key Features**:
- Video picker (image_picker video)
- Video preview player
- Title input field
- Description input field
- Thumbnail selector (first frame)
- "Upload" button with progress indicator
- Client-side compression (flutter_video_compress)

**Implementation Guide**:
```dart
- Use image_picker for video selection
- Use flutter_video_compress for compression
- Use video_thumbnail for thumbnail generation
- Use StorageService.uploadVideo() and uploadThumbnail()
- Use VideoService.createVideo()
- Show CircularProgressIndicator during upload
- Navigate to feed after successful upload
```

#### 8. Profile Screen (`lib/screens/profile_screen.dart`)
**Purpose**: User profile view

**Key Features**:
- User avatar (large)
- Username and display name
- Bio
- Stats: Followers, Views, Videos count
- Monetization status badge
- "Edit Profile" button
- "Monetization" button
- Grid of user's videos
- Sign out button

**Implementation Guide**:
```dart
- Use ProfileService.getProfileByAuthId()
- Use VideoService.getUserVideos()
- Show GridView of video thumbnails
- Navigate to edit profile screen
- Navigate to monetization screen
- Use AuthService.signOut()
```

#### 9. Monetization Screen (`lib/screens/monetization_screen.dart`)
**Purpose**: Show eligibility and enable premium

**Key Features**:
- Progress circle (percentage toward eligibility)
- Checklist of criteria:
  - ✓ 1,000+ followers
  - ✓ 10,000+ video views
  - ✓ Account age 30+ days
  - ✓ Email verified
  - ✓ 18+ confirmed
  - ✓ No active flags
- Current stats display
- "Enable Premium" button (simulated payment)
- Benefits list

**Implementation Guide**:
```dart
- Use ProfileService.getMonetizationEligibility()
- Show CircularProgressIndicator with percentage
- Show CheckCircleIcon or RadioButtonUnchecked for criteria
- On "Enable Premium", use ProfileService.updateProfile()
- Show success dialog and navigate back
```

#### 10. Video Detail Screen (Optional for MVP, can be bottom sheet)
**Purpose**: Full video with comments

**Key Features**:
- Full-screen video player
- Comments bottom sheet
- Comment input field
- Send button
- Real-time comment updates

**Implementation Guide**:
```dart
- Use showModalBottomSheet for comments
- Use CommentService.getCommentsByVideo()
- Use CommentService.createComment()
- Show ListView of comments
- Use TextField with send IconButton
```

## Widget Components to Create

### 1. Custom Button (`lib/widgets/custom_button.dart`)
- Primary, secondary, outline variants
- Loading state
- Disabled state
- Consistent styling across app

### 2. Custom Text Field (`lib/widgets/custom_text_field.dart`)
- Consistent styling
- Error state
- Prefix/suffix icons
- Validation support

### 3. Video Player Widget (`lib/widgets/video_player_widget.dart`)
- Wraps video_player
- Muted autoplay support
- Loading indicator
- Error handling
- Play/pause overlay

### 4. Comment Item (`lib/widgets/comment_item.dart`)
- Avatar, username, timestamp
- Comment text
- Delete button (for own comments)

### 5. Video Feed Item (`lib/widgets/video_feed_item.dart`)
- Video player
- Author info overlay
- Interaction buttons (like, comment, share)
- Like count, comment count

## Testing the App

### Prerequisites
1. **Supabase Setup**:
   - Create Supabase project
   - Run `create_tables.sql` in SQL Editor
   - Run `rls_policies.sql` in SQL Editor
   - Create storage buckets (avatars, videos, thumbnails)
   - Apply storage policies from `storage_setup.md`

2. **Environment Variables**:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
   ```

### Test Flow
1. Launch app → Splash screen
2. Click "Sign Up" → Enter email/password
3. Check email → Click verification link
4. Return to app → Click "I've Verified"
5. Set up profile → Upload avatar, choose username
6. Land on Feed screen (empty initially)
7. Go to Upload tab → Select video → Add title → Upload
8. Wait for upload → See video in feed
9. Like video → See count increment
10. Comment on video → See comment appear
11. Go to Profile → See video count
12. Click Monetization → See eligibility checklist
13. Sign out

## Web Preview Limitations

⚠️ **Note**: Some features have limited support in web preview:

- **image_picker**: May not work in web. Test on actual device.
- **video_player**: Works but performance may vary.
- **flutter_video_compress**: Not supported in web. Skip compression or show error message.

**Solution**: Add platform checks and fallback UI for web:
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

if (kIsWeb) {
  // Show message: "Upload feature requires mobile device"
} else {
  // Normal flow
}
```

## Next Steps for Production

1. **Add user following/followers**
2. **Implement video sharing**
3. **Add push notifications**
4. **Implement video transcoding** (Cloudflare Stream, Mux)
5. **Add CDN** for faster video delivery
6. **Implement search and discovery**
7. **Add hashtags and trending**
8. **Implement real payment gateway** for monetization
9. **Add admin dashboard UI**
10. **Implement CI/CD pipeline** (GitHub Actions)

## Admin API Usage

See README.md for admin API endpoints and usage examples.

## Support

- Check README.md for detailed setup instructions
- Check architecture.md for system design
- Review Supabase documentation for database/storage issues
- Check Flutter documentation for UI/navigation issues
