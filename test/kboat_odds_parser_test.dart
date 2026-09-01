import 'dart:io';

import 'package:boat_racing/core/services/kboat_scraper_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 픽스처는 KBOAT 최종배당률 페이지의 실제 응답이다.
/// - `kboat_final_odds.html`: 2026년 35회 2일차 17경주 (7개 승식 전부)
/// - `kboat_final_odds_scratch.html`: 같은 일차 13경주의 단승·연승 구간.
///   2번 코스가 결장해 배당이 `-` 로 들어온다.
///
/// 손으로 만든 이상적인 표는 실제 마크업과 구조가 달라(특히 삼쌍승식은 3착이
/// `<th>`, 배당이 `<td>`) 파싱 실패를 잡아내지 못한다. 그래서 실제 응답을 쓴다.
void main() {
  final service = KboatScraperService();
  final odds = service.parseFinalOddsHtml(
    File('test/fixtures/kboat_final_odds.html').readAsStringSync(),
  );

  test('한 자리 경주번호를 KBOAT URL의 두 자리 형식으로 변환한다', () {
    final url = service.finalOddsRequestUrl(
      year: '2026',
      weekTcnt: 33,
      dayTcnt: 2,
      raceNo: 1,
    );

    expect(url, endsWith('/2026/33/2/01'));
  });

  test('단승식·연승식을 코스별로 읽는다', () {
    expect(odds.win, {
      1: 1.5,
      2: 5.1,
      3: 4.0,
      4: 116.0,
      5: 36.3,
      6: 13.7,
    });
    expect(odds.show, {
      1: 1.1,
      2: 1.6,
      3: 1.5,
      4: 25.4,
      5: 14.3,
      6: 6.2,
    });
  });

  test('쌍승식은 순서를 구분해 30개 조합을 모두 읽는다', () {
    expect(odds.exacta.length, 30);
    expect(odds.exacta['1-3'], 3.0);
    expect(odds.exacta['3-1'], 9.3);
    expect(odds.exacta['4-3'], 517.2);
    // 같은 코스 조합은 존재하지 않는다.
    expect(odds.exacta.containsKey('1-1'), isFalse);
  });

  test('복승식은 순서를 합쳐 15개 조합만 읽는다', () {
    expect(odds.place.length, 15);
    expect(odds.place['1-3'], 2.2);
    expect(odds.place['1-2'], 3.8);
    expect(odds.place['4-5'], 212.6);
    expect(odds.place.containsKey('3-1'), isFalse);
  });

  test('삼복승식 20개, 쌍복승식 60개 조합을 읽는다', () {
    expect(odds.trio.length, 20);
    expect(odds.trio['1-2-3'], 2.6);
    expect(odds.trio['4-5-6'], 222.3);

    expect(odds.xla.length, 60);
    expect(odds.xla['1-2-3'], 4.0);
    expect(odds.xla['4-1-2'], 1924.7);
  });

  test('삼쌍승식 120개 조합을 3착(th)과 배당(td) 짝으로 읽는다', () {
    expect(odds.trifecta.length, 120);
    expect(odds.trifecta['1-2-3'], 9.6);
    // 1·2착 순서가 바뀌면 다른 조합이다.
    expect(odds.trifecta['1-3-2'], 6.9);
    expect(odds.trifecta['4-5-2'], 4342.1);
    expect(odds.trifecta['6-5-4'], 1912.3);
  });

  test('결장 코스만 제외하고 나머지 배당은 유지한다', () {
    final scratch = service.parseFinalOddsHtml(
      File('test/fixtures/kboat_final_odds_scratch.html').readAsStringSync(),
    );

    expect(scratch.win, {1: 1.4, 3: 3.3, 4: 9.2, 5: 19.3, 6: 22.1});
    expect(scratch.show, {1: 1.0, 3: 1.7, 4: 1.8, 5: 14.4, 6: 5.9});
    expect(scratch.isEmpty, isFalse);
  });

  test('빈 응답은 빈 배당으로 처리한다', () {
    expect(service.parseFinalOddsHtml('').isEmpty, isTrue);
  });

  group('확정배당률', () {
    final decision = service.parseDecisionOddsHtml(
      File('test/fixtures/kboat_decision_odds.html').readAsStringSync(),
    );

    test('경주번호를 두 자리로 맞춘 확정배당 주소를 만든다', () {
      expect(
        service.decisionOddsRequestUrl(
          year: '2026',
          weekTcnt: 35,
          dayTcnt: 2,
          raceNo: 1,
        ),
        endsWith('/dividendrate/decision/2026/35/2/01'),
      );
    });

    /// 35회 2일차 1경주는 5→2→1 로 들어왔고, 페이지에 실린 확정배당은
    /// 단승 2.7 / 연승 1.2·6.0 / 쌍승 26.4 / 복승 17.8 / 삼복승 3.4 /
    /// 쌍복승 12.3 / 삼쌍승 63.8 이다.
    test('승식 7종을 모두 읽는다', () {
      expect(decision.win, 2.7);
      expect(decision.exacta, 26.4);
      expect(decision.quinella, 17.8);
      expect(decision.trio, 3.4);
      expect(decision.xla, 12.3);
      expect(decision.trifecta, 63.8);
      expect(decision.isEmpty, isFalse);
    });

    test('연승은 1착 몫과 2착 몫을 따로 읽는다', () {
      expect(decision.placeFirst, 1.2);
      expect(decision.placeSecond, 6.0);
    });

    test('쌍승과 복승을 뒤바꾸지 않는다', () {
      // 같은 5-2 조합이지만 순서를 가리는 쌍승이 항상 더 높다.
      expect(decision.exacta! > decision.quinella!, isTrue);
    });

    test('빈 응답은 빈 확정배당으로 처리한다', () {
      expect(service.parseDecisionOddsHtml('').isEmpty, isTrue);
    });

    test('취소된 승식은 null 로 남긴다', () {
      const html = '''
      <table>
        <thead><tr><th>승식</th><th>단승</th><th>연승</th><th>연승</th><th>삼쌍승</th></tr></thead>
        <tbody>
          <tr><th>승자</th><td>5</td><td>5</td><td>[ ]</td><td>[ ]-[ ]-[ ]</td></tr>
          <tr><th>배당률(%)</th><td>2.7</td><td>1.2</td><td>-</td><td>-</td></tr>
        </tbody>
      </table>
      ''';

      final cancelled = service.parseDecisionOddsHtml(html);

      expect(cancelled.win, 2.7);
      expect(cancelled.placeFirst, 1.2);
      expect(cancelled.placeSecond, isNull);
      expect(cancelled.trifecta, isNull);
    });
  });

  /// `kboat_race_result_general.html`: 2026년 35회 2일차 1경주 경주결과.
  /// 착순 표 앞에 경주정보·날씨·주회기록 표가 먼저 나오므로, 파서가 착순 표를
  /// 제대로 골라내는지도 함께 확인한다.
  group('경주기록', () {
    final records = service.parseRaceRecordsHtml(
      File('test/fixtures/kboat_race_result_general.html').readAsStringSync(),
    );

    test('한 자리 경주번호를 KBOAT URL의 두 자리 형식으로 변환한다', () {
      final url = service.raceRecordsRequestUrl(
        year: '2026',
        weekTcnt: 35,
        dayTcnt: 2,
        raceNo: 1,
      );

      expect(url, endsWith('/race/result/general/2026/35/2/01'));
    });

    test('착순별 항주시간을 읽는다', () {
      expect(records, {
        1: '1:14.645',
        2: '1:17.337',
        3: '1:18.258',
        4: '1:19.023',
        5: '1:20.139',
        6: '1:20.856',
      });
    });

    test('주회기록 표가 아니라 착순 표에서 읽는다', () {
      // 주회기록 표의 2주회 값도 1착 기록과 같지만, 그 표에는 착순이 없다.
      expect(records.length, 6);
    });

    test('빈 응답은 빈 기록으로 처리한다', () {
      expect(service.parseRaceRecordsHtml(''), isEmpty);
    });

    test('기록 없는 착순은 건너뛴다', () {
      const html = '''
      <table>
        <thead><tr><th>착순</th><th>선수정보</th><th>ST</th><th>항주시간</th><th>비고</th></tr></thead>
        <tbody>
          <tr><th>1</th><td>5 문주엽</td><td>0.11</td><td>1:14.645</td><td>-</td></tr>
          <tr><th>2</th><td>2 김보경</td><td>0.25</td><td>-</td><td>-</td></tr>
        </tbody>
      </table>
      ''';

      expect(service.parseRaceRecordsHtml(html), {1: '1:14.645'});
    });
  });
}
