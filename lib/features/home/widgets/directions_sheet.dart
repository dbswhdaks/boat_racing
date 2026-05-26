import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kBg = Color(0xFF0D1117);
const Color _kCard = Color(0xFF161B22);
const Color _kBorder = Color(0xFF30363D);
const Color _kPrimary = Color(0xFF1565C0);
const Color _kGold = Color(0xFFFBBF24);
const String _kAppName = 'com.boat_racing';

/// 경정 본장 + 장외발매소(지사) + 경정 공동발매 경륜장 데이터.
/// 출처: 사행산업통합감독위원회 사업자 일반현황(2024 기준) 및 KBOAT/KCYCLE 공식 안내.
/// - main   : 경정 본장 (미사리)
/// - shared : 경륜 본장/지점이지만 경정 공동발매 시행
/// - branch : 경정 장외발매소(KSPO)
/// 좌표는 WGS84(naver/구글 호환) 기준 주소 근사값.
enum _VenueKind { main, shared, branch }

class _BoatVenue {
  const _BoatVenue({
    required this.name,
    required this.region,
    required this.address,
    required this.lat,
    required this.lng,
    required this.transit,
    this.kind = _VenueKind.branch,
  });

  final String name;
  final String region;
  final String address;
  final double lat;
  final double lng;
  final String transit;
  final _VenueKind kind;
}

const List<_BoatVenue> _kVenues = [
  _BoatVenue(
    name: '미사리경정공원',
    region: '경기',
    address: '경기도 하남시 미사대로 505',
    lat: 37.5683,
    lng: 127.1925,
    transit: '경정 본장 · 5호선 미사역',
    kind: _VenueKind.main,
  ),
  _BoatVenue(
    name: '광명경륜장',
    region: '경기',
    address: '경기도 광명시 광명로 721',
    lat: 37.4631,
    lng: 126.8597,
    transit: '경륜 본장(경정 공동발매) · 7호선 광명사거리역',
    kind: _VenueKind.shared,
  ),
  _BoatVenue(
    name: '장안지사',
    region: '서울',
    address: '서울특별시 동대문구 장한로2길 33',
    lat: 37.5663,
    lng: 127.0635,
    transit: '5호선 장한평역 3번 출구',
  ),
  _BoatVenue(
    name: '성북지사',
    region: '서울',
    address: '서울특별시 성북구 동소문로 300',
    lat: 37.6038,
    lng: 127.0237,
    transit: '4호선 길음역 10번 출구',
  ),
  _BoatVenue(
    name: '강남지사',
    region: '서울',
    address: '서울특별시 강남구 학동로 171',
    lat: 37.5148,
    lng: 127.0317,
    transit: '7호선 학동역 6번 출구',
  ),
  _BoatVenue(
    name: '동대문지사',
    region: '서울',
    address: '서울특별시 중구 장충단로 263',
    lat: 37.5663,
    lng: 127.0093,
    transit: '2·4·5호선 동대문역사문화공원역',
  ),
  _BoatVenue(
    name: '관악지사',
    region: '서울',
    address: '서울특별시 관악구 신림로59길 23',
    lat: 37.4843,
    lng: 126.9296,
    transit: '2호선 신림역 3·4번 출구',
  ),
  _BoatVenue(
    name: '시흥지사',
    region: '경기',
    address: '경기도 시흥시 월곶중앙로 38',
    lat: 37.3416,
    lng: 126.7461,
    transit: '수인선 월곶역 1번 출구',
  ),
  _BoatVenue(
    name: '분당지사',
    region: '경기',
    address: '경기도 성남시 분당구 성남대로925번길 11',
    lat: 37.4108,
    lng: 127.1287,
    transit: '분당선 야탑역 4번 출구',
  ),
  _BoatVenue(
    name: '의정부지사',
    region: '경기',
    address: '경기도 의정부시 시민로 80',
    lat: 37.7384,
    lng: 127.0462,
    transit: '1호선 의정부역 2번 출구',
  ),
  _BoatVenue(
    name: '천안지사',
    region: '충남',
    address: '충청남도 천안시 서북구 두정로 220',
    lat: 36.8323,
    lng: 127.1552,
    transit: '1호선 두정역 1번 출구',
  ),
  _BoatVenue(
    name: '창원경륜장',
    region: '경남',
    address: '경상남도 창원시 성산구 원이대로 470',
    lat: 35.2230,
    lng: 128.6741,
    transit: '경륜 본장(경정 공동발매) · 창원중앙역',
    kind: _VenueKind.shared,
  ),
  _BoatVenue(
    name: '김해지점',
    region: '경남',
    address: '경상남도 김해시 분성로 321',
    lat: 35.2287,
    lng: 128.8826,
    transit: '경정 공동발매 · 부산김해경전철 부원역',
    kind: _VenueKind.shared,
  ),
  _BoatVenue(
    name: '부산금정경륜장',
    region: '부산',
    address: '부산광역시 금정구 체육공원로399번길 324',
    lat: 35.2521,
    lng: 129.1108,
    transit: '경륜 본장(경정 공동발매) · 1호선 노포역',
    kind: _VenueKind.shared,
  ),
  _BoatVenue(
    name: '부산광복지점',
    region: '부산',
    address: '부산광역시 중구 광복로 88',
    lat: 35.0986,
    lng: 129.0337,
    transit: '경정 공동발매 · 1호선 남포역 7번 출구',
    kind: _VenueKind.shared,
  ),
  _BoatVenue(
    name: '부산서면지점',
    region: '부산',
    address: '부산광역시 부산진구 서면로 25',
    lat: 35.1581,
    lng: 129.0594,
    transit: '경정 공동발매 · 1·2호선 서면역',
    kind: _VenueKind.shared,
  ),
];

const List<String> _kRegions = ['전체', '서울', '경기', '충남', '경남', '부산'];

Color _regionColor(String region) {
  switch (region) {
    case '서울':
      return const Color(0xFF38BDF8);
    case '경기':
      return const Color(0xFF22C55E);
    case '충남':
      return const Color(0xFFA78BFA);
    case '경남':
      return const Color(0xFFF472B6);
    case '부산':
      return const Color(0xFFFB923C);
    default:
      return const Color(0xFF94A3B8);
  }
}

IconData _iconFor(_VenueKind kind) {
  switch (kind) {
    case _VenueKind.main:
      return Icons.stadium_rounded;
    case _VenueKind.shared:
      return Icons.sports_score_rounded;
    case _VenueKind.branch:
      return Icons.location_on_rounded;
  }
}

enum _SortMode { distance, region }

/// 현재 위치에서의 직선거리를 km 단위로 일관되게 표시한다.
/// - 1km 미만: 소수 둘째 자리까지(예: 0.32km)
/// - 1~99km : 소수 첫째 자리까지(예: 4.2km, 87.3km)
/// - 100km↑ : 정수(예: 234km)
String _formatDistance(double meters) {
  final km = meters / 1000;
  if (km < 1) return '${km.toStringAsFixed(2)}km';
  if (km < 100) return '${km.toStringAsFixed(1)}km';
  return '${km.toStringAsFixed(0)}km';
}

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

class BoatVenuesDirectionsSheet extends StatefulWidget {
  const BoatVenuesDirectionsSheet({super.key});

  @override
  State<BoatVenuesDirectionsSheet> createState() =>
      _BoatVenuesDirectionsSheetState();
}

class _BoatVenuesDirectionsSheetState extends State<BoatVenuesDirectionsSheet> {
  String _region = '전체';
  _SortMode _sortMode = _SortMode.distance;
  Position? _userPosition;
  bool _locating = false;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _loadUserPosition();
  }

  /// 현재 위치 조회. 권한이 없거나 실패하면 지역순으로 fallback.
  Future<void> _loadUserPosition({bool requestIfDenied = true}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationDenied = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _sortMode = _SortMode.region;
            _locationDenied = true;
          });
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && requestIfDenied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _sortMode = _SortMode.region;
            _locationDenied = true;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() {
          _userPosition = pos;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sortMode = _SortMode.region;
          _locationDenied = true;
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? _distanceM(_BoatVenue venue) {
    final pos = _userPosition;
    if (pos == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      venue.lat,
      venue.lng,
    );
  }

  List<_BoatVenue> get _filtered {
    final base = _region == '전체'
        ? List<_BoatVenue>.from(_kVenues)
        : _kVenues.where((v) => v.region == _region).toList();
    if (_sortMode == _SortMode.distance && _userPosition != null) {
      base.sort((a, b) {
        final da = _distanceM(a) ?? double.infinity;
        final db = _distanceM(b) ?? double.infinity;
        return da.compareTo(db);
      });
    }
    return base;
  }

  int _countOf(String region) {
    if (region == '전체') return _kVenues.length;
    return _kVenues.where((v) => v.region == region).length;
  }

  Future<void> _onSortChanged(_SortMode mode) async {
    if (mode == _SortMode.distance && _userPosition == null) {
      await _loadUserPosition();
      if (_userPosition == null) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('위치 권한이 필요합니다. 설정에서 허용해 주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _sortMode = mode);
  }

  Future<void> _openTravelModeSheet(_BoatVenue venue) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TravelModeSheet(
        venue: venue,
        distanceMeters: _distanceM(venue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final bottomSafe = MediaQuery.of(context).padding.bottom;
        final filtered = _filtered;

        return Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
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
                        children: [
                          const Text(
                            '전국 경정장 가는길',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '본장 · 장외발매소 · 공동발매장 ${_kVenues.length}개소',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SortButton(
                      mode: _sortMode,
                      loading: _locating,
                      hasLocation: _userPosition != null,
                      onChanged: _onSortChanged,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _kRegions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final r = _kRegions[i];
                    return _RegionChip(
                      label: '$r (${_countOf(r)})',
                      selected: r == _region,
                      onTap: () => setState(() => _region = r),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomSafe),
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == filtered.length) {
                      final locationLine = _locationDenied
                          ? '* 위치 권한이 거부되어 거리순 정렬은 사용할 수 없습니다.\n'
                          : (_userPosition == null && _locating)
                              ? '* 현재 위치를 확인 중입니다...\n'
                              : (_userPosition != null
                                  ? '* "가까운 순"은 현재 위치 기준 직선거리입니다.\n'
                                  : '');
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                        child: Text(
                          '$locationLine'
                          '* 경정 경주는 매주 수·목요일 미사리 본장에서 진행됩니다.\n'
                          '* "공동발매"는 경륜 본장·지점에서 경정 경주권을 함께 발매하는 곳입니다.\n'
                          '* 카드 탭 시 네이버 지도(앱 우선)로 길찾기가 열립니다.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      );
                    }
                    final v = filtered[i];
                    return _VenueTile(
                      venue: v,
                      distanceMeters: _distanceM(v),
                      onTap: () => _openTravelModeSheet(v),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : Colors.transparent,
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({
    required this.venue,
    required this.onTap,
    this.distanceMeters,
  });

  final _BoatVenue venue;
  final double? distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final regionColor = _regionColor(venue.region);
    final distance = distanceMeters;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: _kBg,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: regionColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(venue.kind),
                  color: regionColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(
                          label: venue.region,
                          color: regionColor,
                        ),
                        if (venue.kind == _VenueKind.main) ...[
                          const SizedBox(width: 6),
                          const _Tag(label: '본장', color: _kGold),
                        ] else if (venue.kind == _VenueKind.shared) ...[
                          const SizedBox(width: 6),
                          const _Tag(
                            label: '공동발매',
                            color: Color(0xFF38BDF8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      venue.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      venue.address,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.directions_transit_rounded,
                            color: Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue.transit,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distance != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                        border: Border.all(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: Color(0xFF38BDF8),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDistance(distance),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_rounded,
                            color: _kPrimary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '길찾기',
                          style: TextStyle(
                            color: _kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TravelModeSheet extends StatelessWidget {
  const _TravelModeSheet({required this.venue, this.distanceMeters});

  final _BoatVenue venue;
  final double? distanceMeters;

  /// 시트를 먼저 닫고 네이버 지도(앱→웹 순)로 길찾기를 연다.
  /// 출발지를 비워두면 네이버 지도가 단말의 현재 위치를 자동으로 사용한다.
  Future<void> _onSelect(BuildContext context, _TravelMode mode) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);

    final dname = Uri.encodeComponent(venue.name);
    final appName = Uri.encodeComponent(_kAppName);

    final appUri = Uri.parse(
      'nmap://route/${mode.nmapPath}'
      '?dlat=${venue.lat}'
      '&dlng=${venue.lng}'
      '&dname=$dname'
      '&appname=$appName',
    );

    final webUri = Uri.parse(
      'https://map.naver.com/p/directions/-'
      '/${venue.lng},${venue.lat},$dname'
      '/-/${mode.webPath}',
    );

    navigator.pop();

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
    await Clipboard.setData(ClipboardData(text: venue.address));
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
    final regionColor = _regionColor(venue.region);
    final distance = distanceMeters;

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
                  color: regionColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(venue.kind),
                  color: regionColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(label: venue.region, color: regionColor),
                        if (venue.kind == _VenueKind.main) ...[
                          const SizedBox(width: 6),
                          const _Tag(label: '본장', color: _kGold),
                        ] else if (venue.kind == _VenueKind.shared) ...[
                          const SizedBox(width: 6),
                          const _Tag(
                            label: '공동발매',
                            color: Color(0xFF38BDF8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      venue.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      venue.address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (distance != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: Color(0xFF38BDF8),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '현재 위치에서 ${_formatDistance(distance)}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                onTap: () => _onSelect(context, m),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '* 네이버 지도 앱이 설치돼 있으면 현재 위치 기반으로 자동 안내됩니다.',
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

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.mode,
    required this.loading,
    required this.hasLocation,
    required this.onChanged,
  });

  final _SortMode mode;
  final bool loading;
  final bool hasLocation;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDistance = mode == _SortMode.distance;
    final activeColor = isDistance && hasLocation
        ? const Color(0xFF38BDF8)
        : Colors.white70;

    return PopupMenuButton<_SortMode>(
      tooltip: '정렬 방식',
      initialValue: mode,
      color: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _kBorder),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        _menuItem(
          value: _SortMode.distance,
          icon: Icons.near_me_rounded,
          label: '가까운 순',
          selected: mode == _SortMode.distance,
        ),
        _menuItem(
          value: _SortMode.region,
          icon: Icons.map_rounded,
          label: '지역 순',
          selected: mode == _SortMode.region,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Color(0xFF38BDF8),
                ),
              )
            else
              Icon(
                isDistance ? Icons.near_me_rounded : Icons.map_rounded,
                color: activeColor,
                size: 13,
              ),
            const SizedBox(width: 5),
            Text(
              isDistance ? '가까운순' : '지역순',
              style: TextStyle(
                color: activeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: activeColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_SortMode> _menuItem({
    required _SortMode value,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return PopupMenuItem<_SortMode>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xFF38BDF8) : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF38BDF8) : Colors.white,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (selected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded,
                color: Color(0xFF38BDF8), size: 14),
          ],
        ],
      ),
    );
  }
}

Future<void> showBoatVenuesDirectionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const BoatVenuesDirectionsSheet(),
  );
}
