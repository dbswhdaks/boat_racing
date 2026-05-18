import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kCard = Color(0xFF161B22);
const Color _kBorder = Color(0xFF30363D);
const Color _kPrimary = Color(0xFF1565C0);

/// 미사리경정공원 좌표 (WGS84)
/// 주소: 경기도 하남시 미사대로 505
const double _kMisariLat = 37.5683;
const double _kMisariLng = 127.1925;
const String _kMisariName = '미사리경정공원';
const String _kMisariAddress = '경기도 하남시 미사대로 505';
const String _kAppName = 'com.boat_racing';

enum _TravelMode { walk, transit, car }

extension _TravelModeMeta on _TravelMode {
  String get label {
    switch (this) {
      case _TravelMode.walk:
        return '걸어가기';
      case _TravelMode.transit:
        return '대중교통';
      case _TravelMode.car:
        return '자가용';
    }
  }

  String get description {
    switch (this) {
      case _TravelMode.walk:
        return '도보 경로 안내';
      case _TravelMode.transit:
        return '버스·지하철 경로 안내';
      case _TravelMode.car:
        return '실시간 자동차 길찾기';
    }
  }

  IconData get icon {
    switch (this) {
      case _TravelMode.walk:
        return Icons.directions_walk_rounded;
      case _TravelMode.transit:
        return Icons.directions_transit_rounded;
      case _TravelMode.car:
        return Icons.directions_car_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _TravelMode.walk:
        return const Color(0xFF22C55E);
      case _TravelMode.transit:
        return const Color(0xFF38BDF8);
      case _TravelMode.car:
        return const Color(0xFFFBBF24);
    }
  }

  /// 네이버 지도 앱 스킴 경로 (`nmap://route/{path}`)
  String get nmapPath {
    switch (this) {
      case _TravelMode.walk:
        return 'walk';
      case _TravelMode.transit:
        return 'public';
      case _TravelMode.car:
        return 'car';
    }
  }

  /// 네이버 지도 웹 길찾기 경로 (`/-/{path}`)
  String get webPath {
    switch (this) {
      case _TravelMode.walk:
        return 'walk';
      case _TravelMode.transit:
        return 'transit';
      case _TravelMode.car:
        return 'car';
    }
  }
}

class MisariDirectionsSheet extends StatelessWidget {
  const MisariDirectionsSheet({super.key});

  Future<void> _launch(BuildContext context, _TravelMode mode) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final dname = Uri.encodeComponent(_kMisariName);
    final appName = Uri.encodeComponent(_kAppName);

    final appUri = Uri.parse(
      'nmap://route/${mode.nmapPath}'
      '?dlat=$_kMisariLat'
      '&dlng=$_kMisariLng'
      '&dname=$dname'
      '&appname=$appName',
    );

    final webUri = Uri.parse(
      'https://map.naver.com/p/directions/-'
      '/$_kMisariLng,$_kMisariLat,$dname'
      '/-/${mode.webPath}',
    );

    bool launched = false;
    try {
      if (await canLaunchUrl(appUri)) {
        launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('네이버 지도를 열 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyAddress(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(const ClipboardData(text: _kMisariAddress));
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('주소가 복사되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomSafe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_boat_rounded,
                  color: _kPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '미사리 경정장 가는길',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _kMisariAddress,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '주소 복사',
                onPressed: () => _copyAddress(context),
                icon: const Icon(
                  Icons.content_copy_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._TravelMode.values.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DirectionOption(
                mode: m,
                onTap: () {
                  Navigator.of(context).pop();
                  _launch(context, m);
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '* 네이버 지도 앱이 설치되어 있으면 앱으로, 없으면 웹으로 열립니다.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({required this.mode, required this.onTap});

  final _TravelMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mode.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(mode.icon, color: mode.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMisariDirectionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MisariDirectionsSheet(),
  );
}
