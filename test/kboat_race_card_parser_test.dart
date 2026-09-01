import 'dart:io';

import 'package:boat_racing/core/services/kboat_scraper_service.dart';
import 'package:boat_racing/core/services/prediction_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 픽스처는 2026년 35회 2일차 확정출주표의 1~2경주 구획이다.
/// 예측 모델이 쓰는 값은 '최근 6회차'가 아니라 '연간' 컬럼이므로, 어느 컬럼을
/// 읽는지가 그대로 적중률에 영향을 준다.
void main() {
  final html = File(
    'test/fixtures/kboat_race_card.html',
  ).readAsStringSync();
  final service = KboatScraperService();

  test('경주별로 6명씩 분리해 파싱한다', () {
    final races = service.parseRaceCardHtml(html);

    expect(races.keys.toList()..sort(), [1, 2]);
    for (final entries in races.values) {
      expect(entries.length, 6);
      expect(entries.map((e) => e.courseNo), [1, 2, 3, 4, 5, 6]);
    }
  });

  test('선수 기록을 연간 컬럼에서 읽는다', () {
    final first = service.parseRaceCardHtml(html)[1]!.first;

    expect(first.racerName, '박진서');
    expect(first.racerId, '11-011');
    expect(first.grade, 'A1');
    expect(first.weight, 57);
    // 연간 평균착순점 6.88 / 연간 연대율 57.6% (최근 6회차는 6.78 / 55.6%)
    expect(first.avgRankPoint, 6.88);
    expect(first.top2Rate, 57.6);
    // 최근 6회차 값은 화면 표시용으로 그대로 유지한다.
    expect(first.avgScore, 6.67);
    expect(first.winRate, 22.2);
    expect(first.avgStartTime, 0.22);
  });

  test('둘째 표에서 모터와 보트 성적을 이어 붙인다', () {
    final first = service.parseRaceCardHtml(html)[1]!.first;

    expect(first.motorNo, 45);
    expect(first.motorRankPoint, 4.3);
    expect(first.motorWinRate, 21.7);
    expect(first.motorTop3Rate, 37.7);
    expect(first.boatNo, 8);
    expect(first.boatRankPoint, 5.44);
    expect(first.boatWinRate, 38);
  });

  test('둘째 경주도 자기 구획의 장비 성적을 쓴다', () {
    final second = service.parseRaceCardHtml(html)[2]!.first;

    expect(second.motorNo, 5);
    expect(second.motorRankPoint, 5.25);
    expect(second.boatNo, 25);
    expect(second.boatWinRate, 37.4);
  });

  test('출주표에서 바로 예측하면 모든 모델 피처가 채워진다', () {
    // 당일 경주는 공공 API 대신 이 출주표만 쓸 수 있으므로, 여기서 피처가 비면
    // 모델이 학습 평균으로 대체돼 적중률이 떨어진다.
    final prediction = PredictionEngine.predict(
      service.parseRaceCardHtml(html)[1]!,
    );

    for (final racer in prediction.rankings) {
      expect(
        racer.factors.keys,
        containsAll(['코스', '등급', '평균착순점', '연대율', '모터', '보트']),
        reason: '${racer.courseNo}코스 피처 누락',
      );
    }
  });
}
