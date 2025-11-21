import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/router/app_router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }
  
  runApp(const ProviderScope(child: XpreXApp()));
}

class XpreXApp extends ConsumerWidget {
  const XpreXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'XpreX',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
