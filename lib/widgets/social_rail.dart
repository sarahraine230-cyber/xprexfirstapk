import 'package:flutter/material.dart';
import 'package:xprex/theme.dart';

class SocialRail extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onLike;
  
  final int commentsCount;
  final VoidCallback onComment;
  
  final bool isSaved;
  final int saveCount;
  final VoidCallback onSave;
  
  final bool isReposted;
  final int repostCount;
  final VoidCallback onRepost;
  
  final int shareCount;
  final VoidCallback onShare;

  const SocialRail({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onLike,
    required this.commentsCount,
    required this.onComment,
    required this.isSaved,
    required this.saveCount,
    required this.onSave,
    required this.isReposted,
    required this.repostCount,
    required this.onRepost,
    required this.shareCount,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Constant sizing for uniformity
    const double iconSize = 35.0; 
    const double gap = 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LIKE
        _RailItem(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isLiked ? const Color(0xFFFF2E54) : Colors.white,
          label: '$likeCount',
          size: iconSize,
          onTap: onLike,
        ),
        SizedBox(height: gap),
        
        // COMMENT
        _RailItem(
          icon: Icons.comment_rounded, // Use rounded variants for modern feel
          color: Colors.white,
          label: '$commentsCount',
          size: iconSize,
          onTap: onComment,
        ),
        SizedBox(height: gap),
        
        // SAVE
        _RailItem(
          icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isSaved ? Colors.amber : Colors.white,
          label: '$saveCount',
          size: iconSize,
          onTap: onSave,
        ),
        SizedBox(height: gap),
        
        // SHARE
        _RailItem(
          icon: Icons.reply_rounded, // The "Forward" style arrow looks cleaner for share
          color: Colors.white,
          label: '$shareCount',
          size: iconSize,
          onTap: onShare,
        ),
        SizedBox(height: gap),

        // REPOST
        _RailItem(
          icon: Icons.repeat_rounded,
          color: isReposted ? Colors.greenAccent : Colors.white,
          label: '$repostCount',
          size: iconSize,
          onTap: onRepost,
        ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // Optional: faint shadow behind icon to ensure visibility on bright videos
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                )
              ]
            ),
            child: Icon(
              icon, 
              size: size, 
              color: color,
              // Add a subtle drop shadow to the icon glyph itself
              shadows: const [
                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))
              ]
            ),
          ),
        ],
      ),
    );
  }
}
