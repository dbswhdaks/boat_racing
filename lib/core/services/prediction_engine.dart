import 'dart:math' as math;

import '../../models/race_entry.dart';
import '../../models/odds.dart';
import '../../models/prediction.dart';

class PredictionEngine {
  static const _gradeScores = {'A1': 10.0, 'A2': 7.5, 'B1': 5.0, 'B2': 3.0};
  static const _courseScores = {1: 9.0, 2: 7.6, 3: 6.5, 4: 5.4, 5: 4.4, 6: 3.6};
  static const _softmaxTemperature = 9.0;

  static RacePrediction predict(List<RaceEntry> entries, {Odds? odds}) {
    if (entries.isEmpty) {
      return const RacePrediction(
        rankings: [],
        confidence: 0,
        winPicks: [],
        placePicks: [],
        quinellaPicks: [],
        analysis: '출주표 데이터가 없습니다.',
      );
    }

    final marketProbabilities = _marketProbabilities(odds);
    final scored = entries
        .map((e) => _scoreRacer(e, entries, marketProbabilities[e.courseNo]))
        .toList();
    final probabilities = _softmaxProbabilities(scored);

    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final rankings = <RacerPrediction>[];
    for (int i = 0; i < scored.length; i++) {
      final s = scored[i];
      rankings.add(
        RacerPrediction(
          courseNo: s.courseNo,
          racerName: s.racerName,
          racerId: s.racerId,
          grade: s.grade,
          winProb: probabilities[s.courseNo] ?? 0,
          rank: i + 1,
          totalScore: s.totalScore,
          factors: s.factors,
        ),
      );
    }

    return RacePrediction(
      rankings: rankings,
      confidence: _calcConfidence(rankings),
      winPicks: _generateWinPicks(rankings),
      placePicks: _generatePlacePicks(rankings),
      quinellaPicks: _generateQuinellaPicks(rankings),
      analysis: _generateAnalysis(rankings),
    );
  }

  static RacerPrediction _scoreRacer(
    RaceEntry e,
    List<RaceEntry> all,
    double? marketProbability,
  ) {
    final gradeScore = _gradeScores[e.grade] ?? 4.0;
    final avgScore = e.avgScore > 0
        ? e.avgScore.clamp(0, 10).toDouble()
        : gradeScore * 0.75;
    final recentScore = _recentScore(e.recent3Wins);
    final courseScore = _courseScores[e.courseNo] ?? 4.0;
    final weightScore = _weightScore(e, all);
    final marketScore = marketProbability == null
        ? null
        : (marketProbability * 10).clamp(0.0, 10.0);

    var total =
        gradeScore * 3.0 +
        avgScore * 2.6 +
        recentScore * 1.8 +
        courseScore * 1.7 +
        weightScore * 0.7;
    if (marketScore != null) {
      total = total * 0.82 + marketScore * 6.0;
    }

    return RacerPrediction(
      courseNo: e.courseNo,
      racerName: e.racerName,
      racerId: e.racerId,
      grade: e.grade,
      winProb: 0,
      rank: 0,
      totalScore: total,
      factors: {
        '등급': gradeScore,
        '평균득점': avgScore,
        '최근 전적': recentScore,
        '코스': courseScore,
        if (e.weight != null) '체중': weightScore,
        if (marketScore != null) '배당': marketScore,
      },
    );
  }

  static double _recentScore(int recent3Wins) {
    if (recent3Wins <= 0) return 0;
    if (recent3Wins <= 3) return (recent3Wins / 3 * 10).clamp(0.0, 10.0);
    return (recent3Wins / 100 * 10).clamp(0.0, 10.0);
  }

  static double _weightScore(RaceEntry entry, List<RaceEntry> all) {
    final weights = all
        .where((e) => e.weight != null && e.weight! > 0)
        .map((e) => e.weight!)
        .toList();
    if (entry.weight == null || entry.weight! <= 0 || weights.isEmpty) return 5;

    final avgWeight =
        weights.fold<double>(0, (sum, weight) => sum + weight) / weights.length;
    final delta = avgWeight - entry.weight!;
    return (5 + delta * 0.7).clamp(0.0, 10.0);
  }

  static Map<int, double> _marketProbabilities(Odds? odds) {
    final winOdds = odds?.win ?? const <int, double>{};
    final implied = <int, double>{};

    for (final entry in winOdds.entries) {
      if (entry.value > 1.0) {
        implied[entry.key] = 1 / entry.value;
      }
    }

    final total = implied.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return const {};

    return implied.map(
      (courseNo, probability) => MapEntry(courseNo, probability / total),
    );
  }

  static Map<int, double> _softmaxProbabilities(List<RacerPrediction> scored) {
    if (scored.isEmpty) return const {};

    final maxScore = scored
        .map((r) => r.totalScore)
        .reduce((a, b) => a > b ? a : b);
    final weights = <int, double>{};
    var totalWeight = 0.0;

    for (final racer in scored) {
      final weight = math.exp(
        (racer.totalScore - maxScore) / _softmaxTemperature,
      );
      weights[racer.courseNo] = weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0) return const {};
    return weights.map(
      (courseNo, weight) => MapEntry(courseNo, weight / totalWeight * 100),
    );
  }

  static double _calcConfidence(List<RacerPrediction> rankings) {
    if (rankings.length < 2) return 50;
    final gap = rankings[0].totalScore - rankings[1].totalScore;
    final avg =
        rankings.fold<double>(0, (s, r) => s + r.totalScore) / rankings.length;
    return (50 + (gap / avg) * 80).clamp(30, 85);
  }

  static List<BettingPick> _generateWinPicks(List<RacerPrediction> rankings) {
    if (rankings.isEmpty) return [];
    final top = rankings.first;
    return [
      BettingPick(
        label: '${top.courseNo}코스 ${top.racerName}',
        description: '${top.grade}등급 · 승률 ${top.winProb.toStringAsFixed(1)}%',
        confidence: top.winProb,
      ),
      if (rankings.length > 1)
        BettingPick(
          label: '${rankings[1].courseNo}코스 ${rankings[1].racerName}',
          description:
              '대항마 · ${rankings[1].grade}등급 · 승률 ${rankings[1].winProb.toStringAsFixed(1)}%',
          confidence: rankings[1].winProb,
        ),
    ];
  }

  static List<BettingPick> _generatePlacePicks(List<RacerPrediction> rankings) {
    if (rankings.length < 2) return [];
    final top2 = rankings.take(3).toList();
    return [
      BettingPick(
        label: '${top2[0].courseNo}-${top2[1].courseNo}',
        description: '${top2[0].racerName} · ${top2[1].racerName}',
        confidence: (top2[0].winProb + top2[1].winProb) / 2,
      ),
      if (top2.length > 2)
        BettingPick(
          label: '${top2[0].courseNo}-${top2[2].courseNo}',
          description: '${top2[0].racerName} · ${top2[2].racerName}',
          confidence: (top2[0].winProb + top2[2].winProb) / 2,
        ),
    ];
  }

  static List<BettingPick> _generateQuinellaPicks(
    List<RacerPrediction> rankings,
  ) {
    if (rankings.length < 2) return [];
    return [
      BettingPick(
        label: '${rankings[0].courseNo}→${rankings[1].courseNo}',
        description:
            '${rankings[0].racerName}(1착) → ${rankings[1].racerName}(2착)',
        confidence: (rankings[0].winProb * 0.6 + rankings[1].winProb * 0.4),
      ),
      if (rankings.length > 2)
        BettingPick(
          label: '${rankings[0].courseNo}→${rankings[2].courseNo}',
          description:
              '${rankings[0].racerName}(1착) → ${rankings[2].racerName}(2착)',
          confidence: (rankings[0].winProb * 0.5 + rankings[2].winProb * 0.3),
        ),
    ];
  }

  static String _generateAnalysis(List<RacerPrediction> rankings) {
    if (rankings.isEmpty) return '';
    final top = rankings.first;
    final buf = StringBuffer();

    buf.writeln(
      '${top.courseNo}코스 ${top.racerName} 선수가 ${top.grade}등급의 높은 기량으로 가장 유리합니다.',
    );

    if (rankings.length >= 3) {
      buf.writeln();
      buf.write(
        '대항마로 ${rankings[1].courseNo}코스 ${rankings[1].racerName}(${rankings[1].grade}), ',
      );
      buf.write(
        '${rankings[2].courseNo}코스 ${rankings[2].racerName}(${rankings[2].grade}) 선수를 주시하세요.',
      );
    }

    final innerCourse = rankings.where((r) => r.courseNo <= 2).toList();
    if (innerCourse.isNotEmpty && innerCourse.first.rank <= 2) {
      buf.writeln();
      buf.writeln();
      buf.write(
        '인코스(${innerCourse.first.courseNo}코스) 선수가 유리한 위치에 있어 선행 유리 전개가 예상됩니다.',
      );
    }

    return buf.toString();
  }
}
