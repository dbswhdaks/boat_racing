import 'dart:math' as math;

import '../../models/race_entry.dart';
import '../../models/prediction.dart';
import '../../models/race_result.dart';

/// 학습된 랭킹 모델이 쓰는 연속형 피처 하나.
class _Feature {
  /// 예측 근거 칩에 표시할 이름.
  final String label;

  /// 학습으로 얻은 계수.
  final double weight;

  /// 값이 없을 때 대신 쓰는 학습 데이터 평균.
  final double fallback;

  /// 근거 칩을 0~10 범위로 보여주기 위한 나눗수.
  final double displayDivisor;

  final double? Function(RaceEntry entry) read;

  const _Feature({
    required this.label,
    required this.weight,
    required this.fallback,
    required this.displayDivisor,
    required this.read,
  });
}

double? _avgRankPoint(RaceEntry e) => _positive(e.avgRankPoint);
double? _top2Rate(RaceEntry e) => _positive(e.top2Rate);
double? _motorRankPoint(RaceEntry e) => _positive(e.motorRankPoint);
double? _motorWinRate(RaceEntry e) => _positive(e.motorWinRate);
double? _motorTop3Rate(RaceEntry e) => _positive(e.motorTop3Rate);
double? _boatRankPoint(RaceEntry e) => _positive(e.boatRankPoint);
double? _boatWinRate(RaceEntry e) => _positive(e.boatWinRate);

double? _positive(double? value) =>
    (value == null || value <= 0) ? null : value;

class PredictionEngine {
  /// 조건부 랭킹 모델(Plackett-Luce). 공공데이터포털 출주표·경주결과의
  /// 2023-01 ~ 2025-12 5,301경주로 학습했고, 2026 시즌 1,130경주를 홀드아웃으로
  /// 한 번만 평가해 1착 적중 42.1% → 51.9%, 복승 35.8% → 45.6% 를 확인했다.
  static const modelVersion = 'ranking-v3';

  /// 각 선수의 효용 u = Σ(계수 × 피처) 를 구해 내림차순이 예측 순위가 되고,
  /// softmax(u / 온도) 가 예상 승률이 된다. softmax 는 평행이동에 불변이라
  /// 절편이 필요 없고, 결측 피처를 학습 평균으로 채우면 경주 안 모든 선수에게
  /// 같은 값이 더해져 순위가 흔들리지 않는다.
  ///
  /// 온도는 검증셋(2025) 로그손실이 최소가 되는 값으로 보정했다.
  static const _softmaxTemperature = 0.7;

  /// 효용을 화면용 "종합 점수"로 바꾸는 배율. 순위에는 영향이 없다.
  static const _displayScoreScale = 25.0;

  static const _courseWeights = <int, double>{
    1: 1.373642,
    2: 1.034877,
    3: 0.784351,
    4: 0.570634,
    5: 0.351113,
    6: 0,
  };

  static const _gradeWeights = <String, double>{
    'A1': 0.558552,
    'A2': 0.322477,
    'B1': 0.075595,
    'B2': 0,
  };

  /// 등급을 알 수 없을 때 쓰는 학습 데이터 평균.
  static const _unknownGradeWeight = 0.210084;

  /// 1·2코스에 A급 선수가 들어갔을 때의 추가 이점.
  static const _innerCourseTopGradeWeights = <int, double>{
    1: 0.110331,
    2: 0.126812,
  };

  static const _features = <_Feature>[
    _Feature(
      label: '평균착순점',
      weight: 0.120855,
      fallback: 4.5145,
      displayDivisor: 1,
      read: _avgRankPoint,
    ),
    _Feature(
      label: '연대율',
      weight: 0.007383,
      fallback: 31.7436,
      displayDivisor: 10,
      read: _top2Rate,
    ),
    _Feature(
      label: '모터',
      weight: 0.092611,
      fallback: 4.6636,
      displayDivisor: 1,
      read: _motorRankPoint,
    ),
    _Feature(
      label: '모터 연대율',
      weight: 0.009521,
      fallback: 33.1207,
      displayDivisor: 10,
      read: _motorWinRate,
    ),
    _Feature(
      label: '모터 삼연대율',
      weight: 0.011937,
      fallback: 49.7285,
      displayDivisor: 10,
      read: _motorTop3Rate,
    ),
    _Feature(
      label: '보트',
      weight: 0.071942,
      fallback: 4.6773,
      displayDivisor: 1,
      read: _boatRankPoint,
    ),
    _Feature(
      label: '보트 연대율',
      weight: 0.018287,
      fallback: 32.9614,
      displayDivisor: 10,
      read: _boatWinRate,
    ),
  ];

  /// 단승 배당은 경주가 끝난 뒤에야 공개돼 예측 시점에 얻을 수 없으므로
  /// 모델 입력에서 제외한다. (배당을 섞으면 홀드아웃 1착 적중이 58%까지 오르지만,
  /// 지난 경주를 다시 볼 때만 가능한 수치라 실제 예측과 어긋난다.)
  static RacePrediction predict(
    List<RaceEntry> entries, {
    RaceConditions? conditions,
  }) {
    if (entries.isEmpty) {
      return RacePrediction(
        rankings: [],
        confidence: 0,
        winPicks: [],
        placePicks: [],
        quinellaPicks: [],
        analysis: '출주표 데이터가 없습니다.',
        modelVersion: modelVersion,
      );
    }

    final scored = entries.map(_scoreRacer).toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final probabilities = _softmaxProbabilities(scored);

    final rankings = <RacerPrediction>[];
    for (var index = 0; index < scored.length; index++) {
      final racer = scored[index];
      rankings.add(
        RacerPrediction(
          courseNo: racer.courseNo,
          racerName: racer.racerName,
          racerId: racer.racerId,
          grade: racer.grade,
          winProb: probabilities[racer.courseNo] ?? 0,
          rank: index + 1,
          totalScore: racer.totalScore,
          factors: racer.factors,
        ),
      );
    }

    return RacePrediction(
      rankings: rankings,
      confidence: _calcConfidence(rankings, conditions),
      winPicks: _generateWinPicks(rankings),
      placePicks: _generatePlacePicks(rankings),
      quinellaPicks: _generateQuinellaPicks(rankings),
      analysis: _generateAnalysis(rankings, conditions),
      modelVersion: modelVersion,
    );
  }

  static RacePrediction restore({
    required List<RacerPrediction> rankings,
    required double confidence,
    required String analysis,
    required String modelVersion,
    required DateTime predictedAt,
  }) {
    return RacePrediction(
      rankings: rankings,
      confidence: confidence,
      winPicks: _generateWinPicks(rankings),
      placePicks: _generatePlacePicks(rankings),
      quinellaPicks: _generateQuinellaPicks(rankings),
      analysis: analysis,
      modelVersion: modelVersion,
      predictedAt: predictedAt,
    );
  }

  static PredictionEvaluation evaluate(
    RacePrediction prediction,
    RaceResult result,
  ) {
    final ranked = List<RacerPrediction>.from(prediction.rankings)
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final predictedCourses = ranked.map((racer) => racer.courseNo).toList();
    final actualCourses = [result.firstNo, result.secondNo, result.thirdNo];

    var orderedHits = 0;
    for (
      var index = 0;
      index < 3 &&
          index < predictedCourses.length &&
          index < actualCourses.length;
      index++
    ) {
      if (predictedCourses[index] == actualCourses[index]) orderedHits++;
    }

    final actualTop3 = actualCourses.where((course) => course > 0).toSet();
    final unorderedHits = predictedCourses
        .take(3)
        .where(actualTop3.contains)
        .length;
    final actualTop2 = {result.firstNo, result.secondNo};
    final placeCombinations = <Set<int>>[
      if (predictedCourses.length >= 2)
        {predictedCourses[0], predictedCourses[1]},
      if (predictedCourses.length >= 3)
        {predictedCourses[0], predictedCourses[2]},
    ];
    final exactaCombinations = <(int, int)>[
      if (predictedCourses.length >= 2)
        (predictedCourses[0], predictedCourses[1]),
      if (predictedCourses.length >= 3)
        (predictedCourses[0], predictedCourses[2]),
    ];

    return PredictionEvaluation(
      winHit: predictedCourses.take(2).contains(result.firstNo),
      placeHit:
          actualTop2.length == 2 &&
          placeCombinations.any(
            (combination) =>
                combination.length == 2 && combination.containsAll(actualTop2),
          ),
      quinellaHit: exactaCombinations.any(
        (combination) =>
            combination.$1 == result.firstNo &&
            combination.$2 == result.secondNo,
      ),
      orderedTop3Hits: orderedHits,
      unorderedTop3Hits: unorderedHits,
    );
  }

  /// 출주표 화면에서 선수를 정렬·비교할 때 쓰는 종합 점수.
  static double comprehensiveScore(RaceEntry entry) {
    return _scoreRacer(entry).totalScore;
  }

  /// 학습된 계수로 계산한 효용. 값이 클수록 상위 착순 가능성이 높다.
  static double _utility(RaceEntry entry) {
    var utility =
        (_courseWeights[entry.courseNo] ?? 0) +
        (_gradeWeights[entry.grade] ?? _unknownGradeWeight);

    if (_isTopGrade(entry.grade)) {
      utility += _innerCourseTopGradeWeights[entry.courseNo] ?? 0;
    }
    for (final feature in _features) {
      utility += feature.weight * (feature.read(entry) ?? feature.fallback);
    }
    return utility;
  }

  static bool _isTopGrade(String grade) => grade == 'A1' || grade == 'A2';

  static RacerPrediction _scoreRacer(RaceEntry entry) {
    final maxCourseWeight = _courseWeights[1]!;
    final maxGradeWeight = _gradeWeights['A1']!;

    final factors = <String, double>{
      '코스': (_courseWeights[entry.courseNo] ?? 0) / maxCourseWeight * 10,
      if (_gradeWeights.containsKey(entry.grade))
        '등급': _gradeWeights[entry.grade]! / maxGradeWeight * 10,
    };
    for (final feature in _features) {
      final value = feature.read(entry);
      if (value != null) {
        factors[feature.label] = (value / feature.displayDivisor).clamp(
          0.0,
          10.0,
        );
      }
    }

    return RacerPrediction(
      courseNo: entry.courseNo,
      racerName: entry.racerName,
      racerId: entry.racerId,
      grade: entry.grade,
      winProb: 0,
      rank: 0,
      totalScore: _utility(entry) * _displayScoreScale,
      factors: factors,
    );
  }

  static Map<int, double> _softmaxProbabilities(List<RacerPrediction> scored) {
    if (scored.isEmpty) return const {};

    final scale = _displayScoreScale * _softmaxTemperature;
    final maxScore = scored
        .map((racer) => racer.totalScore)
        .reduce((a, b) => a > b ? a : b);

    final weights = <int, double>{};
    var totalWeight = 0.0;
    for (final racer in scored) {
      final weight = math.exp((racer.totalScore - maxScore) / scale);
      weights[racer.courseNo] = weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0) return const {};
    return weights.map(
      (courseNo, weight) => MapEntry(courseNo, weight / totalWeight * 100),
    );
  }

  /// 1위 예상 확률이 곧 신뢰도다. 홀드아웃에서 이 확률과 실제 1착 적중률이
  /// 거의 일치하도록 온도를 보정했으므로 그대로 쓰고, 기상 악화만 감점한다.
  static double _calcConfidence(
    List<RacerPrediction> rankings,
    RaceConditions? conditions,
  ) {
    if (rankings.isEmpty) return 0;

    final windPenalty = ((conditions?.windSpeed ?? 0) * 1.5).clamp(0, 12);
    final rainPenalty = (conditions?.precipitation ?? 0) > 0 ? 5 : 0;
    final confidence = rankings.first.winProb - windPenalty - rainPenalty;
    return confidence.clamp(10, 95);
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

  static String _generateAnalysis(
    List<RacerPrediction> rankings,
    RaceConditions? conditions,
  ) {
    if (rankings.isEmpty) return '';
    final top = rankings.first;
    final buf = StringBuffer();

    buf.writeln(
      '${top.courseNo}코스 ${top.racerName} 선수가 예상 승률 '
      '${top.winProb.toStringAsFixed(1)}%로 가장 유리합니다.',
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

    final motorEdge = rankings.first.factors['모터'];
    if (motorEdge != null && motorEdge >= 5.5) {
      buf.writeln();
      buf.writeln();
      buf.write('모터 성적이 상위권이라 직선 가속에서 우위가 예상됩니다.');
    }

    final innerCourse = rankings.where((r) => r.courseNo <= 2).toList();
    if (innerCourse.isNotEmpty && innerCourse.first.rank <= 2) {
      buf.writeln();
      buf.writeln();
      buf.write(
        '인코스(${innerCourse.first.courseNo}코스) 선수가 유리한 위치에 있어 선행 유리 전개가 예상됩니다.',
      );
    }
    if (conditions?.isAdverse == true) {
      buf.writeln();
      buf.writeln();
      buf.write('강풍 또는 강수로 변수가 커 신뢰도를 보수적으로 조정했습니다.');
    }

    return buf.toString();
  }
}
