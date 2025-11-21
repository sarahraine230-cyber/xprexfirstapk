import express from 'express';
import supabase from '../config/supabase.js';
import { authenticateAdmin } from '../middleware/auth.js';

const router = express.Router();

// All routes require admin authentication
router.use(authenticateAdmin);

// GET /admin/flags?status=pending&page=1&limit=20
router.get('/', async (req, res, next) => {
  try {
    const { status = 'pending', page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    // Validate status
    const validStatuses = ['pending', 'resolved', 'dismissed'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`
      });
    }

    // Fetch flags
    const { data: flags, error, count } = await supabase
      .from('flags')
      .select('*, profiles!reporter_auth_user_id(username, display_name)', { count: 'exact' })
      .eq('status', status)
      .order('created_at', { ascending: false })
      .range(offset, offset + parseInt(limit) - 1);

    if (error) throw error;

    res.json({
      data: flags,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: count,
        totalPages: Math.ceil(count / parseInt(limit))
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /admin/flags/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    const { data: flag, error } = await supabase
      .from('flags')
      .select(`
        *,
        reporter:profiles!reporter_auth_user_id(username, display_name, avatar_url)
      `)
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Flag not found'
        });
      }
      throw error;
    }

    // Fetch resource details based on type
    let resourceDetails = null;
    if (flag.resource_type === 'video') {
      const { data } = await supabase
        .from('videos')
        .select('title, author_auth_user_id, storage_path')
        .eq('id', flag.resource_id)
        .single();
      resourceDetails = data;
    } else if (flag.resource_type === 'comment') {
      const { data } = await supabase
        .from('comments')
        .select('text, author_auth_user_id, video_id')
        .eq('id', flag.resource_id)
        .single();
      resourceDetails = data;
    } else if (flag.resource_type === 'profile') {
      const { data } = await supabase
        .from('profiles')
        .select('username, display_name, bio')
        .eq('id', flag.resource_id)
        .single();
      resourceDetails = data;
    }

    res.json({
      ...flag,
      resource_details: resourceDetails
    });
  } catch (error) {
    next(error);
  }
});

// POST /admin/flags/:id/action
// Body: { action: 'remove' | 'dismiss' | 'ban', admin_notes: string }
router.post('/:id/action', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { action, admin_notes } = req.body;

    const validActions = ['remove', 'dismiss', 'ban'];
    if (!validActions.includes(action)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid action. Must be one of: ${validActions.join(', ')}`
      });
    }

    // Get flag details
    const { data: flag, error: flagError } = await supabase
      .from('flags')
      .select('*')
      .eq('id', id)
      .single();

    if (flagError) {
      if (flagError.code === 'PGRST116') {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Flag not found'
        });
      }
      throw flagError;
    }

    if (flag.status !== 'pending') {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Flag has already been processed'
      });
    }

    // Perform action
    let actionResult = null;

    if (action === 'remove') {
      // Delete the flagged resource
      if (flag.resource_type === 'video') {
        const { error } = await supabase
          .from('videos')
          .delete()
          .eq('id', flag.resource_id);
        if (error) throw error;
        actionResult = 'Video removed';
      } else if (flag.resource_type === 'comment') {
        const { error } = await supabase
          .from('comments')
          .delete()
          .eq('id', flag.resource_id);
        if (error) throw error;
        actionResult = 'Comment removed';
      }
      
      // Update flag status
      await supabase
        .from('flags')
        .update({ status: 'resolved', admin_notes })
        .eq('id', id);

    } else if (action === 'dismiss') {
      // Just update flag status
      const { error } = await supabase
        .from('flags')
        .update({ status: 'dismissed', admin_notes })
        .eq('id', id);
      if (error) throw error;
      actionResult = 'Flag dismissed';

    } else if (action === 'ban') {
      // TODO: Implement user banning logic
      // For now, just mark flag as resolved
      const { error } = await supabase
        .from('flags')
        .update({ status: 'resolved', admin_notes: `BANNED: ${admin_notes}` })
        .eq('id', id);
      if (error) throw error;
      actionResult = 'User banned (placeholder - implement full ban logic)';
    }

    res.json({
      success: true,
      message: actionResult,
      flag_id: id,
      action: action
    });
  } catch (error) {
    next(error);
  }
});

// GET /admin/flags/stats
router.get('/stats/summary', async (req, res, next) => {
  try {
    const { data: stats, error } = await supabase
      .from('flags')
      .select('status');

    if (error) throw error;

    const summary = stats.reduce((acc, flag) => {
      acc[flag.status] = (acc[flag.status] || 0) + 1;
      return acc;
    }, {});

    res.json({
      total: stats.length,
      by_status: summary
    });
  } catch (error) {
    next(error);
  }
});

export default router;
