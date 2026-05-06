import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/api_constants.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/subscription/providers/in_app_purchase_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ApiConstants.loadServiceKey(),
    Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    ),
  ]);
  runApp(const ProviderScope(child: BoatRacingApp()));
}

class BoatRacingApp extends ConsumerWidget {
  const BoatRacingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 앱 시작 시 IAP 상태(구독/상품) 초기화 트리거
    ref.watch(inAppPurchaseProvider);

    return MaterialApp.router(
      title: '경정 Plus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
