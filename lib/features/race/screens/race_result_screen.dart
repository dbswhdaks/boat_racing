import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../models/prediction.dart';
import '../../../models/race.dart';
import '../../../models/race_entry.dart';
import '../../../models/race_result.dart';
import '../providers/race_providers.dart';

double _comprehensiveScore(RaceEntry e) {
  const gradeScores = {'A1': 10.0, 'A2': 7.5, 'B1': 5.0, 'B2': 3.0};
  final g = gradeScores[e.grade] ?? 4.0;
  return g * 2.0 + e.avgScore * 1.5 + e.recent3Wins * 2.0;
}

const _bg = Color(0xFF0D1117);
const _card = Color(0xFF161B22);
const _accent = Color(0xFFFBBF24);
const _border = Color(0xFF30363D);

bool _isNotYet(Object? error) =>
    error is Exception && error.toString().contains('NOT_YET');

int? _rankValue(Map<String, dynamic> row) {
  final rankRaw = row['race_rank'] ?? row['rank'];
  if (rankRaw is int) return rankRaw;
  if (rankRaw is num) return rankRaw.toInt();
  return int.tryParse('$rankRaw');
}

int? _courseNo(Map<String, dynamic> row) {
  final v = row['course_no'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

String _racerNm(Map<String, dynamic> row) {
  final v = row['racer_nm'];
  return v?.toString() ?? '-';
}

Color _courseColor(int courseNo) {
  switch (courseNo) {
    case 1:
      return const Color(0xFFD4D4D4);
    case 2:
      return const Color(0xFF333333);
    case 3:
      return const Color(0xFFEF4444);
    case 4:
      return const Color(0xFF3B82F6);
    case 5:
      return const Color(0xFFFBBF24);
    case 6:
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _courseTextColor(int courseNo) {
  if (courseNo == 1 || courseNo == 5) return const Color(0xFF1A1A1A);
  return Colors.white;
}

class RaceResultScreen extends ConsumerStatefulWidget {
  const RaceResultScreen(
      {super.key, required this.date, required this.raceNo});

  final String date;
  final int raceNo;

  @override
  ConsumerState<RaceResultScreen> createState() => _RaceResultScreenState();
}

class _RaceResultScreenState extends ConsumerState<RaceResultScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (_isToday(widget.date)) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        _refresh();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isToday(String ymd) {
    final now = DateTime.now();
    final t =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return ymd == t;
  }

  void _refresh() {
    final p = (date: widget.date, raceNo: widget.raceNo);
    ref.invalidate(raceResultProvider(p));
    ref.invalidate(raceRankProvider(p));
    ref.invalidate(raceEntriesProvider(p));
    ref.invalidate(oddsProvider(p));
    ref.invalidate(predictionProvider(p));
  }

  String _formatYmdKorean(String ymd) {
    if (ymd.length != 8) return ymd;
    final y = ymd.substring(0, 4);
    final m = ymd.substring(4, 6);
    final d = ymd.substring(6, 8);
    return '$y년 $m월 $d일';
  }

  @override
  Widget build(BuildContext context) {
    final p = (date: widget.date, raceNo: widget.raceNo);
    final resultAsync = ref.watch(raceResultProvider(p));
    final rankAsync = ref.watch(raceRankProvider(p));
    final entriesAsync = ref.watch(raceEntriesProvider(p));
    final predAsync = ref.watch(predictionProvider(p));
    final racesAsync = ref.watch(raceListProvider((date: widget.date)));

    String venueName = '미사리경정공원';
    String raceStatus = '예정';
    final raceList = racesAsync.valueOrNull?.data ?? const <Race>[];
    if (raceList.isNotEmpty) {
      Race? matchedRace;
      for (final r in raceList) {
        if (r.raceNo == widget.raceNo) {
          matchedRace = r;
          break;
        }
      }
      final baseRace = matchedRace ?? raceList.first;
      venueName = baseRace.venueName;
      raceStatus = baseRace.status;
    }

    final rankRows = rankAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final finalizedRanks = rankRows
        .where((r) {
          final rank = _rankValue(r);
          return rank != null && rank > 0;
        })
        .toList()
      ..sort((a, b) => (_rankValue(a) ?? 99).compareTo(_rankValue(b) ?? 99));

    final hasResultData = resultAsync.valueOrNull != null;
    final hasFinalRankData = finalizedRanks.isNotEmpty;
    final resultNotYet = resultAsync.hasError && _isNotYet(resultAsync.error);
    final rankNotYet = rankAsync.hasError && _isNotYet(rankAsync.error);
    final isMarkedFinished =
        raceStatus == '확정' || raceStatus == '종료' || raceStatus == '완료';

    final preRace = !isMarkedFinished &&
        !hasResultData &&
        !hasFinalRankData &&
        (resultNotYet || rankNotYet);

    RaceResult? fallbackResult;
    if (!hasResultData && finalizedRanks.length >= 3) {
      fallbackResult = RaceResult(
        raceNo: widget.raceNo,
        first: _racerNm(finalizedRanks[0]),
        firstNo: _courseNo(finalizedRanks[0]) ?? 0,
        second: _racerNm(finalizedRanks[1]),
        secondNo: _courseNo(finalizedRanks[1]) ?? 0,
        third: _racerNm(finalizedRanks[2]),
        thirdNo: _courseNo(finalizedRanks[2]) ?? 0,
        winOdds: 0,
        placeOdds: 0,
        quinellaOdds: 0,
      );
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFBBF24),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ).createShader(bounds),
              child: Text(
                '$venueName ${widget.raceNo}R 결과',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateBadge(
                      date: _formatYmdKorean(widget.date),
                      status: raceStatus,
                      isToday: _isToday(widget.date),
                    ),
                    const SizedBox(height: 12),
                    _VideoRow(date: widget.date, raceNo: widget.raceNo),
                    const SizedBox(height: 20),
                    if (preRace)
                      _PreRaceCard(onRetry: _refresh)
                    else ...[
                      resultAsync.when(
                        data: (r) => _PodiumSection(result: r),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                              child:
                                  CircularProgressIndicator(color: _accent)),
                        ),
                        error: (e, _) {
                          if (_isNotYet(e) && fallbackResult != null) {
                            return _PodiumSection(result: fallbackResult);
                          }
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _isNotYet(e) ? '경주 결과 집계 중입니다.' : '경주 결과를 불러오지 못했습니다.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildComparison(entriesAsync, predAsync, resultAsync),
                      const SizedBox(height: 24),
                      resultAsync.maybeWhen(
                        data: (r) => _OddsSection(result: r),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      rankAsync.when(
                        data: (ranks) => _RankListSection(ranks: ranks),
                        loading: () => preRace
                            ? const SizedBox.shrink()
                            : const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: _accent)),
                              ),
                        error: (_, __) {
                          final r = resultAsync.valueOrNull ?? fallbackResult;
                          if (r != null && r.first.isNotEmpty) {
                            return _RankListSection(ranks: [
                              {'rank': 1, 'course_no': r.firstNo, 'racer_nm': r.first},
                              if (r.second.isNotEmpty)
                                {'rank': 2, 'course_no': r.secondNo, 'racer_nm': r.second},
                              if (r.third.isNotEmpty)
                                {'rank': 3, 'course_no': r.thirdNo, 'racer_nm': r.third},
                            ]);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _DisclaimerFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(
    AsyncValue<DataWithSource<List<RaceEntry>>> entriesAsync,
    AsyncValue<RacePrediction> predAsync,
    AsyncValue<RaceResult> resultAsync,
  ) {
    return entriesAsync.when(
      data: (ew) => predAsync.when(
        data: (pred) => _ComparisonSection(
          entries: ew.data,
          prediction: pred,
          result: resultAsync.valueOrNull,
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─── Date Badge ────────────────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    required this.status,
    this.isToday = false,
  });

  final String date;
  final String status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Text('(오늘)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _statusBgColor(status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _statusFgColor(status),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBgColor(String s) {
    if (s == '확정' || s == '종료' || s == '완료') return _accent;
    if (s == '진행') return const Color(0xFF22C55E);
    return Colors.grey.shade700;
  }

  Color _statusFgColor(String s) {
    if (s == '확정' || s == '종료' || s == '완료') {
      return const Color(0xFF1A1A1A);
    }
    return Colors.white;
  }
}

// ─── Pre-Race Card ─────────────────────────────────────────────────────────────

class _PreRaceCard extends StatelessWidget {
  const _PreRaceCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.amber.shade300),
              const SizedBox(width: 10),
              const Text(
                '경기 전',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '아직 집계된 결과가 없습니다.\n경기 종료 후 다시 확인하거나 아래에서 새로고침 하세요.',
            style: TextStyle(color: Colors.grey.shade400, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('지금 다시 불러오기'),
          ),
        ],
      ),
    );
  }
}

// ─── Podium Section ────────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              '경주 결과',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _PodiumColumn(
                      courseNo: result.firstNo,
                      name: result.first,
                      circleColor: _accent,
                      circleSize: 56,
                    ),
                  ),
                  Expanded(
                    child: _PodiumColumn(
                      courseNo: result.secondNo,
                      name: result.second,
                      circleColor: const Color(0xFF9CA3AF),
                      circleSize: 56,
                    ),
                  ),
                  Expanded(
                    child: _PodiumColumn(
                      courseNo: result.thirdNo,
                      name: result.third,
                      circleColor: const Color(0xFFCD7F32),
                      circleSize: 56,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PodiumBlock(
                      label: '1st',
                      height: 60,
                      color: const Color(0xFF1B6B6B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PodiumBlock(
                      label: '2nd',
                      height: 60,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PodiumBlock(
                      label: '3rd',
                      height: 60,
                      color: const Color(0xFF92702A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.courseNo,
    required this.name,
    required this.circleColor,
    required this.circleSize,
  });

  final int courseNo;
  final String name;
  final Color circleColor;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: circleColor, width: 3),
            color: circleColor.withValues(alpha: 0.08),
          ),
          alignment: Alignment.center,
          child: Text(
            '$courseNo',
            style: TextStyle(
              color: circleColor,
              fontWeight: FontWeight.w800,
              fontSize: circleSize * 0.38,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.label,
    required this.height,
    required this.color,
  });

  final String label;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

// ─── Comparison Section ────────────────────────────────────────────────────────

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.entries,
    required this.prediction,
    required this.result,
  });

  final List<RaceEntry> entries;
  final RacePrediction prediction;
  final RaceResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();

    final compSorted = List<RaceEntry>.from(entries)
      ..sort(
          (a, b) => _comprehensiveScore(b).compareTo(_comprehensiveScore(a)));
    final compTop = compSorted.take(3).toList();
    final aiTop = prediction.rankings.take(3).toList();

    final actual = [
      (courseNo: result!.firstNo, name: result!.first),
      (courseNo: result!.secondNo, name: result!.second),
      (courseNo: result!.thirdNo, name: result!.third),
    ];

    final ai = List.generate(3, (i) {
      if (i < aiTop.length) {
        return (courseNo: aiTop[i].courseNo, name: aiTop[i].racerName);
      }
      return (courseNo: 0, name: '-');
    });

    final comp = List.generate(3, (i) {
      if (i < compTop.length) {
        return (courseNo: compTop[i].courseNo, name: compTop[i].racerName);
      }
      return (courseNo: 0, name: '-');
    });

    int aiMatches = 0;
    int compMatches = 0;
    for (int i = 0; i < 3; i++) {
      if (ai[i].courseNo == actual[i].courseNo) aiMatches++;
      if (comp[i].courseNo == actual[i].courseNo) compMatches++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              '추천 vs 실제 비교',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabChip(
                        label: '실제 결과',
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _TabChip(
                        label: 'AI 추천',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _TabChip(
                        label: '종합추천',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: _border, height: 1),
              for (int i = 0; i < 3; i++) ...[
                _ComparisonRow(
                  rank: i + 1,
                  actual: actual[i],
                  aiPred: ai[i],
                  compPred: comp[i],
                  aiMatch: ai[i].courseNo == actual[i].courseNo,
                  compMatch: comp[i].courseNo == actual[i].courseNo,
                ),
                if (i < 2)
                  const Divider(
                    color: _border,
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                  ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MatchBadge(
              label: 'AI',
              matches: aiMatches,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _MatchBadge(
              label: '종합',
              matches: compMatches,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.rank,
    required this.actual,
    required this.aiPred,
    required this.compPred,
    required this.aiMatch,
    required this.compMatch,
  });

  final int rank;
  final ({int courseNo, String name}) actual;
  final ({int courseNo, String name}) aiPred;
  final ({int courseNo, String name}) compPred;
  final bool aiMatch;
  final bool compMatch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 26,
            decoration: BoxDecoration(
              color: _rankColor(rank).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank착',
              style: TextStyle(
                color: _rankColor(rank),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _RacerCell(
              courseNo: actual.courseNo,
              name: actual.name,
              matched: true,
            ),
          ),
          Expanded(
            child: _RacerCell(
              courseNo: aiPred.courseNo,
              name: aiPred.name,
              matched: aiMatch,
            ),
          ),
          Expanded(
            child: _RacerCell(
              courseNo: compPred.courseNo,
              name: compPred.name,
              matched: compMatch,
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int r) {
    switch (r) {
      case 1:
        return _accent;
      case 2:
        return const Color(0xFF9CA3AF);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}

class _RacerCell extends StatelessWidget {
  const _RacerCell({
    required this.courseNo,
    required this.name,
    required this.matched,
  });

  final int courseNo;
  final String name;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CourseCircle(courseNo: courseNo, size: 22),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (matched) ...[
          const SizedBox(width: 2),
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
        ],
      ],
    );
  }
}

class _CourseCircle extends StatelessWidget {
  const _CourseCircle({required this.courseNo, this.size = 22});

  final int courseNo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _courseColor(courseNo),
      ),
      alignment: Alignment.center,
      child: Text(
        '$courseNo',
        style: TextStyle(
          color: _courseTextColor(courseNo),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({
    required this.label,
    required this.matches,
    required this.color,
  });

  final String label;
  final int matches;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $matches/3 적중',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Odds Section ──────────────────────────────────────────────────────────────

class _OddsSection extends StatelessWidget {
  const _OddsSection({required this.result});

  final RaceResult result;

  Widget _courseChip(int no) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _courseColor(no),
      ),
      alignment: Alignment.center,
      child: Text(
        '$no',
        style: TextStyle(
          color: _courseTextColor(no),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _arrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade500),
    );
  }

  Widget _dash() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text('–', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
    );
  }

  Widget _comboOrdered(List<int> courses) {
    final children = <Widget>[];
    for (int i = 0; i < courses.length; i++) {
      if (courses[i] <= 0) continue;
      if (children.isNotEmpty) children.add(_arrow());
      children.add(_courseChip(courses[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _comboUnordered(List<int> courses) {
    final children = <Widget>[];
    for (int i = 0; i < courses.length; i++) {
      if (courses[i] <= 0) continue;
      if (children.isNotEmpty) children.add(_dash());
      children.add(_courseChip(courses[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _comboSemiOrdered(int first, List<int> rest) {
    final children = <Widget>[_courseChip(first)];
    children.add(_arrow());
    for (int i = 0; i < rest.length; i++) {
      if (rest[i] <= 0) continue;
      if (i > 0) children.add(_dash());
      children.add(_courseChip(rest[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final f = result.firstNo;
    final s = result.secondNo;
    final t = result.thirdNo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('💰', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              '적중 배당',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _OddRow(
                label: '단승',
                value: result.winOdds,
                combination: f > 0 ? _comboOrdered([f]) : null,
              ),
              _OddRow(
                label: '연승',
                value: result.placeOdds,
                combination: f > 0 ? _comboUnordered([f, s]) : null,
              ),
              _OddRow(
                label: '쌍승',
                value: result.exactaOdds,
                combination: f > 0 ? _comboOrdered([f, s]) : null,
              ),
              _OddRow(
                label: '복승',
                value: result.quinellaOdds,
                combination: f > 0 ? _comboUnordered([f, s]) : null,
              ),
              _OddRow(
                label: '삼복승',
                value: result.triellaOdds,
                combination: f > 0 ? _comboUnordered([f, s, t]) : null,
              ),
              _OddRow(
                label: '쌍복승',
                value: result.xlaOdds,
                combination: f > 0 ? _comboSemiOrdered(f, [s, t]) : null,
              ),
              _OddRow(
                label: '삼쌍승',
                value: result.trxOdds,
                combination: f > 0 ? _comboOrdered([f, s, t]) : null,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OddRow extends StatelessWidget {
  const _OddRow({
    required this.label,
    required this.value,
    this.combination,
    this.isLast = false,
  });

  final String label;
  final double value;
  final Widget? combination;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ),
          if (combination != null) ...[
            const SizedBox(width: 4),
            Expanded(child: combination!),
          ] else
            const Spacer(),
          const SizedBox(width: 8),
          Text(
            value > 0 ? value.toStringAsFixed(1) : '-',
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rank List Section ─────────────────────────────────────────────────────────

class _RankListSection extends StatelessWidget {
  const _RankListSection({required this.ranks});

  final List<Map<String, dynamic>> ranks;

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(ranks);
    sorted.sort((a, b) {
      final ra = a['rank'];
      final rb = b['rank'];
      final ia = ra is int ? ra : int.tryParse('$ra') ?? 99;
      final ib = rb is int ? rb : int.tryParse('$rb') ?? 99;
      return ia.compareTo(ib);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              '착순',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sorted.map((row) {
          final rank = row['rank'] ?? '-';
          final cn = _courseNo(row);
          final nm = _racerNm(row);
          final rankInt = rank is int ? rank : int.tryParse('$rank') ?? 99;
          final raceTime = row['race_time']?.toString() ?? '';
          final backNo = row['back_no']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _rankBgColor(rankInt),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: _rankFgColor(rankInt),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (cn != null) ...[
                  _CourseCircle(courseNo: cn, size: 26),
                  const SizedBox(width: 10),
                ],
                if (backNo.isNotEmpty && cn == null) ...[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      backNo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    nm,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (raceTime.isNotEmpty)
                  Text(
                    raceTime,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _rankBgColor(int rank) {
    if (rank == 1) return _accent.withValues(alpha: 0.2);
    if (rank == 2) return const Color(0xFF9CA3AF).withValues(alpha: 0.2);
    if (rank == 3) return const Color(0xFFCD7F32).withValues(alpha: 0.2);
    return Colors.grey.withValues(alpha: 0.1);
  }

  Color _rankFgColor(int rank) {
    if (rank == 1) return _accent;
    if (rank == 2) return const Color(0xFF9CA3AF);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade500;
  }
}

// ─── Disclaimer Footer ────────────────────────────────────────────────────────

class _DisclaimerFooter extends StatelessWidget {
  const _DisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(
        '본 화면의 경주 결과·순위·배당·AI·종합추천 정보는 참고용이며, '
        '공식 기록과 다를 수 있습니다. 베팅 판정은 주최 기관 기준입니다.',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 11,
          height: 1.45,
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.date, required this.raceNo});

  final String date;
  final int raceNo;

  Future<void> _launch(BuildContext context, String url, String label) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label 영상을 열 수 없습니다.'),
            backgroundColor: const Color(0xFF30363D),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _VideoChip(
      icon: Icons.play_circle_outline,
      label: '경주영상',
      color: const Color(0xFFEF5350),
      onTap: () => _launch(
        context,
        ApiConstants.raceVideoUrl(date, raceNo),
        '경주',
      ),
    );
  }
}

class _VideoChip extends StatelessWidget {
  const _VideoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
