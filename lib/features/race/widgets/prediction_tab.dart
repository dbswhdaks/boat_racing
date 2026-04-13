import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/prediction.dart';
import '../providers/race_providers.dart';

const Color _kPrimary = Color(0xFF1565C0);
const Color _kAccent = Color(0xFFFBBF24);

Color _gradeColor(String grade) {
  return switch (grade) {
    'A1' => Colors.red.shade400,
    'A2' => Colors.orange.shade400,
    'B1' => Colors.green.shade400,
    'B2' => Colors.blue.shade400,
    _ => Colors.grey.shade500,
  };
}

Color _factorColor(String key) {
  return switch (key) {
    '등급' => Colors.red.shade300,
    '평균득점' => Colors.blue.shade300,
    '최근 전적' => Colors.green.shade300,
    '코스' => Colors.purple.shade300,
    _ => Colors.grey.shade500,
  };
}

/// AI 예측 결과 탭 — [predictionProvider] 사용
class PredictionTab extends ConsumerWidget {
  final String date;
  final int raceNo;

  const PredictionTab({
    super.key,
    required this.date,
    required this.raceNo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(predictionProvider((date: date, raceNo: raceNo)));
    return async.when(
      data: (prediction) => _PredictionLoadedBody(
        prediction: prediction,
        date: date,
        raceNo: raceNo,
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _kPrimary),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'AI 예측을 불러오지 못했습니다.\n$e',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _PredictionLoadedBody extends StatelessWidget {
  const _PredictionLoadedBody({
    required this.prediction,
    required this.date,
    required this.raceNo,
  });

  final RacePrediction prediction;
  final String date;
  final int raceNo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<RacerPrediction>.from(prediction.rankings)
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final maxScore = sorted.isEmpty
        ? 1.0
        : sorted.map((e) => e.totalScore).reduce((a, b) => a > b ? a : b);

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sorted.isNotEmpty) ...[
            ...sorted.take(3).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AiTopPick(racer: r, confidence: prediction.confidence),
            )),
            const SizedBox(height: 6),
          ],
          _ConfidenceGauge(confidence: prediction.confidence),
          const SizedBox(height: 20),
          Text(
            '전체 순위',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((r) => _RankBarRow(
                racer: r,
                maxScore: maxScore,
                gradeColor: _gradeColor(r.grade),
              )),
          const SizedBox(height: 24),
          _BettingSection(
            title: '단승',
            picks: prediction.winPicks,
          ),
          const SizedBox(height: 16),
          _BettingSection(
            title: '복승',
            picks: prediction.placePicks,
          ),
          const SizedBox(height: 16),
          _BettingSection(
            title: '쌍승',
            picks: prediction.quinellaPicks,
          ),
          const SizedBox(height: 24),
          _AnalysisCard(analysis: prediction.analysis),
          const SizedBox(height: 24),
          Text(
            '상위 3위 요인 분석',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.take(3).map((r) => _FactorCard(
                racer: r,
                factorColor: _factorColor,
              )),
          const SizedBox(height: 24),
          _Disclaimer(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/result/$date/$raceNo'),
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.flag_outlined),
            label: Text(
              '경주 결과 보기',
              style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTopPick extends StatelessWidget {
  final RacerPrediction racer;
  final double confidence;

  const _AiTopPick({required this.racer, required this.confidence});

  Color get _rankAccent {
    if (racer.rank == 1) return _kAccent;
    if (racer.rank == 2) return const Color(0xFF9CA3AF);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    final gColor = _gradeColor(racer.grade);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _rankAccent.withValues(alpha: 0.1),
            const Color(0xFF161B22),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rankAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: _rankAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI 추천 ${racer.rank}위',
                style: GoogleFonts.notoSansKr(
                  color: _rankAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _rankAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '승률 ${racer.winProb.toStringAsFixed(1)}%',
                  style: GoogleFonts.notoSansKr(
                    color: _rankAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gColor, width: 2),
                ),
                child: Text(
                  '${racer.courseNo}',
                  style: GoogleFonts.notoSansKr(
                    color: gColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      racer.racerName,
                      style: GoogleFonts.notoSansKr(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: gColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            racer.grade,
                            style: GoogleFonts.notoSansKr(
                              color: gColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '종합 ${racer.totalScore.toStringAsFixed(1)}점',
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${racer.rank}',
                      style: GoogleFonts.notoSansKr(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '위',
                      style: GoogleFonts.notoSansKr(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfidenceGauge extends StatelessWidget {
  final double confidence;

  const _ConfidenceGauge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence.clamp(0, 100)) / 100.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined, color: _kAccent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 신뢰도',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${confidence.toStringAsFixed(0)}%',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: _kPrimary.withValues(alpha: 0.2),
                color: _kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankBarRow extends StatelessWidget {
  final RacerPrediction racer;
  final double maxScore;
  final Color gradeColor;

  const _RankBarRow({
    required this.racer,
    required this.maxScore,
    required this.gradeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxScore > 0 ? (racer.totalScore / maxScore).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '${racer.rank}',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: gradeColor, width: 2),
            ),
            child: Text(
              '${racer.courseNo}',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: gradeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        racer.racerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${racer.winProb.toStringAsFixed(1)}%',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: _kPrimary,
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

class _BettingSection extends StatelessWidget {
  final String title;
  final List<BettingPick> picks;

  const _BettingSection({
    required this.title,
    required this.picks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
            const SizedBox(height: 10),
            if (picks.isEmpty)
              Text(
                '추천 조합이 없습니다.',
                style: GoogleFonts.notoSansKr(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            else
              ...picks.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BettingPickTile(pick: p),
                  )),
          ],
        ),
      ),
    );
  }
}

class _BettingPickTile extends StatelessWidget {
  final BettingPick pick;

  const _BettingPickTile({required this.pick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conf = (pick.confidence.clamp(0, 100)) / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pick.label,
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              '${pick.confidence.toStringAsFixed(0)}%',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: _kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          pick.description,
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: conf,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: _kPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String analysis;

  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '종합 분석',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              analysis.isEmpty ? '분석 내용이 없습니다.' : analysis,
              style: GoogleFonts.notoSansKr(
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorCard extends StatelessWidget {
  final RacerPrediction racer;
  final Color Function(String) factorColor;

  const _FactorCard({
    required this.racer,
    required this.factorColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = racer.factors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gradeColor(racer.grade).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${racer.rank}위 · ${racer.courseNo}코스',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _gradeColor(racer.grade),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    racer.racerName,
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((e) {
                final c = factorColor(e.key);
                return Chip(
                  label: Text(
                    '${e.key} ${e.value.toStringAsFixed(1)}',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                  ),
                  backgroundColor: c.withValues(alpha: 0.15),
                  side: BorderSide(color: c.withValues(alpha: 0.4)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: _kAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI 예측은 참고용이며 경주 결과를 보장하지 않습니다. '
              '실제 베팅은 본인 판단과 책임 하에 이용해 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
