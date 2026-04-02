import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/race.dart';

const Color _kCard = Color(0xFF161B22);
const Color _kBorder = Color(0xFF30363D);

class RaceCard extends StatefulWidget {
  const RaceCard({super.key, required this.race});

  final Race race;

  @override
  State<RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends State<RaceCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (_shouldRunCountdown) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(RaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final should = _shouldRunCountdown;
    final was = _shouldRunCountdownFor(oldWidget.race);
    if (should != was) {
      _tick?.cancel();
      _tick = null;
      if (should) {
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  bool get _shouldRunCountdown => _shouldRunCountdownFor(widget.race);

  bool _shouldRunCountdownFor(Race r) {
    if (_isFinished(r)) return false;
    final d = _timeUntilStart(r);
    return d != null && d > Duration.zero;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool _isFinished(Race r) {
    final s = r.status;
    return s == '종료' || s == '확정' || s == '완료';
  }

  Duration? _timeUntilStart(Race r) {
    final t = r.departureTime;
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].trim()) ?? 0;
    final cleaned = r.date.replaceAll('.', '').replaceAll('-', '');
    if (cleaned.length < 8) return null;
    final y = int.tryParse(cleaned.substring(0, 4)) ?? 0;
    final mo = int.tryParse(cleaned.substring(4, 6)) ?? 0;
    final d = int.tryParse(cleaned.substring(6, 8)) ?? 0;
    final start = DateTime(y, mo, d, h, m);
    return start.difference(DateTime.now());
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '진행중';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 ${m}분 후';
    return '${m}분 후';
  }

  Color _raceNoColor(int no) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF97316),
      Color(0xFF14B8A6),
      Color(0xFF06B6D4),
    ];
    return colors[(no - 1) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.race;
    final finished = _isFinished(r);
    final diff = _timeUntilStart(r);
    final timeStr = r.departureTime ?? '';
    final rColor = _raceNoColor(r.raceNo);
    final hasDiff = !finished && diff != null && diff > Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/race/${r.date}/${r.raceNo}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 왼쪽: 레이스 번호 원형 ---
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${r.raceNo}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // --- 가운데: 정보 영역 ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1행: 일반 + 카운트다운
                      Row(
                        children: [
                          const Text(
                            '일반',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (hasDiff) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A5F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: Color(0xFF60A5FA),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _formatCountdown(diff),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF93C5FD),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (finished) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '종료',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2행: 경기장 · 거리
                      Text(
                        '${r.venueName} · ${r.distance}m',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3행: 인원 + 거리
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${r.racerCount}명',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(
                            Icons.straighten_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${r.distance}m',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 오른쪽: 시간 + 상세 ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 시간
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: finished
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          height: 1,
                        ),
                      ),
                    const SizedBox(height: 30),

                    // 상세 버튼
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: rColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: rColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: rColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '상세',
                            style: TextStyle(
                              color: rColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
      ),
    );
  }
}
