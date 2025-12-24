import 'package:flutter/material.dart';
import 'package:xprex/theme.dart'; // Needed for Neon Theme extension

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
    final theme = Theme.of(context);
    final neon = theme.extension<NeonAccentTheme>();
    final h = MediaQuery.sizeOf(context).height;

    // Dynamic sizing logic (kept from your original code)
    final double _previous = (58.0 * (h / 800.0)).clamp(56.0, 64.0);
    final double iconSize = ((_previous * 1.82).clamp(90.0, 120.0)) * 2.0;
    
    const double baseIcon = 32.0;
    const double baseSmallGap = 6.0;
    const double baseGroupGap = 14.0;
    
    final double scaleRatio = iconSize / baseIcon;
    final double smallGap = (baseSmallGap * scaleRatio).clamp(5.0, 8.0);
    final double groupGap = (baseGroupGap * scaleRatio).clamp(12.0, 18.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NeonRailButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          size: iconSize,
          onTap: onLike,
          color: Colors.white,
          glow: neon?.purple ?? theme.colorScheme.primary,
        ),
        SizedBox(height: smallGap),
        _countBadge(likeCount, glowColor: neon?.purple ?? theme.colorScheme.primary),
        
        SizedBox(height: groupGap),
        
        _NeonRailButton(
          icon: Icons.comment,
          size: iconSize,
          onTap: onComment,
          color: Colors.white,
          glow: neon?.cyan ?? theme.colorScheme.secondary,
        ),
        SizedBox(height: smallGap),
        _countBadge(commentsCount, glowColor: neon?.cyan ?? theme.colorScheme.secondary),
        
        SizedBox(height: groupGap),
        
        _NeonRailButton(
          icon: Icons.share,
          size: iconSize,
          onTap: onShare,
          color: Colors.white,
          glow: neon?.blue ?? theme.colorScheme.tertiary,
        ),
        SizedBox(height: smallGap),
        _countBadge(shareCount, glowColor: neon?.blue ?? theme.colorScheme.tertiary),
        
        SizedBox(height: groupGap),
        
        _NeonRailButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          size: iconSize,
          onTap: onSave,
          color: Colors.white,
          glow: neon?.blue ?? theme.colorScheme.primary,
        ),
        SizedBox(height: smallGap),
        _countBadge(saveCount, glowColor: neon?.blue ?? theme.colorScheme.primary),
        
        SizedBox(height: groupGap),
        
        _NeonRailButton(
          icon: Icons.repeat,
          size: iconSize,
          onTap: onRepost,
          color: Colors.white,
          glow: neon?.purple ?? theme.colorScheme.secondary,
        ),
        SizedBox(height: smallGap),
        _countBadge(repostCount, glowColor: neon?.purple ?? theme.colorScheme.secondary),
      ],
    );
  }

  Widget _countBadge(int count, {Color? glowColor}) {
    return Text(
      '$count',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        shadows: [
          if (glowColor != null)
            BoxShadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _NeonRailButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color color;
  final Color glow;

  const _NeonRailButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
    required this.glow,
  });

  @override
  State<_NeonRailButton> createState() => _NeonRailButtonState();
}

class _NeonRailButtonState extends State<_NeonRailButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Basic sizing logic for the container based on icon size
    final double containerSize = widget.size + 10; 
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 45, // Fixed width for alignment
          height: 45,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Icon(widget.icon, size: 30, color: widget.color),
        ),
      ),
    );
  }
}
