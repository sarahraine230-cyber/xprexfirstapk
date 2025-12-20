class Secrets {
  // Cloudflare R2 Credentials
  static const String r2AccessKey = '340c47bd211eb9473d54bf8f8ef8ae3c';
  static const String r2SecretKey = 'c54c1f9c2e308e73b9e00acf6e0f9219d8d3676365c0d660a5746058c2b65664';
  
  // The Account ID Endpoint (for S3 Clients)
  // Format: https://<accountid>.r2.cloudflarestorage.com
  static const String r2Endpoint = 'https://4105d4cbf23b2183000555fbd2eca29b.r2.cloudflarestorage.com';
  
  // The Bucket Name you created
  static const String r2BucketName = 'xprex-videos'; 

  // --- CRITICAL STEP FOR YOU ---
  // Go to Cloudflare Dashboard -> R2 -> Select Bucket -> Settings -> Public Access
  // Copy the "R2.dev subdomain" (or your Custom Domain if you connected one).
  // It should look like: https://pub-xxxxxxxx.r2.dev
  // DO NOT include a trailing slash.
  static const String r2PublicDomain = 'https://pub-6a33f747461a43d7a06b0cd298966ab6.r2.dev'; 
}
