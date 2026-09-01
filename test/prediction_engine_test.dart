import 'package:boat_racing/core/services/prediction_engine.dart';
import 'package:boat_racing/models/prediction.dart';
import 'package:boat_racing/models/race_entry.dart';
import 'package:boat_racing/models/race_result.dart';
import 'package:flutter_test/flutter_test.dart';

RaceEntry _entry(
  int course, {
  String grade = 'B1',
  double? avgRankPoint,
  double? top2Rate,
  double? motorRankPoint,
  double? motorWinRate,
  double? motorTop3Rate,
  double? boatRankPoint,
  double? boatWinRate,
}) {
  return RaceEntry(
    courseNo: course,
    racerName: '선수$course',
    racerId: 'R$course',
    grade: grade,
    avgRankPoint: avgRankPoint,
    top2Rate: top2Rate,
    motorRankPoint: motorRankPoint,
    motorWinRate: motorWinRate,
    motorTop3Rate: motorTop3Rate,
    boatRankPoint: boatRankPoint,
    boatWinRate: boatWinRate,
  );
}

List<int> _order(RacePrediction prediction) =>
    prediction.rankings.map((racer) => racer.courseNo).toList();

void main() {
  group('PredictionEngine', () {
    test('조건이 같으면 안쪽 코스를 높게 평가한다', () {
      final prediction = PredictionEngine.predict(
        List.generate(6, (index) => _entry(index + 1)),
      );

      expect(_order(prediction), [1, 2, 3, 4, 5, 6]);
    });

    test('예상 승률의 합은 100%다', () {
      final prediction = PredictionEngine.predict(
        List.generate(6, (index) => _entry(index + 1, grade: 'A2')),
      );

      final total = prediction.rankings.fold<double>(
        0,
        (sum, racer) => sum + racer.winProb,
      );
      expect(total, closeTo(100, 0.001));
    });

    test('바깥 코스라도 기록과 장비가 압도적이면 1순위가 된다', () {
      final entries = List.generate(6, (index) => _entry(index + 1));
      entries[5] = _entry(
        6,
        grade: 'A1',
        avgRankPoint: 8.5,
        top2Rate: 70,
        motorRankPoint: 7.5,
        motorWinRate: 55,
        motorTop3Rate: 72,
        boatRankPoint: 7,
        boatWinRate: 52,
      );

      expect(PredictionEngine.predict(entries).rankings.first.courseNo, 6);
    });

    test('모든 선수에게 없는 피처는 순위를 바꾸지 않는다', () {
      final withoutEquipment = List.generate(
        6,
        (index) => _entry(index + 1, grade: 'A2', avgRankPoint: 6 - index * 0.4),
      );
      // 같은 값이 모두에게 채워지면 softmax 특성상 순위에 영향이 없어야 한다.
      final withUniformEquipment = withoutEquipment
          .map((entry) => entry.copyWith(motorRankPoint: 5, boatRankPoint: 5))
          .toList();

      expect(
        _order(PredictionEngine.predict(withUniformEquipment)),
        _order(PredictionEngine.predict(withoutEquipment)),
      );
    });

    test('근거 칩에는 실제로 값이 있는 피처만 담는다', () {
      final prediction = PredictionEngine.predict([
        _entry(1, grade: 'A1', avgRankPoint: 6.5, motorRankPoint: 5.2),
        _entry(2),
      ]);

      final factors = prediction.rankings.first.factors;
      expect(factors.keys, containsAll(['코스', '등급', '평균착순점', '모터']));
      expect(factors.containsKey('보트'), isFalse);
    });

    test('악천후에서는 순위를 바꾸지 않고 신뢰도만 낮춘다', () {
      final entries = List.generate(
        6,
        (index) => _entry(index + 1, avgRankPoint: 7 - index * 0.5),
      );

      final normal = PredictionEngine.predict(entries);
      final adverse = PredictionEngine.predict(
        entries,
        conditions: const RaceConditions(windSpeed: 8, precipitation: 2),
      );

      expect(_order(adverse), _order(normal));
      expect(adverse.confidence, lessThan(normal.confidence));
      expect(adverse.analysis, contains('신뢰도를 보수적으로 조정'));
    });

    test('신뢰도는 1순위 선수의 예상 승률과 같다', () {
      final prediction = PredictionEngine.predict(
        List.generate(6, (index) => _entry(index + 1)),
      );

      expect(
        prediction.confidence,
        closeTo(prediction.rankings.first.winProb, 0.001),
      );
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
        _entry(1, grade: 'A1', avgRankPoint: 7),
        _entry(2, grade: 'A2', avgRankPoint: 6),
        _entry(3, grade: 'B1', avgRankPoint: 5),
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
