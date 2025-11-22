import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static late final SupabaseClient client;
  static late final String urlValue;
  static late final String anonKeyValue;
  
  static Future<void> initialize() async {
    // Prefer environment variables from build, fallback to provided values from user
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://svyuxdowffweanjjzvis.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2eXV4ZG93ZmZ3ZWFuamp6dmlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzODI2NzYsImV4cCI6MjA3ODk1ODY3Nn0.YZqPUaeJKp7kdc_FPBoPfoIruDpTka3ptCmanGpMjR0',
    );
    
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ WARNING: Supabase credentials not found! Falling back to defaults failed.');
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    
    client = Supabase.instance.client;
    urlValue = supabaseUrl;
    anonKeyValue = supabaseAnonKey;
    debugPrint('✅ Supabase initialized successfully');
  }
}

SupabaseClient get supabase => SupabaseConfig.client;
