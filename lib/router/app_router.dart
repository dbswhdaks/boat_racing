import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/iap_constants.dart';
import '../core/services/firebase_service.dart';
import '../features/home/screens/home_screen.dart';
import '../features/race/screens/race_detail_screen.dart';
import '../features/race/screens/race_result_screen.dart';
import '../features/racer/screens/racer_detail_screen.dart';
import '../features/settings/screens/api_settings_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Firebase 초기화가 placeholder 상태일 수도 있으므로 옵저버 생성을
/// 항상 try-catch 로 감싸 앱 기동을 방해하지 않게 한다.
List<NavigatorObserver> _buildNavigatorObservers() {
  try {
    return [FirebaseService.instance.routerObserver];
  } catch (_) {
    return const <NavigatorObserver>[];
  }
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: _buildNavigatorObservers(),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/race/:date/:raceNo',
      builder: (context, state) {
        final date = state.pathParameters['date'] ?? '';
        final raceNo = state.pathParameters['raceNo'] ?? '1';
        return RaceDetailScreen(date: date, raceNo: int.tryParse(raceNo) ?? 1);
      },
    ),
    GoRoute(
      path: '/result/:date/:raceNo',
      builder: (context, state) {
        final date = state.pathParameters['date'] ?? '';
        final raceNo = state.pathParameters['raceNo'] ?? '1';
        return RaceResultScreen(date: date, raceNo: int.tryParse(raceNo) ?? 1);
      },
    ),
    GoRoute(
      path: '/racer/:racerId',
      builder: (context, state) {
        final racerId = state.pathParameters['racerId'] ?? '';
        return RacerDetailScreen(racerId: racerId);
      },
    ),
    GoRoute(path: '/settings', builder: (context, state) => const ApiSettingsScreen()),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => SubscriptionScreen(
        initialProductId:
            state.uri.queryParameters['plan'] == IapConstants.yearlyProductId
            ? IapConstants.yearlyProductId
            : IapConstants.monthlyProductId,
      ),
    ),
  ],
);
