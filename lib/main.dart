import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/api_constants.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/subscription/providers/in_app_purchase_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FCM 백그라운드 메시지 핸들러는 main 이전에 등록되어야 한다.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Future.wait([
    ApiConstants.loadServiceKey(),
    Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    ),
    // firebase_options.dart 가 아직 placeholder 인 경우 실패할 수 있으므로
    // 앱 기동을 막지 않도록 격리한다.
    _safeInitFirebase(),
  ]);

  runApp(const ProviderScope(child: BoatRacingApp()));
}

Future<void> _safeInitFirebase() async {
  try {
    await FirebaseService.instance.initialize();
  } catch (e, st) {
    // firebase_options 가 placeholder 이거나 google-services.json 이 없으면
    // 여기서 실패한다. 디버그 로그만 남기고 앱은 계속 동작하게 둔다.
    debugPrint('[Firebase init skipped] $e');
    if (kDebugMode) debugPrintStack(stackTrace: st);
  }
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
