import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/shimmer_loading.dart';
import '../../../features/race/providers/race_providers.dart';
import '../../../models/race.dart';
import '../widgets/directions_sheet.dart';
import '../widgets/month_calendar_sheet.dart';
import '../widgets/race_card.dart';

const Color _kBg = Color(0xFF0D1117);
const Color _kCard = Color(0xFF161B22);
const Color _kPrimary = Color(0xFF1565C0);
const Color _kGold = Color(0xFFFBBF24);

final _lastRefreshProvider = StateProvider<DateTime?>((ref) => null);
final _autoRefreshEnabledProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;
  Timer? _displayTimer;
  bool _hasData = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimers();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _displayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNow();
    }
  }

  void _startTimers() {
    _autoRefreshTimer?.cancel();
    _displayTimer?.cancel();
    final interval = _hasData ? 60 : 30;
    _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted) return;
      if (ref.read(_autoRefreshEnabledProvider)) {
        _refreshNow();
      }
    });
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onDataChanged(bool hasData) {
    if (hasData != _hasData) {
      _hasData = hasData;
      _startTimers();
    }
  }

  void _refreshNow() {
    final selected = ref.read(selectedDateProvider);
    final ymd = dateToYmd(selected);
    ref.read(kboatScraperProvider).invalidateForRefresh();
    ref.invalidate(raceListProvider((date: ymd)));
    ref.read(_lastRefreshProvider.notifier).state = DateTime.now();
  }

  void _shiftDate(int days) {
    final d = ref.read(selectedDateProvider).add(Duration(days: days));
    ref.read(selectedDateProvider.notifier).state =
        DateTime(d.year, d.month, d.day);
  }

  String _formatKoreanDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final w = weekdays[d.weekday - 1];
    return '${d.year}년 ${d.month}월 ${d.day}일 ($w)';
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '—';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return '방금 업데이트됨';
    if (diff.inSeconds < 60) return '${diff.inSeconds}초 전 업데이트';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 업데이트';
    return '${diff.inHours}시간 전 업데이트';
  }

  Future<void> _openCalendar() async {
    final current = ref.read(selectedDateProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonthCalendarSheet(initialDay: current),
    );
  }

  Future<void> _shareApp() async {
    await Share.share(
      '경정 Plus — 미사리경정공원 경정 정보 앱',
      subject: '경정 Plus',
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDateProvider);
    final ymd = dateToYmd(selected);
    final asyncRaces = ref.watch(raceListProvider((date: ymd)));

    ref.listen<AsyncValue<DataWithSource<List<Race>>>>(
      raceListProvider((date: ymd)),
      (prev, next) {
        next.whenData((wrapped) {
          ref.read(_lastRefreshProvider.notifier).state = DateTime.now();
          _onDataChanged(wrapped.data.isNotEmpty);
        });
      },
    );

    final lastRefresh = ref.watch(_lastRefreshProvider);
    final autoOn = ref.watch(_autoRefreshEnabledProvider);

    return Scaffold(
      backgroundColor: _kBg,
      endDrawer: const _HomeDrawer(),
      appBar: AppBar(
        backgroundColor: _kCard,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '경정 Plus',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '공유',
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareApp,
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateSelectorRow(
            label: _formatKoreanDate(selected),
            onPrev: () => _shiftDate(-1),
            onNext: () => _shiftDate(1),
            onCalendarTap: _openCalendar,
          ),
          _UpdateMetaRow(
            lastRefresh: lastRefresh,
            formatTime: _formatTime,
            asyncRaces: asyncRaces,
            autoRefreshEnabled: autoOn,
            onAutoRefreshChanged: (v) =>
                ref.read(_autoRefreshEnabledProvider.notifier).state = v,
            onManualRefresh: _refreshNow,
          ),
          Expanded(
            child: asyncRaces.when(
              loading: () => const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ShimmerRaceList(),
              ),
              error: (e, st) => _HomeError(
                message: e.toString(),
                onRetry: _refreshNow,
              ),
              data: (wrapped) {
                final races = wrapped.data;
                if (races.isEmpty) {
                  return _HomeEmpty(
                    onRefresh: _refreshNow,
                    autoRefreshEnabled: autoOn,
                  );
                }
                final bottomSafe = MediaQuery.of(context).padding.bottom;
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomSafe),
                  itemCount: races.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RaceCard(race: races[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSelectorRow extends StatelessWidget {
  const _DateSelectorRow({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onCalendarTap,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
            ),
            Expanded(
              child: InkWell(
                onTap: onCalendarTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: _kPrimary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateMetaRow extends StatelessWidget {
  const _UpdateMetaRow({
    required this.lastRefresh,
    required this.formatTime,
    required this.asyncRaces,
    required this.autoRefreshEnabled,
    required this.onAutoRefreshChanged,
    required this.onManualRefresh,
  });

  final DateTime? lastRefresh;
  final String Function(DateTime?) formatTime;
  final AsyncValue<DataWithSource<List<Race>>> asyncRaces;
  final bool autoRefreshEnabled;
  final ValueChanged<bool> onAutoRefreshChanged;
  final VoidCallback onManualRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatTime(lastRefresh),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('자동', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: autoRefreshEnabled,
                onChanged: onAutoRefreshChanged,
                activeThumbColor: _kPrimary,
              ),
              IconButton(
                tooltip: '지금 새로고침',
                onPressed: onManualRefresh,
                icon: const Icon(Icons.refresh_rounded, color: _kGold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({required this.onRefresh, this.autoRefreshEnabled = true});

  final VoidCallback onRefresh;
  final bool autoRefreshEnabled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_boat_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            const Text(
              '이 날짜에 예정된 경주가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  void _openDirections(BuildContext context) {
    // drawer를 닫은 직후엔 drawer의 context가 unmount 직전 상태가 되어
    // showModalBottomSheet이 정상 동작하지 않는다.
    // root navigator의 context를 미리 잡아두고 sheet을 띄운다.
    final rootContext =
        Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    showBoatVenuesDirectionsSheet(rootContext);
  }

  Future<void> _openPlayStore(BuildContext context, String packageId) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    final marketUri = Uri.parse('market://details?id=$packageId');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageId',
    );

    try {
      final ok = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {}

    try {
      final ok = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Play 스토어를 열 수 없습니다.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Play 스토어를 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: _kCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF0097A7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 36,
                          height: 36,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '경정 Plus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '미사리경정공원 경주 정보·예측',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                children: [
                  const _DrawerSectionHeader(
                    icon: Icons.apps_rounded,
                    label: '추천 앱',
                  ),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.sports_score_rounded,
                    iconColor: const Color(0xFFEF4444),
                    label: '경마Plus',
                    subtitle: 'AI 경마 예상 · 실시간 경주결과',
                    isExternal: true,
                    onTap: () => _openPlayStore(
                      context,
                      'com.horseracingplus.app',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.pedal_bike_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    label: '경륜Plus',
                    subtitle: '실시간 경륜정보 · 경기 결과',
                    isExternal: true,
                    onTap: () => _openPlayStore(
                      context,
                      'com.gyeongryunplus.app',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _DrawerSectionHeader(
                    icon: Icons.dashboard_customize_rounded,
                    label: '바로가기',
                  ),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.directions_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    label: '전국 경정장 가는길',
                    subtitle: '미사리 · 하남 경정공원 안내',
                    onTap: () => _openDirections(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF30363D), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                '경정 Plus',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF30363D).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isExternal = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isExternal;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1C232D);
    const borderColor = Color(0xFF262E38);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: iconColor.withValues(alpha: 0.12),
        highlightColor: iconColor.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        iconColor.withValues(alpha: 0.22),
                        iconColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExternal
                      ? Icons.open_in_new_rounded
                      : Icons.chevron_right_rounded,
                  size: isExternal ? 16 : 20,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
