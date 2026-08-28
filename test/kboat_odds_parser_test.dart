import 'package:boat_racing/core/services/kboat_scraper_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _section(String title, String tables) {
  return '<div class="comTitH3"><h3>$title</h3></div>$tables';
}

const _courseTable = '''
<table><tbody><tr>
  <td>1.1</td><td>2.2</td><td>3.3</td>
  <td>4.4</td><td>5.5</td><td>6.6</td>
</tr></tbody></table>
''';

const _matrixTable = '''
<table><tbody>
  <tr><th>1</th><td></td><td>1.2</td><td>1.3</td><td>1.4</td><td>1.5</td><td>1.6</td></tr>
  <tr><th>2</th><td>2.1</td><td></td><td>2.3</td><td>2.4</td><td>2.5</td><td>2.6</td></tr>
</tbody></table>
''';

void main() {
  test('한 자리 경주번호를 KBOAT URL의 두 자리 형식으로 변환한다', () {
    final url = KboatScraperService().finalOddsRequestUrl(
      year: '2026',
      weekTcnt: 33,
      dayTcnt: 2,
      raceNo: 1,
    );

    expect(url, endsWith('/2026/33/2/01'));
  });

  test('KBOAT 최종배당 7개 승식을 모두 파싱한다', () {
    final html = [
      _section('단승식', _courseTable),
      _section('연승식', _courseTable),
      _section('쌍승식', _matrixTable),
      _section('복승식', _matrixTable),
      _section('삼복승식', '<table><tr><td>1-2-3</td><td>3.2</td></tr></table>'),
      _section('쌍복승식', '<table><tr><td>1-2-3</td><td>6.5</td></tr></table>'),
      _section('삼쌍승식', '''
        <table>
          <thead><tr><th>1-2</th><th></th><th>1-3</th><th></th></tr></thead>
          <tbody><tr><td>3</td><td>9.9</td><td>2</td><td>11.9</td></tr></tbody>
        </table>
        '''),
    ].join();

    final odds = KboatScraperService().parseFinalOddsHtml(html);

    expect(odds.win, containsPair(1, 1.1));
    expect(odds.show, containsPair(6, 6.6));
    expect(odds.exacta, containsPair('2-1', 2.1));
    expect(odds.place, containsPair('1-2', 1.2));
    expect(odds.place, isNot(contains('2-1')));
    expect(odds.trio, containsPair('1-2-3', 3.2));
    expect(odds.xla, containsPair('1-2-3', 6.5));
    expect(odds.trifecta, containsPair('1-2-3', 9.9));
    expect(odds.trifecta, containsPair('1-3-2', 11.9));
    expect(odds.isEmpty, isFalse);
  });
}
