import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// 백그라운드(앱 종료/슬립 포함)에서 수신된 FCM 메시지 핸들러.
///
/// 반드시 top-level 함수여야 하며, `@pragma('vm:entry-point')` 가 필요하다.
/// 내부에서 Firebase API를 사용하려면 먼저 `Firebase.initializeApp()` 호출이
/// 필요하다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 필요한 경우 여기에서 알림 후처리(분석/로깅 등)를 수행한다.
  // 백그라운드 isolate 이므로 UI 갱신은 불가하다.
  debugPrint('[FCM bg] ${message.messageId} ${message.notification?.title}');
}

/// 앱 전체 Firebase 통합 초기화·접근점.
///
/// `FirebaseService.instance` 로 어디서나 동일 인스턴스를 사용한다.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;

  late final FirebaseAnalytics analytics;
  late final FirebaseCrashlytics crashlytics;
  late final FirebaseMessaging messaging;
  late final FirebaseRemoteConfig remoteConfig;

  /// 앱 시작 시 main()에서 한 번만 호출한다.
  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    analytics = FirebaseAnalytics.instance;
    crashlytics = FirebaseCrashlytics.instance;
    messaging = FirebaseMessaging.instance;
    remoteConfig = FirebaseRemoteConfig.instance;

    await _setupCrashlytics();
    await _setupRemoteConfig();
    await _setupMessaging();

    _initialized = true;
  }

  /// Flutter / Dart 미처리 예외를 모두 Crashlytics 로 보고하도록 후킹한다.
  Future<void> _setupCrashlytics() async {
    // 디버그 모드에서는 리포트를 끄고, 릴리스에서만 수집한다.
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Remote Config 기본값/페치 주기 설정.
  /// 키 추가가 필요하면 [_defaults] 만 수정하면 된다.
  Future<void> _setupRemoteConfig() async {
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const <String, Object>{
        'race_start_alert_enabled': true,
        'force_update_min_build': 0,
        'maintenance_message': '',
      });
      unawaited(remoteConfig.fetchAndActivate());
    } catch (e, st) {
      await crashlytics.recordError(e, st, reason: 'remote_config_init');
    }
  }

  /// FCM 토큰 로깅 + 포그라운드 표시 옵션.
  /// 실제 알림 UI 노출(포그라운드)은 flutter_local_notifications 등으로
  /// 별도 처리하는 것이 일반적이다. 현재는 시스템 기본 동작을 사용한다.
  Future<void> _setupMessaging() async {
    try {
      // iOS 포그라운드에서도 알림 배너/소리/배지 표시
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 토큰은 디버그 로깅 + Analytics user_property 로 보관
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[FCM token] $token');
        await analytics.setUserProperty(name: 'fcm_token_set', value: 'true');
      }

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM token refresh] $newToken');
      });
    } catch (e, st) {
      await crashlytics.recordError(e, st, reason: 'fcm_init');
    }
  }

  /// 화면 진입 등 이벤트를 손쉽게 기록하기 위한 헬퍼.
  Future<void> logEvent(String name, [Map<String, Object>? params]) {
    return analytics.logEvent(name: name, parameters: params);
  }

  /// 화면 추적용 라우터 옵저버.
  /// `MaterialApp.router(... navigatorObservers: [...] )` 또는
  /// go_router 의 `observers` 옵션에 주입한다.
  FirebaseAnalyticsObserver get routerObserver =>
      FirebaseAnalyticsObserver(analytics: analytics);
}
