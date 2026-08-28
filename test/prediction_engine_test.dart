import 'package:boat_racing/core/services/prediction_engine.dart';
import 'package:boat_racing/models/odds.dart';
import 'package:boat_racing/models/prediction.dart';
import 'package:boat_racing/models/race_entry.dart';
import 'package:boat_racing/models/race_result.dart';
import 'package:flutter_test/flutter_test.dart';

RaceEntry _entry(
  int course, {
  String grade = 'B1',
  double score = 5,
  double winRate = 10,
  int recentWins = 0,
  double? startTime,
  double? boatWinRate,
  double? motorWinRate,
}) {
  return RaceEntry(
    courseNo: course,
    racerName: '선수$course',
    racerId: 'R$course',
    grade: grade,
    avgScore: score,
    recentWinCount: recentWins,
    winRate: winRate,
    avgStartTime: startTime,
    boatWinRate: boatWinRate,
    motorWinRate: motorWinRate,
  );
}

void main() {
  group('PredictionEngine', () {
    test('승률과 최근 우승 수를 서로 다른 피처로 계산한다', () {
      final entries = [
        _entry(1, winRate: 30, recentWins: 0),
        _entry(2, winRate: 0, recentWins: 3),
      ];

      final prediction = PredictionEngine.predict(entries);

      expect(prediction.rankings.first.factors, contains('승률'));
      expect(
        prediction.rankings.firstWhere((racer) => racer.courseNo == 2).factors,
        contains('최근 우승'),
      );
    });

    test('선수, ST, 장비 성적이 좋은 선수를 높게 평가한다', () {
      final entries = List.generate(6, (index) => _entry(index + 1));
      entries[3] = _entry(
        4,
        grade: 'A1',
        score: 9,
        winRate: 35,
        recentWins: 3,
        startTime: 0.12,
        boatWinRate: 30,
        motorWinRate: 35,
      );

      final prediction = PredictionEngine.predict(entries);

      expect(prediction.rankings.first.courseNo, 4);
      expect(prediction.rankings.first.factors, contains('평균 ST'));
      expect(prediction.rankings.first.factors, contains('모터'));
      expect(prediction.rankings.first.factors, contains('보트'));
    });

    test('일부 코스만 있는 사후 배당은 예측에 사용하지 않는다', () {
      final entries = List.generate(6, (index) => _entry(index + 1));

      final withoutOdds = PredictionEngine.predict(entries);
      final incompleteOdds = PredictionEngine.predict(
        entries,
        odds: const Odds(win: {1: 1.1}),
      );

      expect(
        incompleteOdds.rankings.map((racer) => racer.courseNo),
        withoutOdds.rankings.map((racer) => racer.courseNo),
      );
      expect(
        incompleteOdds.rankings.every(
          (racer) => !racer.factors.containsKey('배당'),
        ),
        isTrue,
      );
    });

    test('악천후에서는 순위를 바꾸지 않고 신뢰도만 낮춘다', () {
      final entries = List.generate(
        6,
        (index) => _entry(
          index + 1,
          score: 8 - index * 0.5,
          winRate: 25 - index.toDouble(),
        ),
      );

      final normal = PredictionEngine.predict(entries);
      final adverse = PredictionEngine.predict(
        entries,
        conditions: const RaceConditions(windSpeed: 8, precipitation: 2),
      );

      expect(adverse.rankings.first.courseNo, normal.rankings.first.courseNo);
      expect(adverse.confidence, lessThan(normal.confidence));
      expect(adverse.analysis, contains('신뢰도를 보수적으로 조정'));
    });

    test('저장된 순위에서 베팅 추천을 동일하게 복원한다', () {
      final original = PredictionEngine.predict(
        List.generate(6, (index) => _entry(index + 1)),
      );

      final restored = PredictionEngine.restore(
        rankings: original.rankings,
        confidence: original.confidence,
        analysis: original.analysis,
        modelVersion: PredictionEngine.modelVersion,
        predictedAt: DateTime.utc(2026, 8, 13, 1),
      );

      expect(
        restored.winPicks.map((pick) => pick.label),
        original.winPicks.map((pick) => pick.label),
      );
      expect(
        restored.placePicks.map((pick) => pick.label),
        original.placePicks.map((pick) => pick.label),
      );
      expect(
        restored.quinellaPicks.map((pick) => pick.label),
        original.quinellaPicks.map((pick) => pick.label),
      );
    });

    test('단승, 복승, 쌍승과 TOP3 적중을 계산한다', () {
      final prediction = PredictionEngine.predict([
        _entry(1, grade: 'A1', score: 9, winRate: 40),
        _entry(2, grade: 'A2', score: 8, winRate: 30),
        _entry(3, grade: 'B1', score: 7, winRate: 20),
      ]);
      final ranked = prediction.rankings;
      final result = RaceResult(
        raceNo: 1,
        first: ranked[0].racerName,
        firstNo: ranked[0].courseNo,
        second: ranked[2].racerName,
        secondNo: ranked[2].courseNo,
        third: ranked[1].racerName,
        thirdNo: ranked[1].courseNo,
      );

      final evaluation = PredictionEngine.evaluate(prediction, result);

      expect(evaluation.winHit, isTrue);
      expect(evaluation.placeHit, isTrue);
      expect(evaluation.quinellaHit, isTrue);
      expect(evaluation.orderedTop3Hits, 1);
      expect(evaluation.unorderedTop3Hits, 3);
    });
  });
}
