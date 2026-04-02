import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/racer_detail.dart';
import '../../race/providers/race_providers.dart';

const Color _kPrimary = Color(0xFF1565C0);
const Color _kAccent = Color(0xFFFBBF24);
const Color _kBg = Color(0xFF0D1117);
const Color _kCard = Color(0xFF161B22);
const Color _kBorder = Color(0xFF30363D);

Color _gradeColor(String grade) {
  return switch (grade) {
    'A1' => Colors.red.shade400,
    'A2' => Colors.orange.shade400,
    'B1' => Colors.green.shade400,
    'B2' => Colors.blue.shade400,
    _ => Colors.grey.shade500,
  };
}

class RacerDetailScreen extends ConsumerWidget {
  final String racerId;

  const RacerDetailScreen({super.key, required this.racerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRacerEntryProvider);
    if (selected != null && selected.racerId == racerId) {
      final asyncDetail = ref.watch(racerDetailProvider((entry: selected)));
      return asyncDetail.when(
        data: (d) => _RacerDetailBody(detail: d),
        loading: () => const _LoadingScaffold(),
        error: (e, st) => _ErrorScaffold(message: '$e'),
      );
    }

    final asyncById = ref.watch(racerDetailByIdProvider((racerId: racerId)));
    return asyncById.when(
      data: (d) => _RacerDetailBody(detail: d),
      loading: () => const _LoadingScaffold(),
      error: (e, st) => _ErrorScaffold(message: '$e'),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _kBg,
      body: Center(child: CircularProgressIndicator(color: _kAccent)),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;

  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('오류'),
        backgroundColor: _kBg,
      ),
      body: Center(
        child: Text(message, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class _RacerDetailBody extends StatelessWidget {
  final RacerDetail detail;

  const _RacerDetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _kBg,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kPrimary, Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  detail.racerName,
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      const Shadow(blurRadius: 4, color: Colors.black45),
                    ],
                  ),
                ),
                background: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.person,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (detail.fromApi)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_done,
                          size: 14, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text(
                        'API 실시간 데이터${detail.stndYear != null ? ' (${detail.stndYear}년)' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ProfileCard(detail: detail),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _StatRow(detail: detail),
            ),
          ),
          if (detail.fromApi) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _ExtraStatRow(detail: detail),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(child: _SectionTitle('기본정보')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _BasicInfoCard(detail: detail),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                detail.fromApi && detail.stndYear != null
                    ? '${detail.stndYear}년 성적'
                    : '올해성적',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _YearStatsCard(detail: detail),
            ),
          ),
          if (detail.fromApi) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(child: _SectionTitle('착순 분포')),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _RankDistributionChart(detail: detail),
              ),
            ),
          ],
          if (detail.courseWins.values.any((v) => v > 0)) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(child: _SectionTitle('코스별 우승')),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _CourseWinChart(detail: detail),
              ),
            ),
          ],
          if (detail.recentScores.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(child: _SectionTitle('최근컨디션')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: _RecentConditionCard(detail: detail),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}

// ─── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final RacerDetail detail;

  const _ProfileCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final g = _gradeColor(detail.grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: g.withValues(alpha: 0.25),
            child: Text(
              detail.grade.isEmpty || detail.grade == '-'
                  ? '?'
                  : detail.grade,
              style: GoogleFonts.notoSansKr(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: g,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.racerName,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '선수번호 ${detail.racerId}',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Rows ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final RacerDetail detail;

  const _StatRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: '평균득점',
            value: detail.avgScore.toStringAsFixed(2),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: '승률',
            value: '${detail.winRate.toStringAsFixed(1)}%',
            icon: Icons.emoji_events_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: '입상률',
            value: '${detail.podiumRate.toStringAsFixed(1)}%',
            icon: Icons.leaderboard_outlined,
          ),
        ),
      ],
    );
  }
}

class _ExtraStatRow extends StatelessWidget {
  final RacerDetail detail;

  const _ExtraStatRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (detail.consecutiveWinRate != null)
          Expanded(
            child: _StatTile(
              label: '연승률',
              value: '${detail.consecutiveWinRate!.toStringAsFixed(1)}%',
              icon: Icons.repeat,
              accentColor: const Color(0xFF10B981),
            ),
          ),
        if (detail.consecutiveWinRate != null) const SizedBox(width: 8),
        if (detail.avgStartTime != null)
          Expanded(
            child: _StatTile(
              label: '평균출발',
              value: '${detail.avgStartTime!.toStringAsFixed(2)}초',
              icon: Icons.timer_outlined,
              accentColor: const Color(0xFF3B82F6),
            ),
          ),
        if (detail.avgStartTime != null) const SizedBox(width: 8),
        if (detail.avgAccidentScore != null)
          Expanded(
            child: _StatTile(
              label: '사고점수',
              value: detail.avgAccidentScore!.toStringAsFixed(2),
              icon: Icons.warning_amber_rounded,
              accentColor: detail.avgAccidentScore! > 0.5
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF22C55E),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _kAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Basic Info Card ───────────────────────────────────────────────────────────

class _BasicInfoCard extends StatelessWidget {
  final RacerDetail detail;

  const _BasicInfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: '등급',
            value: detail.grade.isEmpty || detail.grade == '-'
                ? '-'
                : detail.grade,
          ),
          if (detail.age != null) _InfoRow(label: '나이', value: '${detail.age}세'),
          if (detail.weight != null)
            _InfoRow(
              label: '체중',
              value: '${detail.weight!.toStringAsFixed(1)}kg',
            ),
          if (detail.yearAvgRank != null)
            _InfoRow(
              label: '평균순위',
              value: detail.yearAvgRank!.toStringAsFixed(1),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Year Stats Card ───────────────────────────────────────────────────────────

class _YearStatsCard extends StatelessWidget {
  final RacerDetail detail;

  const _YearStatsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _InfoRow(label: '출주', value: '${detail.yearRaceCount}회'),
          _InfoRow(label: '1착', value: '${detail.year1stCount}회'),
          _InfoRow(label: '2착', value: '${detail.year2ndCount}회'),
          _InfoRow(label: '3착', value: '${detail.year3rdCount}회'),
          if (detail.fromApi) ...[
            _InfoRow(label: '4착', value: '${detail.rank4Count}회'),
            _InfoRow(label: '5착', value: '${detail.rank5Count}회'),
            _InfoRow(label: '6착', value: '${detail.rank6Count}회'),
          ],
        ],
      ),
    );
  }
}

// ─── Rank Distribution Chart ───────────────────────────────────────────────────

class _RankDistributionChart extends StatelessWidget {
  final RacerDetail detail;

  const _RankDistributionChart({required this.detail});

  @override
  Widget build(BuildContext context) {
    final counts = [
      detail.year1stCount,
      detail.year2ndCount,
      detail.year3rdCount,
      detail.rank4Count,
      detail.rank5Count,
      detail.rank6Count,
    ];
    final total = counts.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final colors = [
      _kAccent,
      const Color(0xFF9CA3AF),
      const Color(0xFFCD7F32),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
    ];

    final labels = ['1착', '2착', '3착', '4착', '5착', '6착'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: counts.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      return BarTooltipItem(
                        '${labels[group.x]}  ${counts[group.x]}회',
                        GoogleFonts.notoSansKr(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i > 5) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(6, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: colors[i],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(6, (i) {
              final pct =
                  total > 0 ? (counts[i] / total * 100).toStringAsFixed(1) : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${labels[i]} $pct%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Course Win Chart ──────────────────────────────────────────────────────────

class _CourseWinChart extends StatelessWidget {
  final RacerDetail detail;

  const _CourseWinChart({required this.detail});

  @override
  Widget build(BuildContext context) {
    final wins = <int, int>{};
    for (int c = 1; c <= 6; c++) {
      wins[c] = detail.courseWins[c] ?? 0;
    }
    final maxY = wins.values.isEmpty
        ? 1.0
        : wins.values.reduce((a, b) => a > b ? a : b).toDouble();
    final cap = maxY < 1 ? 1.0 : maxY * 1.2;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: cap,
            barTouchData: BarTouchData(enabled: true),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 1 || i > 6) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$i',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.notoSansKr(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: cap > 5 ? cap / 5 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(6, (index) {
              final course = index + 1;
              final w = wins[course]!.toDouble();
              return BarChartGroupData(
                x: course,
                barRods: [
                  BarChartRodData(
                    toY: w,
                    width: 14,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                    gradient: const LinearGradient(
                      colors: [_kPrimary, Color(0xFF42A5F5)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Recent Condition Card ─────────────────────────────────────────────────────

class _RecentConditionCard extends StatelessWidget {
  final RacerDetail detail;

  const _RecentConditionCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final scores = detail.recentScores;
    final avg = detail.recentAvgScore;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avg != null)
            Text(
              '최근 평균득점 ${avg.toStringAsFixed(2)}',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: scores.asMap().entries.map((e) {
              return Chip(
                label: Text(
                  e.value.toStringAsFixed(1),
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w600,
                    color: _kPrimary,
                  ),
                ),
                backgroundColor: _kPrimary.withValues(alpha: 0.12),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
