import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/race_entry.dart';
import '../../../models/odds.dart';
import '../providers/race_providers.dart';
import '../widgets/entry_card.dart';
import '../widgets/odds_panel.dart';
import '../widgets/prediction_tab.dart';

const _bg = Color(0xFF0D1117);
const _card = Color(0xFF161B22);
const _primary = Color(0xFF1565C0);
const _accent = Color(0xFFFBBF24);

/// 종합 추천 점수: 등급 + 평균득점 + 최근 3착
double comprehensiveScore(RaceEntry e) {
  const gradeScores = {'A1': 10.0, 'A2': 7.5, 'B1': 5.0, 'B2': 3.0};
  final g = gradeScores[e.grade] ?? 4.0;
  return g * 2.0 + e.avgScore * 1.5 + e.recent3Wins * 2.0;
}

String formatYmdKorean(String ymd) {
  if (ymd.length != 8) return ymd;
  final y = ymd.substring(0, 4);
  final m = ymd.substring(4, 6);
  final d = ymd.substring(6, 8);
  return '$y년 $m월 $d일';
}

/// 배당 기준 인기 순 (단승 배당 낮을수록 유리)
List<RaceEntry> popularityOrder(List<RaceEntry> entries, Odds odds) {
  final copy = List<RaceEntry>.from(entries);
  copy.sort((a, b) {
    final oa = odds.win[a.courseNo] ?? 9999.0;
    final ob = odds.win[b.courseNo] ?? 9999.0;
    return oa.compareTo(ob);
  });
  return copy;
}

Map<int, int> _rankByCourse(List<RaceEntry> ordered, int Function(RaceEntry) key) {
  final map = <int, int>{};
  for (var i = 0; i < ordered.length; i++) {
    map[key(ordered[i])] = i + 1;
  }
  return map;
}

class RaceDetailScreen extends ConsumerStatefulWidget {
  const RaceDetailScreen({super.key, required this.date, required this.raceNo});

  final String date;
  final int raceNo;

  @override
  ConsumerState<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends ConsumerState<RaceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (date: widget.date, raceNo: widget.raceNo);
    final entriesAsync = ref.watch(raceEntriesProvider(params));
    final oddsAsync = ref.watch(oddsProvider(params));

    return Scaffold(
      backgroundColor: _bg,
      body: entriesAsync.when(
        data: (entriesWithSource) {
          final entries = entriesWithSource.data;
          return oddsAsync.when(
            data: (odds) => _buildBody(context, entries, odds, entriesWithSource.apiError),
            loading: () => const Center(child: CircularProgressIndicator(color: _primary)),
            error: (e, _) => Center(child: Text('배당: $e', style: const TextStyle(color: Colors.white70))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _primary)),
        error: (e, _) => Center(child: Text('출주표: $e', style: const TextStyle(color: Colors.white70))),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<RaceEntry> entries,
    Odds odds,
    String? apiError,
  ) {
    final popOrder = popularityOrder(entries, odds);
    final popRankByCourse = _rankByCourse(popOrder, (e) => e.courseNo);

    final compSorted = List<RaceEntry>.from(entries)
      ..sort((a, b) => comprehensiveScore(b).compareTo(comprehensiveScore(a)));
    final compRankByCourse = _rankByCourse(compSorted, (e) => e.courseNo);

    final topComprehensive = compSorted.take(3).toList();

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            pinned: true,
            expandedHeight: 168,
            backgroundColor: _bg,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.go('/result/${widget.date}/${widget.raceNo}'),
                icon: const Icon(Icons.emoji_events, color: _accent, size: 20),
                label: const Text('결과', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '${widget.raceNo}R · 미사리경정공원',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              background: Container(
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
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatYmdKorean(widget.date),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          apiError != null ? '※ 일부 데이터는 참고용 목업입니다.' : '실시간 데이터',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _InfoCard(raceNo: widget.raceNo),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: '종합추천'),
                  Tab(text: 'AI 추천'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComprehensiveTab(
            entries: entries,
            odds: odds,
            popRankByCourse: popRankByCourse,
            compRankByCourse: compRankByCourse,
            topComprehensive: topComprehensive,
          ),
          PredictionTab(date: widget.date, raceNo: widget.raceNo),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.raceNo});

  final int raceNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, color: Color(0xFF64B5F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                '미사리경정공원',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _InfoChip(icon: Icons.straighten, label: '거리', value: '600m'),
              _InfoChip(icon: Icons.groups, label: '출전', value: '6명'),
              _InfoChip(icon: Icons.tag, label: '경주', value: '고정'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '경주번호 $raceNo · 경정(모터보트)',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text('$label ', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ComprehensiveTab extends StatelessWidget {
  const _ComprehensiveTab({
    required this.entries,
    required this.odds,
    required this.popRankByCourse,
    required this.compRankByCourse,
    required this.topComprehensive,
  });

  final List<RaceEntry> entries;
  final Odds odds;
  final Map<int, int> popRankByCourse;
  final Map<int, int> compRankByCourse;
  final List<RaceEntry> topComprehensive;

  @override
  Widget build(BuildContext context) {
    const rankColors = [Color(0xFFFBBF24), Color(0xFF9CA3AF), Color(0xFFCD7F32)];
    const rankLabels = ['1위', '2위', '3위'];
    final top3 = topComprehensive.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (top3.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: _accent, size: 20),
              SizedBox(width: 8),
              Text(
                '종합 추천 TOP 3',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '등급·평균득점·최근 3착을 반영한 점수 상위',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...top3.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RankRow(
                rank: rankLabels[i],
                rankColor: rankColors[i],
                entry: entry,
                score: comprehensiveScore(entry),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        const Text(
          '전체 출주표',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (e) => EntryCard(
            entry: e,
            popularityRank: popRankByCourse[e.courseNo],
            comprehensiveRank: compRankByCourse[e.courseNo],
          ),
        ),
        const SizedBox(height: 16),
        OddsPanel(odds: odds),
        const SizedBox(height: 12),
        Text(
          '※ 배당·기록은 참고용이며, 실제 투표 및 결과와 다를 수 있습니다.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.rankColor,
    required this.entry,
    required this.score,
  });

  final String rank;
  final Color rankColor;
  final RaceEntry entry;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: rankColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              rank,
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _courseColor(entry.courseNo),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry.courseNo}',
              style: TextStyle(
                color: (entry.courseNo == 2 || entry.courseNo == 3 || entry.courseNo == 6)
                    ? Colors.white
                    : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.racerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.grade} · 평균 ${entry.avgScore.toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${score.toStringAsFixed(1)}점',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

Color _courseColor(int courseNo) {
  const colors = [
    Color(0xFFD4D4D4), Color(0xFF333333), Color(0xFFEF4444),
    Color(0xFF3B82F6), Color(0xFFFBBF24), Color(0xFF22C55E),
  ];
  return (courseNo >= 1 && courseNo <= 6) ? colors[courseNo - 1] : const Color(0xFF6B7280);
}


