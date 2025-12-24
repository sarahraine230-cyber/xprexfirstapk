import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/video_player_screen.dart';

class ProfileVideoGrid extends StatelessWidget {
  final List<VideoModel> videos;
  
  // Receives the context
  final String? repostContextUsername;
  
  const ProfileVideoGrid({
    super.key, 
    required this.videos,
    this.repostContextUsername,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      // We handle empty state in the parent usually
      return const SizedBox.shrink();
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.7,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        final isProcessing = v.isProcessing; 

        return GestureDetector(
          onTap: isProcessing 
            ? null 
            : () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  videos: videos, 
                  initialIndex: index,
                  // HANDOFF: Passes it to the Player!
                  repostContextUsername: repostContextUsername,
                ),
              ));
            },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              if (v.coverImageUrl != null)
                Image.network(v.coverImageUrl!, fit: BoxFit.cover)
              else
                Container(color: Colors.grey[900]),
              
              // Processing Badge
              if (isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(height: 8),
                      Text('Processing', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              // View Count
              if (!isProcessing)
                Positioned(
                  bottom: 4, left: 4,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                      Text('${v.playbackCount}', style: const TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(blurRadius: 2, color: Colors.black)])),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
