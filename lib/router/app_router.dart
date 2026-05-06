import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/iap_constants.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/race/screens/race_detail_screen.dart';
import '../features/race/screens/race_result_screen.dart';
import '../features/racer/screens/racer_detail_screen.dart';
import '../features/settings/screens/api_settings_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
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
    GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
  ],
);
