import 'package:flutter/material.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/services/comment_service.dart';
import 'package:xprex/models/comment_model.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final String videoAuthorId;
  final int initialCount;
  final VoidCallback? onNewComment;
  final bool allowComments;

  const CommentsSheet({
    super.key,
    required this.videoId, 
    required this.videoAuthorId,
    required this.initialCount, 
    this.onNewComment,
    this.allowComments = true,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _svc = CommentService();
  final _inputCtrl = TextEditingController();
  late Future<List<CommentModel>> _loader;
  bool _posting = false;
  late int _commentsCount;
  CommentModel? _replyingTo;
  final List<String> _quickEmojis = ['🔥', '😂', '😍', '👏', '😢', '😮', '💯', '🙏'];

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.initialCount;
    _loader = _svc.getCommentsByVideo(widget.videoId);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _posting) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to comment')));
      return;
    }
    setState(() => _posting = true);
    try {
      String? parentId;
      if (_replyingTo != null) {
        parentId = _replyingTo!.parentId ?? _replyingTo!.id;
      }
      await _svc.createComment(
        videoId: widget.videoId, 
        authorAuthUserId: uid, 
        text: text,
        parentId: parentId,
      );
      
      _inputCtrl.clear();
      setState(() {
        _replyingTo = null; 
        _loader = _svc.getCommentsByVideo(widget.videoId);
        _commentsCount++;
        _posting = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment posted')));
      widget.onNewComment?.call();
    } catch (e) {
      setState(() => _posting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
    }
  }

  void _insertEmoji(String emoji) {
    _inputCtrl.text += emoji;
    _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _inputCtrl.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55, 
        minChildSize: 0.40,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    children: [
                      Text('Comments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (_commentsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(_commentsCount.toString(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: FutureBuilder<List<CommentModel>>(
                    future: _loader,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final items = snap.data ?? const <CommentModel>[];
                      if (items.isEmpty) return const Center(child: Text('No comments yet'));
                      
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final isCreator = items[i].authorAuthUserId == widget.videoAuthorId;
                          return _CommentRow(
                            comment: items[i],
                            isCreator: isCreator,
                            onReplyTap: (c) => setState(() => _replyingTo = c),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                      );
                    },
                  ),
                ),
                
                if (!widget.allowComments) 
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)))
                    ),
                    alignment: Alignment.center,
                    child: Text('Comments are turned off for this post.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  )
                else ...[
                  if (_replyingTo != null)
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text('Replying to @${_replyingTo!.authorUsername ?? "user"}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyingTo = null))
                        ],
                      ),
                    ),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)))),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickEmojis.length,
                      separatorBuilder: (_,__) => const SizedBox(width: 16),
                      itemBuilder: (ctx, i) => GestureDetector(onTap: () => _insertEmoji(_quickEmojis[i]), child: Center(child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 22)))),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 8),
                      child: Row(
                      children: [
                        const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            decoration: InputDecoration(
                              hintText: _replyingTo == null ? 'Add a comment...' : 'Add a reply...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(onPressed: _posting ? null : _post, icon: Icon(Icons.arrow_upward, color: _posting ? Colors.grey : theme.colorScheme.primary))
                      ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommentRow extends StatefulWidget {
  final CommentModel comment;
  final bool isCreator; 
  final Function(CommentModel) onReplyTap;
  
  const _CommentRow({
    required this.comment, 
    required this.isCreator,
    required this.onReplyTap
  });

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  final _svc = CommentService();
  late bool _isLiked;
  late int _likesCount;
  bool _isToggling = false;
  
  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likesCount = widget.comment.likesCount;
  }

  Future<void> _toggleLike() async {
    if (_isToggling) return;
    setState(() {
      _isToggling = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await _svc.toggleCommentLike(widget.comment.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to like comment")));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar [PROTOCOL UPDATE]
            CircleAvatar(
              radius: 20, 
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              // Check directly for valid URL
              backgroundImage: (c.authorAvatarUrl != null && c.authorAvatarUrl!.isNotEmpty) 
                  ? NetworkImage(c.authorAvatarUrl!) 
                  : null,
              // If no URL, show Icon
              child: (c.authorAvatarUrl == null || c.authorAvatarUrl!.isEmpty) 
                  ? const Icon(Icons.person, color: Colors.grey) 
                  : null,
            ),
            const SizedBox(width: 12),
            
            // 2. Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Row(
                    children: [
                      Text(
                        c.authorDisplayName ?? '@${c.authorUsername}', 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      if (c.authorIsPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                      ],
                      if (widget.isCreator) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Creator',
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w700, 
                              color: theme.colorScheme.error
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.text),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => widget.onReplyTap(c), 
                    child: Text(
                      'Reply', 
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)
                    )
                  ),
                ]
              )
            ),

            // 3. Like Button
            Column(
              children: [
                InkWell(
                  onTap: _toggleLike,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: _isLiked ? Colors.red : Colors.grey,
                  ),
                ),
                if (_likesCount > 0)
                  Text(
                    _likesCount.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
