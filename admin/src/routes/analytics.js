import express from 'express';
import supabase from '../config/supabase.js';
import { authenticateAdmin } from '../middleware/auth.js';

const router = express.Router();

// All routes require admin authentication
router.use(authenticateAdmin);

// GET /admin/analytics/daily?days=30
router.get('/daily', async (req, res, next) => {
  try {
    const { days = 30 } = req.query;
    const daysInt = parseInt(days);

    if (daysInt < 1 || daysInt > 365) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Days must be between 1 and 365'
      });
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysInt);

    // Fetch daily analytics
    const { data: analytics, error } = await supabase
      .from('daily_analytics')
      .select('*')
      .gte('date', startDate.toISOString().split('T')[0])
      .order('date', { ascending: false });

    if (error) throw error;

    // Group by date for easier consumption
    const groupedByDate = analytics.reduce((acc, row) => {
      const date = row.date;
      if (!acc[date]) {
        acc[date] = { date, video: 0, comment: 0, like: 0 };
      }
      acc[date][row.resource_type] = row.count;
      return acc;
    }, {});

    const result = Object.values(groupedByDate);

    res.json({
      period: {
        days: daysInt,
        start_date: startDate.toISOString().split('T')[0],
        end_date: new Date().toISOString().split('T')[0]
      },
      data: result
    });
  } catch (error) {
    next(error);
  }
});

// GET /admin/analytics/overview
router.get('/overview', async (req, res, next) => {
  try {
    // Get total counts
    const [
      { count: totalUsers },
      { count: totalVideos },
      { count: totalComments },
      { count: totalLikes },
      { count: totalFlags }
    ] = await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true }),
      supabase.from('videos').select('*', { count: 'exact', head: true }),
      supabase.from('comments').select('*', { count: 'exact', head: true }),
      supabase.from('likes').select('*', { count: 'exact', head: true }),
      supabase.from('flags').select('*', { count: 'exact', head: true })
    ]);

    // Get premium users count
    const { count: premiumUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('is_premium', true);

    // Get recent activity (last 24 hours)
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    const [
      { count: newUsers },
      { count: newVideos },
      { count: newComments }
    ] = await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true })
        .gte('created_at', yesterday.toISOString()),
      supabase.from('videos').select('*', { count: 'exact', head: true })
        .gte('created_at', yesterday.toISOString()),
      supabase.from('comments').select('*', { count: 'exact', head: true })
        .gte('created_at', yesterday.toISOString())
    ]);

    res.json({
      totals: {
        users: totalUsers,
        videos: totalVideos,
        comments: totalComments,
        likes: totalLikes,
        flags: totalFlags,
        premium_users: premiumUsers
      },
      last_24h: {
        new_users: newUsers,
        new_videos: newVideos,
        new_comments: newComments
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /admin/analytics/top-creators?limit=10
router.get('/top-creators', async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;

    const { data: topCreators, error } = await supabase
      .from('user_engagement_stats')
      .select('*')
      .order('total_video_views', { ascending: false })
      .limit(parseInt(limit));

    if (error) throw error;

    res.json({
      data: topCreators
    });
  } catch (error) {
    next(error);
  }
});

// GET /admin/analytics/engagement
router.get('/engagement', async (req, res, next) => {
  try {
    // Get engagement metrics
    const { data: videos } = await supabase
      .from('videos')
      .select('playback_count, likes_count, comments_count');

    if (!videos || videos.length === 0) {
      return res.json({
        total_views: 0,
        total_likes: 0,
        total_comments: 0,
        avg_likes_per_video: 0,
        avg_comments_per_video: 0,
        engagement_rate: 0
      });
    }

    const totalViews = videos.reduce((sum, v) => sum + (v.playback_count || 0), 0);
    const totalLikes = videos.reduce((sum, v) => sum + (v.likes_count || 0), 0);
    const totalComments = videos.reduce((sum, v) => sum + (v.comments_count || 0), 0);

    const avgLikesPerVideo = totalLikes / videos.length;
    const avgCommentsPerVideo = totalComments / videos.length;
    const engagementRate = totalViews > 0 
      ? ((totalLikes + totalComments) / totalViews * 100).toFixed(2)
      : 0;

    res.json({
      total_views: totalViews,
      total_likes: totalLikes,
      total_comments: totalComments,
      avg_likes_per_video: parseFloat(avgLikesPerVideo.toFixed(2)),
      avg_comments_per_video: parseFloat(avgCommentsPerVideo.toFixed(2)),
      engagement_rate: parseFloat(engagementRate)
    });
  } catch (error) {
    next(error);
  }
});

export default router;
