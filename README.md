# XpreX - Vertical Video Sharing Platform

A TikTok-style vertical video sharing platform with monetization features, built with Flutter and Supabase.

## 📋 Table of Contents
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Running the App](#running-the-app)
- [Admin API](#admin-api)
- [Project Structure](#project-structure)
- [Testing Checklist](#testing-checklist)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## ✨ Features

### User Features
- ✅ Email/password authentication with verification
- ✅ Profile setup with avatar upload
- ✅ Vertical video feed (9:16 aspect ratio)
- ✅ Video upload with compression
- ✅ Video playback with autoplay (muted)
- ✅ Like, comment, and share videos
- ✅ User profiles with video history
- ✅ Monetization eligibility tracking
- ✅ Premium account upgrade (simulated)

### Admin Features
- ✅ Content moderation dashboard
- ✅ Flag management (pending/resolved/dismissed)
- ✅ User banning capabilities
- ✅ Analytics and metrics
- ✅ Daily activity reports

## 🛠 Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Navigation**: go_router
- **Video**: video_player
- **Image**: image_picker
- **Compression**: flutter_video_compress

### Backend
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Admin API**: Node.js + Express

## 📦 Prerequisites

### Flutter App
- Flutter SDK 3.6.0 or higher
- Dart 3.6.0 or higher
- Android Studio / Xcode (for mobile)
- VS Code (recommended)

### Admin API
- Node.js 18.0.0 or higher
- npm or yarn

### Supabase
- Supabase account (free tier works)
- Supabase project created

## 🚀 Setup Instructions

### 1. Supabase Setup

#### A. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your project URL and anon key from Settings → API
3. Note your service role key (for admin API)

#### B. Run Database Migrations
1. Go to SQL Editor in Supabase dashboard
2. Run `supabase/create_tables.sql`
3. Run `supabase/rls_policies.sql`

#### C. Configure Storage
Follow instructions in `supabase/storage_setup.md` to create:
- `avatars` bucket (public)
- `videos` bucket (private with signed URLs)
- `thumbnails` bucket (public)

#### D. Configure Authentication
1. Go to Authentication → Settings
2. Enable Email provider
3. Configure email templates (optional)
4. Set Site URL to your app URL (for email verification links)

### 2. Flutter App Setup

#### A. Install Dependencies
```bash
cd /path/to/project
flutter pub get
```

#### B. Configure Environment Variables

**Option 1: Command Line (Recommended)**
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

**Option 2: Create .env file (requires additional setup)**

Create `.env` in project root:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

#### C. Platform-Specific Setup

**Android** (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access required for video recording</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access required for video recording</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access required to upload videos</string>
```

### 3. Admin API Setup

#### A. Install Dependencies
```bash
cd admin
npm install
```

#### B. Configure Environment
Create `admin/.env` based on `admin/.env.example`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PORT=3001
NODE_ENV=development
ADMIN_JWT_SECRET=your-very-secure-jwt-secret
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com
```

#### C. Generate Admin Token (for testing)
```javascript
// Run this in Node.js REPL or create a script
import jwt from 'jsonwebtoken';
const token = jwt.sign(
  { id: 'admin-1', role: 'admin' },
  'your-very-secure-jwt-secret',
  { expiresIn: '24h' }
);
console.log(token);
```

## 🏃 Running the App

### Flutter App

**Chrome (Web Preview)**
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

**Android Device/Emulator**
```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

**iOS Device/Simulator**
```bash
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

**Note for Web Preview**: Image picker and video compression have limited support in web. Test on actual device for full functionality.

### Admin API

**Development**
```bash
cd admin
npm run dev
```

**Production**
```bash
cd admin
npm start
```

API will be available at `http://localhost:3001`

## 🔐 Admin API Usage

### Authentication
All admin endpoints require JWT authentication:
```bash
curl -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  http://localhost:3001/admin/flags
```

### Endpoints

#### Get Pending Flags
```bash
GET /admin/flags?status=pending&page=1&limit=20
```

#### Get Flag Details
```bash
GET /admin/flags/:id
```

#### Moderate Flag
```bash
POST /admin/flags/:id/action
Content-Type: application/json

{
  "action": "remove|dismiss|ban",
  "admin_notes": "Reason for action"
}
```

#### Get Analytics Overview
```bash
GET /admin/analytics/overview
```

#### Get Daily Analytics
```bash
GET /admin/analytics/daily?days=30
```

#### Get Top Creators
```bash
GET /admin/analytics/top-creators?limit=10
```

#### Get Engagement Metrics
```bash
GET /admin/analytics/engagement
```

## 📁 Project Structure

```
/project
├── lib/
│   ├── main.dart                 # App entry point
│   ├── theme.dart                # App theming
│   ├── config/
│   │   └── supabase_config.dart  # Supabase initialization
│   ├── models/                   # Data models
│   ├── providers/                # Riverpod providers
│   ├── screens/                  # UI screens
│   ├── services/                 # Business logic
│   └── widgets/                  # Reusable widgets
├── supabase/
│   ├── create_tables.sql         # Database schema
│   ├── rls_policies.sql          # Row Level Security
│   └── storage_setup.md          # Storage configuration
├── admin/
│   ├── src/
│   │   ├── routes/               # API routes
│   │   ├── middleware/           # Express middleware
│   │   └── config/               # Configuration
│   └── package.json
└── README.md
```

## ✅ Testing Checklist

### Authentication Flow
- [ ] Sign up with email/password
- [ ] Receive verification email
- [ ] Click verification link
- [ ] Complete profile setup
- [ ] Upload avatar
- [ ] Choose unique username
- [ ] Land on feed after setup

### Video Features
- [ ] View vertical video feed
- [ ] Videos autoplay when visible
- [ ] Like/unlike videos
- [ ] Comment on videos
- [ ] View comment count
- [ ] Upload new video
- [ ] Video compression works
- [ ] Thumbnail generation works
- [ ] Video appears in feed after upload

### Profile Features
- [ ] View own profile
- [ ] See uploaded videos
- [ ] Edit profile information
- [ ] View follower/view counts
- [ ] Check monetization status

### Monetization
- [ ] View eligibility checklist
- [ ] See progress toward requirements
- [ ] Simulate premium upgrade
- [ ] Premium status reflected in profile

### Admin API
- [ ] Authenticate with JWT
- [ ] Fetch pending flags
- [ ] Moderate flagged content
- [ ] View analytics dashboard
- [ ] Check daily activity
- [ ] See top creators

## 🚢 Deployment

### Flutter App

#### Android
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

#### iOS
```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

#### Web
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

### Admin API

#### Using Heroku
```bash
cd admin
heroku create xprex-admin
heroku config:set SUPABASE_URL=...
heroku config:set SUPABASE_SERVICE_ROLE_KEY=...
heroku config:set ADMIN_JWT_SECRET=...
git push heroku main
```

#### Using Docker
```bash
cd admin
docker build -t xprex-admin .
docker run -p 3001:3001 --env-file .env xprex-admin
```

## 🐛 Troubleshooting

### Flutter Issues

**Issue**: Image picker not working in web
- **Solution**: Test on actual mobile device. Web has limited support for native plugins.

**Issue**: Video compression fails
- **Solution**: Ensure device has sufficient storage. Try smaller video files.

**Issue**: Videos not playing
- **Solution**: Check Supabase storage bucket permissions and signed URL expiry.

**Issue**: "SUPABASE_URL not found"
- **Solution**: Ensure you're passing `--dart-define` flags when running the app.

### Admin API Issues

**Issue**: CORS errors
- **Solution**: Add your frontend URL to `ALLOWED_ORIGINS` in `.env`

**Issue**: Unauthorized errors
- **Solution**: Check JWT token is valid and includes `role: 'admin'`

**Issue**: Database connection fails
- **Solution**: Verify `SUPABASE_SERVICE_ROLE_KEY` is correct (not anon key)

### Supabase Issues

**Issue**: RLS policy blocks requests
- **Solution**: Check policies in `rls_policies.sql` are applied correctly

**Issue**: Storage upload fails
- **Solution**: Verify bucket exists and policies allow authenticated uploads

**Issue**: Email verification not working
- **Solution**: Configure SMTP settings in Supabase dashboard or use default (limited)

## 📈 Performance Optimization

### Current Optimizations
- Client-side video compression
- Lazy loading in feed
- Thumbnail-first loading
- Pagination for comments

### Future Improvements
- CDN integration (Cloudflare/CloudFront)
- Video transcoding service (Mux/Cloudflare Stream)
- Redis caching for analytics
- Background job processing for uploads
- Push notifications

## 🔒 Security Notes

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ No hardcoded API keys
- ✅ Signed URLs for private video access
- ✅ JWT authentication for admin API
- ✅ Email verification required
- ⚠️ Service role key must be kept secret (admin API only)
- ⚠️ Implement rate limiting for production
- ⚠️ Add CAPTCHA for signup to prevent bots

## 📞 Support

For issues and questions:
- Check [Supabase Documentation](https://supabase.com/docs)
- Check [Flutter Documentation](https://flutter.dev/docs)
- Review `architecture.md` for system design

## 📄 License

MIT License - See LICENSE file for details
#   x p r e x - f a s t - b u i l d  
 #   x p r e x - f a s t - b u i l d  
 