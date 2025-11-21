import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_call_outlined, size: 100, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Upload Feature', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                kIsWeb
                    ? 'Video upload is not fully supported in web preview.\n\nPlease test on a mobile device for full functionality.'
                    : 'Video upload feature will be implemented here.\n\nSelect a video, add title and description, then upload to Supabase storage.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: kIsWeb ? null : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video picker to be implemented. See IMPLEMENTATION_GUIDE.md')),
                  );
                },
                icon: Icon(Icons.video_library),
                label: Text('Select Video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
