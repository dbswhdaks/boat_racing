import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/race_entry.dart';
import '../providers/race_providers.dart';

const Color _kPrimary = Color(0xFF1565C0);

Color _gradeColor(String grade) {
  return switch (grade) {
    'A1' => Colors.red.shade400,
    'A2' => Colors.orange.shade400,
    'B1' => Colors.green.shade400,
    'B2' => Colors.blue.shade400,
    _ => Colors.grey.shade500,
  };
}

/// 출주표 한 줄 카드 (경정)
class EntryCard extends ConsumerWidget {
  final RaceEntry entry;
  final int? popularityRank;
  final int? comprehensiveRank;
  final Widget? trailing;

  const EntryCard({
    super.key,
    required this.entry,
    this.popularityRank,
    this.comprehensiveRank,
    this.trailing,
  });

  void _openRacer(BuildContext context, WidgetRef ref) {
    ref.read(selectedRacerEntryProvider.notifier).state = entry;
    context.push('/racer/${entry.racerId}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gColor = _gradeColor(entry.grade);

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRacer(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: gColor, width: 2),
                ),
                child: Text(
                  '${entry.courseNo}',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: gColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _openRacer(context, ref),
                            child: Text(
                              entry.racerName,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: _kPrimary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        _GradeChip(grade: entry.grade, color: gColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '평균득점 ${entry.avgScore.toStringAsFixed(2)} · 최근 3회 ${entry.recent3Wins}승',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.directions_boat_outlined,
                          label: entry.boatNo != null ? '보트 ${entry.boatNo}' : '보트 —',
                        ),
                        _InfoChip(
                          icon: Icons.settings_outlined,
                          label: entry.motorNo != null ? '모터 ${entry.motorNo}' : '모터 —',
                        ),
                        if (entry.weight != null)
                          _InfoChip(
                            icon: Icons.monitor_weight_outlined,
                            label: '${entry.weight!.toStringAsFixed(1)}kg',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (popularityRank != null || comprehensiveRank != null || trailing != null) ...[
                const SizedBox(width: 8),
                if (popularityRank != null)
                  _RankMini(label: '인기', rank: popularityRank!, color: const Color(0xFFFBBF24)),
                if (comprehensiveRank != null) ...[
                  if (popularityRank != null) const SizedBox(width: 6),
                  _RankMini(label: '종합', rank: comprehensiveRank!, color: _kPrimary),
                ],
                if (trailing != null) trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankMini extends StatelessWidget {
  const _RankMini({required this.label, required this.rank, required this.color});

  final String label;
  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9))),
        Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _GradeChip extends StatelessWidget {
  final String grade;
  final Color color;

  const _GradeChip({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        grade.isEmpty ? '-' : grade,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
