import 'dart:math';
import '../../models/race_entry.dart';
import '../../models/prediction.dart';

class PredictionEngine {
  static const _gradeScores = {'A1': 10.0, 'A2': 7.5, 'B1': 5.0, 'B2': 3.0};

  static RacePrediction predict(List<RaceEntry> entries) {
    if (entries.isEmpty) {
      return const RacePrediction(
        rankings: [], confidence: 0, winPicks: [], placePicks: [], quinellaPicks: [],
        analysis: '출주표 데이터가 없습니다.',
      );
    }

    final scored = entries.map((e) => _scoreRacer(e, entries)).toList();
    final totalRaw = scored.fold<double>(0, (s, r) => s + r.totalScore);

    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final rankings = <RacerPrediction>[];
    for (int i = 0; i < scored.length; i++) {
      final s = scored[i];
      rankings.add(RacerPrediction(
        courseNo: s.courseNo,
        racerName: s.racerName,
        racerId: s.racerId,
        grade: s.grade,
        winProb: (s.totalScore / totalRaw * 100).clamp(2, 60),
        rank: i + 1,
        totalScore: s.totalScore,
        factors: s.factors,
      ));
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

  static RacerPrediction _scoreRacer(RaceEntry e, List<RaceEntry> all) {
    final gradeScore = _gradeScores[e.grade] ?? 4.0;
    final avgNorm = e.avgScore.clamp(0, 10).toDouble();
    final recentBonus = e.recent3Wins * 1.5;

    // 인코스(1번) 유리, 아웃코스(6번) 불리
    final courseScore = (7 - e.courseNo) * 0.6;

    final rng = Random(e.courseNo * 31 + e.racerName.hashCode);
    final randomFactor = 0.8 + rng.nextDouble() * 0.4;

    final total = (gradeScore * 3.0 + avgNorm * 2.5 + recentBonus * 2.0 + courseScore * 1.5) * randomFactor;

    return RacerPrediction(
      courseNo: e.courseNo,
      racerName: e.racerName,
      racerId: e.racerId,
      grade: e.grade,
      winProb: 0, rank: 0, totalScore: total,
      factors: {'등급': gradeScore, '평균득점': avgNorm, '최근 전적': recentBonus, '코스': courseScore},
    );
  }

  static double _calcConfidence(List<RacerPrediction> rankings) {
    if (rankings.length < 2) return 50;
    final gap = rankings[0].totalScore - rankings[1].totalScore;
    final avg = rankings.fold<double>(0, (s, r) => s + r.totalScore) / rankings.length;
    return (50 + (gap / avg) * 80).clamp(30, 85);
  }

  static List<BettingPick> _generateWinPicks(List<RacerPrediction> rankings) {
    if (rankings.isEmpty) return [];
    final top = rankings.first;
    return [
      BettingPick(label: '${top.courseNo}코스 ${top.racerName}', description: '${top.grade}등급 · 승률 ${top.winProb.toStringAsFixed(1)}%', confidence: top.winProb),
      if (rankings.length > 1)
        BettingPick(label: '${rankings[1].courseNo}코스 ${rankings[1].racerName}', description: '대항마 · ${rankings[1].grade}등급 · 승률 ${rankings[1].winProb.toStringAsFixed(1)}%', confidence: rankings[1].winProb),
    ];
  }

  static List<BettingPick> _generatePlacePicks(List<RacerPrediction> rankings) {
    if (rankings.length < 2) return [];
    final top2 = rankings.take(3).toList();
    return [
      BettingPick(label: '${top2[0].courseNo}-${top2[1].courseNo}', description: '${top2[0].racerName} · ${top2[1].racerName}', confidence: (top2[0].winProb + top2[1].winProb) / 2),
      if (top2.length > 2)
        BettingPick(label: '${top2[0].courseNo}-${top2[2].courseNo}', description: '${top2[0].racerName} · ${top2[2].racerName}', confidence: (top2[0].winProb + top2[2].winProb) / 2),
    ];
  }

  static List<BettingPick> _generateQuinellaPicks(List<RacerPrediction> rankings) {
    if (rankings.length < 2) return [];
    return [
      BettingPick(label: '${rankings[0].courseNo}→${rankings[1].courseNo}', description: '${rankings[0].racerName}(1착) → ${rankings[1].racerName}(2착)', confidence: (rankings[0].winProb * 0.6 + rankings[1].winProb * 0.4)),
      if (rankings.length > 2)
        BettingPick(label: '${rankings[0].courseNo}→${rankings[2].courseNo}', description: '${rankings[0].racerName}(1착) → ${rankings[2].racerName}(2착)', confidence: (rankings[0].winProb * 0.5 + rankings[2].winProb * 0.3)),
    ];
  }

  static String _generateAnalysis(List<RacerPrediction> rankings) {
    if (rankings.isEmpty) return '';
    final top = rankings.first;
    final buf = StringBuffer();

    buf.writeln('${top.courseNo}코스 ${top.racerName} 선수가 ${top.grade}등급의 높은 기량으로 가장 유리합니다.');

    if (rankings.length >= 3) {
      buf.writeln();
      buf.write('대항마로 ${rankings[1].courseNo}코스 ${rankings[1].racerName}(${rankings[1].grade}), ');
      buf.write('${rankings[2].courseNo}코스 ${rankings[2].racerName}(${rankings[2].grade}) 선수를 주시하세요.');
    }

    final innerCourse = rankings.where((r) => r.courseNo <= 2).toList();
    if (innerCourse.isNotEmpty && innerCourse.first.rank <= 2) {
      buf.writeln();
      buf.writeln();
      buf.write('인코스(${innerCourse.first.courseNo}코스) 선수가 유리한 위치에 있어 선행 유리 전개가 예상됩니다.');
    }

    return buf.toString();
  }
}
