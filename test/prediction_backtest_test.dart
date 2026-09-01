import 'dart:convert';
import 'dart:io';

import 'package:boat_racing/core/services/prediction_engine.dart';
import 'package:boat_racing/models/race_entry.dart';
import 'package:boat_racing/models/race_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026 시즌 홀드아웃 백테스트.
///
/// 모델은 2023~2025 시즌 5,301경주로 학습했고 이 픽스처는 학습에 쓰이지 않았다.
/// 파이썬 학습 파이프라인이 낸 수치를 Dart 엔진이 그대로 재현하는지 확인해,
/// 계수나 피처 매핑이 어긋나면 바로 드러나게 한다.
void main() {
  test('2026 홀드아웃에서 학습 당시 적중률을 재현한다', () {
    final payload =
        jsonDecode(
              File('test/fixtures/holdout_2026.json').readAsStringSync(),
            )
            as Map<String, dynamic>;

    final grades = (payload['grades'] as List).cast<String>();
    final races = (payload['races'] as List).cast<Map<String, dynamic>>();

    var top1Hits = 0;
    var winHits = 0;
    var placeHits = 0;
    var quinellaHits = 0;

    for (final race in races) {
      final podium = (race['podium'] as List).cast<int>();
      final entries = <RaceEntry>[];

      var course = 0;
      for (final row in (race['entries'] as List).cast<List<dynamic>>()) {
        final values = row.map((value) => (value as num).toDouble()).toList();
        course = values[0].toInt();
        final gradeIndex = values[1].toInt();
        entries.add(
          RaceEntry(
            courseNo: course,
            racerName: '$course',
            racerId: '$course',
            grade: gradeIndex >= 0 ? grades[gradeIndex] : '',
            avgRankPoint: _orNull(values[2]),
            top2Rate: _orNull(values[3]),
            motorRankPoint: _orNull(values[4]),
            motorWinRate: _orNull(values[5]),
            motorTop3Rate: _orNull(values[6]),
            boatRankPoint: _orNull(values[7]),
            boatWinRate: _orNull(values[8]),
          ),
        );
      }

      final prediction = PredictionEngine.predict(entries);
      final evaluation = PredictionEngine.evaluate(
        prediction,
        RaceResult(
          raceNo: 1,
          first: '',
          firstNo: podium[0],
          second: '',
          secondNo: podium[1],
          third: '',
          thirdNo: podium[2],
        ),
      );

      if (prediction.rankings.first.courseNo == podium[0]) top1Hits++;
      if (evaluation.winHit) winHits++;
      if (evaluation.placeHit) placeHits++;
      if (evaluation.quinellaHit) quinellaHits++;
    }

    final total = races.length;
    double rate(int hits) => hits / total * 100;

    // 학습 파이프라인이 보고한 값. 정렬 동점 처리 차이만큼만 허용한다.
    expect(total, 1130);
    expect(rate(top1Hits), closeTo(51.86, 0.5));
    expect(rate(winHits), closeTo(72.74, 0.5));
    expect(rate(placeHits), closeTo(45.58, 0.5));
    expect(rate(quinellaHits), closeTo(32.39, 0.5));

    // 교체 전 heuristic-v2 가 같은 구간에서 기록한 값보다 확실히 높아야 한다.
    expect(rate(top1Hits), greaterThan(42.12));
    expect(rate(placeHits), greaterThan(35.84));
  });
}

double? _orNull(double value) => value < 0 ? null : value;
