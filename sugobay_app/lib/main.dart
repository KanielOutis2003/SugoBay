import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants.dart';
import 'core/supabase_client.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Keep placeholder fallbacks working if .env has not been filled yet.
  }

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: SugoBayApp()));
}

class SugoBayApp extends ConsumerWidget {
  const SugoBayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBg,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.white),
        ),
        colorScheme: ColorScheme.dark(
          primary: AppColors.teal,
          secondary: AppColors.coral,
          surface: AppColors.cardBg,
        ),
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
