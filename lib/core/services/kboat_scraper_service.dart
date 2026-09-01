import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../../models/race.dart';
import '../../models/race_entry.dart';
import '../../models/race_result.dart';
import '../../models/odds.dart';

class KboatVideoInfo {
  final String dateYmd;
  final int raceNo;
  final int weekTcnt;
  final int dayTcnt;

  const KboatVideoInfo({
    required this.dateYmd,
    required this.raceNo,
    required this.weekTcnt,
    required this.dayTcnt,
  });
}

class KboatRaceResultBundle {
  final Map<int, RaceResult> results;
  final Map<int, List<Map<String, dynamic>>> ranks;
  const KboatRaceResultBundle({required this.results, required this.ranks});
}

class KboatScraperService {
  static const _baseUrl = 'https://www.kboat.or.kr/broadcast/racevideo';
  static const _resultUrl = 'https://www.kboat.or.kr/main/race/result';
  static const _cardUrl = 'https://www.kboat.or.kr/race/card/decision';
  static const _finalOddsUrl =
      'https://www.kboat.or.kr/race/dividendrate/final';
  final Dio _dio = dioClient;

  final Map<String, List<KboatVideoInfo>> _cache = {};
  final Map<String, Set<String>> _monthDatesCache = {};
  final Map<int, Map<String, (int, int)>> _dateMappingCache = {};
  final Map<String, List<Race>> _cardRaceListCache = {};
  KboatRaceResultBundle? _resultCache;
  String? _resultCacheDate;
  final Map<String, ({Odds odds, DateTime fetchedAt})> _oddsCache = {};

  String _monthKey(int year, int month) =>
      '$year${month.toString().padLeft(2, '0')}';

  /// 특정 기간의 경주 동영상 정보를 KBOAT에서 스크래핑
  Future<List<KboatVideoInfo>> fetchVideos({
    required String startDate,
    required String endDate,
  }) async {
    final cacheKey = '$startDate-$endDate';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final results = <KboatVideoInfo>[];
    final seen = <String>{};

    try {
      for (int page = 1; page <= 15; page++) {
        final formData = FormData.fromMap({
          'pagination.currentPage': page,
          'dateRange': '',
          'startDate': _formatDot(startDate),
          'endDate': _formatDot(endDate),
        });

        final res = await _dio.post(
          _baseUrl,
          data: formData,
          options: Options(
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'Accept': 'text/html',
            },
          ),
        );

        final html = res.data?.toString() ?? '';
        if (html.isEmpty) break;

        final pattern = RegExp(
          r'(\d+)회\s*(\d+)일차\s*(\d+)경주\((\d{2})월\s*(\d{2})일\)',
        );

        final year = startDate.substring(0, 4);
        final matches = pattern.allMatches(html);
        if (matches.isEmpty) break;

        for (final m in matches) {
          final weekTcnt = int.parse(m.group(1)!);
          final dayTcnt = int.parse(m.group(2)!);
          final raceNo = int.parse(m.group(3)!);
          final mm = m.group(4)!;
          final dd = m.group(5)!;
          final dateYmd = '$year$mm$dd';

          final key = '${dateYmd}_$raceNo';
          if (seen.contains(key)) continue;
          seen.add(key);

          results.add(
            KboatVideoInfo(
              dateYmd: dateYmd,
              raceNo: raceNo,
              weekTcnt: weekTcnt,
              dayTcnt: dayTcnt,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 스크래핑 실패: $e');
    }

    _cache[cacheKey] = results;
    return results;
  }

  /// 월별 경기 날짜 조회
  Future<Set<String>> fetchRaceDatesForMonth({
    required int year,
    required int month,
  }) async {
    final key = _monthKey(year, month);
    if (_monthDatesCache.containsKey(key)) return _monthDatesCache[key]!;

    final mm = month.toString().padLeft(2, '0');
    final startDate = '$year.$mm.01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDate = '$year.$mm.$lastDay';

    try {
      final dates = <String>{};

      for (int page = 1; page <= 15; page++) {
        final formData = FormData.fromMap({
          'pagination.currentPage': page,
          'dateRange': '',
          'startDate': startDate,
          'endDate': endDate,
        });

        final res = await _dio.post(
          _baseUrl,
          data: formData,
          options: Options(
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'Accept': 'text/html',
            },
          ),
        );

        final html = res.data?.toString() ?? '';
        if (html.isEmpty) break;

        final pattern = RegExp(r'(\d{2})월\s*(\d{2})일\)');
        final matches = pattern.allMatches(html);
        if (matches.isEmpty) break;

        bool foundNew = false;
        for (final m in matches) {
          final dateYmd = '$year${m.group(1)!}${m.group(2)!}';
          if (dates.add(dateYmd)) foundNew = true;
        }
        if (!foundNew) break;
      }

      _monthDatesCache[key] = dates;
      return dates;
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 월별 날짜 스크래핑 실패: $e');
      return {};
    }
  }

  /// 특정 날짜의 경주 목록을 Race 객체로 변환
  ///
  /// 우선순위:
  /// 1. 확정출주표 페이지(`/race/card/decision`) — 오늘/미래 경주 포함, 출발시간·거리 포함
  /// 2. 경주영상 페이지(`/broadcast/racevideo`) — 과거 경주(영상 존재) 한정
  Future<List<Race>> fetchRaceList({required String date}) async {
    final cardRaces = await fetchRaceListFromCard(
      date: date,
    ).catchError((_) => <Race>[]);
    if (cardRaces.isNotEmpty) return cardRaces;

    final year = date.substring(0, 4);
    final mm = date.substring(4, 6);

    final videos = await fetchVideos(startDate: date, endDate: date);

    final filtered = videos.where((v) => v.dateYmd == date).toList();
    if (filtered.isEmpty) {
      final all = await fetchVideos(
        startDate: '$year${mm}01',
        endDate:
            '$year$mm${DateTime(int.parse(year), int.parse(mm) + 1, 0).day}',
      );
      filtered.addAll(all.where((v) => v.dateYmd == date));
    }

    if (filtered.isEmpty) return [];

    final raceNos = filtered.map((v) => v.raceNo).toSet().toList()..sort();

    return raceNos.map((no) {
      return Race(
        venueCode: 1,
        date: date,
        raceNo: no,
        venueName: '미사리경정공원',
        distance: 600,
        status: '예정',
        departureTime: Race.defaultDepartureTimes[no],
        racerCount: 6,
      );
    }).toList();
  }

  // ─── 확정출주표 페이지 기반 (오늘/미래 경주 지원) ───

  /// `/race/card/decision` 페이지에서 연간 (날짜 → 회차/일차) 매핑 추출
  Future<Map<String, (int, int)>> fetchDateMappings({int? year}) async {
    final y = year ?? DateTime.now().year;
    if (_dateMappingCache.containsKey(y)) return _dateMappingCache[y]!;

    try {
      final res = await _dio.post(
        _cardUrl,
        data: FormData.fromMap({'stndYear': y.toString()}),
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          },
        ),
      );

      final html = res.data?.toString() ?? '';
      if (html.isEmpty) return {};

      // (NN회 N일) MM월 DD일 패턴
      final pattern = RegExp(r'\((\d+)회\s*(\d+)일\)\s*(\d{1,2})월\s*(\d{1,2})일');

      final mappings = <String, (int, int)>{};
      for (final m in pattern.allMatches(html)) {
        final tms = int.parse(m.group(1)!);
        final day = int.parse(m.group(2)!);
        final mm = m.group(3)!.padLeft(2, '0');
        final dd = m.group(4)!.padLeft(2, '0');
        mappings['$y$mm$dd'] = (tms, day);
      }

      _dateMappingCache[y] = mappings;
      return mappings;
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 날짜 매핑 스크래핑 실패: $e');
      return {};
    }
  }

  /// 특정 날짜에 해당하는 (week_tcnt, day_tcnt) 조회
  Future<(int, int)?> getWeekDayForDate(String date) async {
    if (date.length != 8) return null;
    final year = int.parse(date.substring(0, 4));
    final mappings = await fetchDateMappings(year: year);
    return mappings[date];
  }

  Future<Odds> fetchFinalOdds({
    required String date,
    required int raceNo,
  }) async {
    final cacheKey = '${date}_$raceNo';
    final cached = _oddsCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(seconds: 15)) {
      return cached.odds;
    }

    final weekDay = await getWeekDayForDate(date);
    if (weekDay == null || date.length < 4) return const Odds();

    try {
      final year = date.substring(0, 4);
      final response = await _dio.get(
        finalOddsRequestUrl(
          year: year,
          weekTcnt: weekDay.$1,
          dayTcnt: weekDay.$2,
          raceNo: raceNo,
        ),
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          },
        ),
      );
      final html = response.data?.toString() ?? '';
      final odds = parseFinalOddsHtml(html);
      if (!odds.isEmpty) {
        _oddsCache[cacheKey] = (odds: odds, fetchedAt: DateTime.now());
      }
      return odds;
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 최종배당 조회 실패: $e');
      return const Odds();
    }
  }

  @visibleForTesting
  String finalOddsRequestUrl({
    required String year,
    required int weekTcnt,
    required int dayTcnt,
    required int raceNo,
  }) {
    final raceNoPath = raceNo.toString().padLeft(2, '0');
    return '$_finalOddsUrl/$year/$weekTcnt/$dayTcnt/$raceNoPath';
  }

  @visibleForTesting
  Odds parseFinalOddsHtml(String html) {
    if (html.isEmpty) return const Odds();

    final sections = <String, String>{};
    final headings = RegExp(
      r'<div\s+class="comTitH3">\s*<h3>(.*?)</h3>\s*</div>',
      dotAll: true,
    ).allMatches(html).toList();
    for (var index = 0; index < headings.length; index++) {
      final title = _plainText(headings[index].group(1) ?? '');
      final end = index + 1 < headings.length
          ? headings[index + 1].start
          : html.length;
      sections[title] = html.substring(headings[index].end, end);
    }

    return Odds(
      win: _parseCourseTable(sections['단승식']),
      show: _parseCourseTable(sections['연승식']),
      exacta: _parseMatrixTable(sections['쌍승식'], ordered: true),
      place: _parseMatrixTable(sections['복승식'], ordered: false),
      trio: _parseCombinationTables(sections['삼복승식'], size: 3),
      xla: _parseCombinationTables(sections['쌍복승식'], size: 3),
      trifecta: _parseTrifectaTables(sections['삼쌍승식']),
    );
  }

  Map<int, double> _parseCourseTable(String? section) {
    if (section == null) return const {};
    for (final row in _tableRows(section)) {
      final values = _dataCells(
        row,
      ).map((cell) => double.tryParse(_plainText(cell))).toList();
      if (values.length < 6 || values.take(6).any((value) => value == null)) {
        continue;
      }
      return {
        for (var index = 0; index < 6; index++) index + 1: values[index]!,
      };
    }
    return const {};
  }

  Map<String, double> _parseMatrixTable(
    String? section, {
    required bool ordered,
  }) {
    if (section == null) return const {};
    final result = <String, double>{};
    for (final row in _tableRows(section)) {
      final cells = _allCells(row).map(_plainText).toList();
      if (cells.length < 7) continue;
      final first = int.tryParse(cells.first);
      if (first == null || first < 1 || first > 6) continue;
      for (var column = 1; column <= 6; column++) {
        final value = double.tryParse(cells[column]);
        if (value == null || first == column) continue;
        if (!ordered && first > column) continue;
        result['$first-$column'] = value;
      }
    }
    return result;
  }

  Map<String, double> _parseCombinationTables(
    String? section, {
    required int size,
  }) {
    if (section == null) return const {};
    final result = <String, double>{};
    final combinationPattern = RegExp(
      size == 3 ? r'^[1-6]-[1-6]-[1-6]$' : r'^[1-6]-[1-6]$',
    );
    for (final row in _tableRows(section)) {
      final cells = _allCells(row).map(_plainText).toList();
      for (var index = 0; index + 1 < cells.length; index += 2) {
        final combination = cells[index];
        final value = double.tryParse(cells[index + 1]);
        if (combinationPattern.hasMatch(combination) && value != null) {
          result[combination] = value;
        }
      }
    }
    return result;
  }

  Map<String, double> _parseTrifectaTables(String? section) {
    if (section == null) return const {};
    final result = <String, double>{};
    final tables = RegExp(
      r'<table\b[^>]*>(.*?)</table>',
      dotAll: true,
    ).allMatches(section);
    for (final tableMatch in tables) {
      final table = tableMatch.group(1) ?? '';
      final firstTwo = RegExp(
        r'>\s*([1-6]-[1-6])\s*<',
      ).allMatches(table).map((match) => match.group(1)!).toList();
      if (firstTwo.isEmpty) continue;

      for (final row in _tableRows(table)) {
        final cells = _dataCells(row).map(_plainText).toList();
        if (cells.length < firstTwo.length * 2) continue;
        for (var index = 0; index < firstTwo.length; index++) {
          final third = int.tryParse(cells[index * 2]);
          final value = double.tryParse(cells[index * 2 + 1]);
          if (third != null && value != null) {
            result['${firstTwo[index]}-$third'] = value;
          }
        }
      }
    }
    return result;
  }

  Iterable<String> _tableRows(String html) {
    return RegExp(
      r'<tr\b[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(html).map((match) => match.group(1) ?? '');
  }

  List<String> _allCells(String row) {
    return RegExp(
      r'<t[hd]\b[^>]*>(.*?)</t[hd]>',
      dotAll: true,
    ).allMatches(row).map((match) => match.group(1) ?? '').toList();
  }

  List<String> _dataCells(String row) {
    return RegExp(
      r'<td\b[^>]*>(.*?)</td>',
      dotAll: true,
    ).allMatches(row).map((match) => match.group(1) ?? '').toList();
  }

  String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', '')
        .replaceAll('&#45;', '-')
        .trim();
  }

  /// 확정출주표 페이지에서 경주 목록 추출 (오늘/미래 경주 표시용)
  Future<List<Race>> fetchRaceListFromCard({required String date}) async {
    if (_cardRaceListCache.containsKey(date)) {
      return _cardRaceListCache[date]!;
    }

    final wd = await getWeekDayForDate(date);
    if (wd == null) return [];

    try {
      final year = date.substring(0, 4);
      final res = await _dio.post(
        _cardUrl,
        data: FormData.fromMap({
          'stndYear': year,
          'tms': wd.$1.toString(),
          'dayOrd': wd.$2.toString(),
        }),
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          },
        ),
      );

      final html = res.data?.toString() ?? '';
      if (html.isEmpty) return [];

      final races = _parseRaceListFromCardHtml(html, date);
      _cardRaceListCache[date] = races;
      return races;
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 출주표 경주 목록 실패: $e');
      return [];
    }
  }

  List<Race> _parseRaceListFromCardHtml(String html, String date) {
    final racePattern = RegExp(
      r'제\s*(\d+)경주\s*\(\s*출발시간\s*(\d{1,2}:\d{2})\s*\)',
    );
    final distPattern = RegExp(
      r'(?:일반|메이퀸)\s+(?:플라잉|온라인)\s+\d주회\s*\(\s*(\d+)m\s*\)',
    );

    final matches = racePattern.allMatches(html).toList();
    if (matches.isEmpty) return [];

    // 동일 raceNo가 HTML 내 여러 위치에 등장(제목/표 헤더)하므로 중복 제거.
    final byRaceNo = <int, Race>{};
    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final raceNo = int.parse(m.group(1)!);
      if (byRaceNo.containsKey(raceNo)) continue;

      final time = m.group(2)!;
      final segEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : html.length;
      final segment = html.substring(m.start, segEnd);
      final distMatch = distPattern.firstMatch(segment);
      final distance = distMatch != null
          ? int.tryParse(distMatch.group(1)!) ?? 600
          : 600;

      byRaceNo[raceNo] = Race(
        venueCode: 1,
        date: date,
        raceNo: raceNo,
        venueName: '미사리경정공원',
        distance: distance,
        status: '예정',
        departureTime: time,
        racerCount: 6,
      );
    }

    final races = byRaceNo.values.toList()
      ..sort((a, b) => a.raceNo.compareTo(b.raceNo));
    return races;
  }

  Future<KboatRaceResultBundle?>? _resultInFlight;

  /// KBOAT 메인페이지 경주결과 API (당일 결과만 제공)
  Future<KboatRaceResultBundle?> fetchTodayResults() {
    final now = DateTime.now();
    final todayYmd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    if (_resultCacheDate == todayYmd && _resultCache != null) {
      return Future.value(_resultCache);
    }

    return _resultInFlight ??= _fetchTodayResultsImpl(todayYmd);
  }

  Future<KboatRaceResultBundle?> _fetchTodayResultsImpl(String todayYmd) async {
    try {
      final res = await _dio.get(
        _resultUrl,
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/json',
          },
        ),
      );

      final body = res.data;
      Map<String, dynamic> json;
      if (body is Map<String, dynamic>) {
        json = body;
      } else if (body is String && body.trim().startsWith('{')) {
        json = jsonDecode(body) as Map<String, dynamic>;
      } else {
        return null;
      }

      final resultsList = json['results'];
      if (resultsList is! List || resultsList.isEmpty) return null;

      final results = <int, RaceResult>{};
      final ranks = <int, List<Map<String, dynamic>>>{};

      for (final rs in resultsList) {
        if (rs is! Map<String, dynamic>) continue;
        final raceNo = int.tryParse(rs['raceNo']?.toString() ?? '') ?? 0;
        if (raceNo == 0) continue;

        final rank1 = rs['rank1']?.toString() ?? '';
        final rank2 = rs['rank2']?.toString() ?? '';
        final rank3 = rs['rank3']?.toString() ?? '';
        final (firstNo, firstName) = _parseKboatRank(rank1);
        final (secondNo, secondName) = _parseKboatRank(rank2);
        final (thirdNo, thirdName) = _parseKboatRank(rank3);

        if (firstName.isEmpty) continue;

        double parseOdds(String key) =>
            double.tryParse(rs[key]?.toString() ?? '') ?? 0;

        final placeStr = rs['place']?.toString() ?? '0';
        double placeOdds = 0;
        if (placeStr.contains('/')) {
          placeOdds = double.tryParse(placeStr.split('/')[0]) ?? 0;
        } else {
          placeOdds = double.tryParse(placeStr) ?? 0;
        }

        results[raceNo] = RaceResult(
          raceNo: raceNo,
          first: firstName,
          firstNo: firstNo,
          second: secondName,
          secondNo: secondNo,
          third: thirdName,
          thirdNo: thirdNo,
          winOdds: parseOdds('win'),
          placeOdds: placeOdds,
          quinellaOdds: parseOdds('quinella'),
          exactaOdds: parseOdds('exacta'),
          triellaOdds: parseOdds('triella'),
          xlaOdds: parseOdds('xla'),
          trxOdds: parseOdds('trx'),
        );

        final rankRacer = rs['rankRacer']?.toString() ?? '';
        if (rankRacer.isNotEmpty) {
          ranks[raceNo] = _parseRankRacer(rankRacer);
        }
      }

      if (results.isEmpty) return null;

      final bundle = KboatRaceResultBundle(results: results, ranks: ranks);
      _resultCache = bundle;
      _resultCacheDate = todayYmd;
      if (kDebugMode) {
        debugPrint('[KBOAT] 경주결과 ${results.length}건 로드 완료');
      }
      return bundle;
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 경주결과 조회 실패: $e');
      return null;
    } finally {
      _resultInFlight = null;
    }
  }

  /// "코스번호-선수명" 형식 파싱 (e.g., "1-박정아")
  (int, String) _parseKboatRank(String s) {
    if (s.isEmpty) return (0, '');
    final idx = s.indexOf('-');
    if (idx < 0) return (0, s);
    final no = int.tryParse(s.substring(0, idx)) ?? 0;
    final name = s.substring(idx + 1).trim();
    return (no, name);
  }

  /// "순위-코스-이름,..." 형식 파싱 (e.g., "1-1-박정아,2-2-오세준,3-6-김응선")
  List<Map<String, dynamic>> _parseRankRacer(String s) {
    final entries = s.split(',');
    final result = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final parts = entry.split('-');
      if (parts.length < 3) continue;
      final rank = int.tryParse(parts[0]) ?? 0;
      final courseNo = int.tryParse(parts[1]) ?? 0;
      final name = parts.sublist(2).join('-');
      if (rank > 0) {
        result.add({
          'rank': rank,
          'race_rank': rank,
          'course_no': courseNo,
          'racer_nm': name.trim(),
        });
      }
    }
    return result;
  }

  /// 날짜 형식 변환 (yyyyMMdd → yyyy.MM.dd)
  String _formatDot(String ymd) {
    if (ymd.contains('.')) return ymd;
    if (ymd.length == 8) {
      return '${ymd.substring(0, 4)}.${ymd.substring(4, 6)}.${ymd.substring(6, 8)}';
    }
    return ymd;
  }

  // ─── 출주표 스크래핑 (KBOAT 확정출주표) ───

  final Map<String, List<RaceEntry>> _entryCache = {};

  Future<List<RaceEntry>> fetchRaceEntries({
    required int weekTcnt,
    required int dayTcnt,
    required int raceNo,
  }) async {
    final cacheKey = '$weekTcnt-$dayTcnt-$raceNo';
    if (_entryCache.containsKey(cacheKey)) return _entryCache[cacheKey]!;

    try {
      final year = DateTime.now().year;
      final res = await _dio.post(
        _cardUrl,
        data: FormData.fromMap({
          'stndYear': year.toString(),
          'tms': weekTcnt.toString(),
          'dayOrd': dayTcnt.toString(),
        }),
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          },
        ),
      );

      final html = res.data?.toString() ?? '';
      if (html.isEmpty) return [];

      final allEntries = parseRaceCardHtml(html);
      for (final entry in allEntries.entries) {
        _entryCache['$weekTcnt-$dayTcnt-${entry.key}'] = entry.value;
      }

      return _entryCache[cacheKey] ?? [];
    } catch (e) {
      if (kDebugMode) debugPrint('[KBOAT] 출주표 스크래핑 실패: $e');
      return [];
    }
  }

  @visibleForTesting
  Map<int, List<RaceEntry>> parseRaceCardHtml(String html) {
    final racePattern = RegExp(r'제\s*(\d+)경주\s*\(출발시간\s*[\d:]+\)');

    // 같은 문구가 제목과 표 caption 에 중복으로 나오므로 경주별 첫 위치만 남긴다.
    final starts = <int, int>{};
    for (final match in racePattern.allMatches(html)) {
      starts.putIfAbsent(int.parse(match.group(1)!), () => match.start);
    }

    final raceNos = starts.keys.toList()
      ..sort((a, b) => starts[a]!.compareTo(starts[b]!));

    final result = <int, List<RaceEntry>>{};
    for (var i = 0; i < raceNos.length; i++) {
      final end = i + 1 < raceNos.length
          ? starts[raceNos[i + 1]]!
          : html.length;
      final entries = _parseRacerRows(html.substring(starts[raceNos[i]]!, end));
      if (entries.isNotEmpty) result[raceNos[i]] = entries;
    }
    return result;
  }

  static final _coursePattern = RegExp(
    r'<span\s+class="sign\s+num\d+">(\d+)</span>',
  );

  static final _namePattern = RegExp(
    r'''fnRacer\.popup\((?:&#39;|')([^'&]+)(?:&#39;|')\s*,\s*(?:&#39;|')[^'&]*(?:&#39;|')\)\s*">\s*([^<]+)</a>''',
  );

  static final _infoPattern = RegExp(
    r'<div\s+class="other">\s*(\d+)기/([\w\d]+)/(\d+)세',
  );

  static final _tdCellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);

  static final _tagStripPattern = RegExp(r'<[^>]+>');

  static final _tbodyPattern = RegExp(
    r'<tbody[^>]*>(.*?)</tbody>',
    dotAll: true,
  );

  /// 확정출주표의 경주 구획에는 표가 두 개 있다.
  /// 첫 표는 선수 기록, 둘째 표는 모터·보트 기록이며 정번(코스)으로 이어 붙인다.
  List<RaceEntry> _parseRacerRows(String section) {
    final bodies = _tbodyPattern.allMatches(section).toList();
    if (bodies.isEmpty) return const [];

    final equipment = bodies.length > 1
        ? _parseEquipmentRows(bodies[1].group(1) ?? '')
        : const <int, _Equipment>{};

    final entries = <RaceEntry>[];
    for (final row in (bodies.first.group(1) ?? '').split(RegExp(r'<tr\b'))) {
      if (row.trim().isEmpty) continue;

      final courseMatch = _coursePattern.firstMatch(row);
      if (courseMatch == null) continue;
      final courseNo = int.parse(courseMatch.group(1)!);

      final nameMatch = _namePattern.firstMatch(row);
      if (nameMatch == null) continue;

      // 선수정보(<th>) 이후의 <td> 셀 순서:
      // [0]체중 [1~6]최근 6회차(평균착순점·평균득점·승률·연대율·삼연대율·평균ST)
      // [7]최근 8경주 착순 [8]연간 평균착순점 [9]연간 연대율 [10]F/L [11]평균사고점
      final cells = _dataCellsAfterHeader(row);
      final gear = equipment[courseNo];

      entries.add(
        RaceEntry(
          courseNo: courseNo,
          racerName: nameMatch.group(2)!.trim(),
          racerId: nameMatch.group(1)!.trim(),
          grade: _infoPattern.firstMatch(row)?.group(2)?.trim() ?? '',
          avgScore: _cellNumber(cells, 2) ?? 0,
          winRate: _cellNumber(cells, 3) ?? 0,
          weight: _cellNumber(cells, 0),
          avgStartTime: _cellNumber(cells, 6),
          // 예측 모델은 최근 6회차가 아니라 연간 누적 지표를 쓴다.
          avgRankPoint: _cellNumber(cells, 8),
          top2Rate: _cellNumber(cells, 9),
          boatNo: gear?.boatNo,
          boatWinRate: gear?.boatTop2Rate,
          boatRankPoint: gear?.boatRankPoint,
          motorNo: gear?.motorNo,
          motorWinRate: gear?.motorTop2Rate,
          motorTop3Rate: gear?.motorTop3Rate,
          motorRankPoint: gear?.motorRankPoint,
        ),
      );
    }

    entries.sort((a, b) => a.courseNo.compareTo(b.courseNo));
    return entries;
  }

  /// 모터·보트 표의 <td> 셀 순서:
  /// [0]출주횟수 [1~6]6개월 코스별 연대율
  /// [7]모터번호 [8]모터 평균착순점 [9]모터 이연대율 [10]모터 삼연대율
  /// [11~12]전 탑승 선수 [13]보트번호 [14]보트 평균착순점 [15]보트 연대율
  Map<int, _Equipment> _parseEquipmentRows(String tbody) {
    final result = <int, _Equipment>{};

    for (final row in tbody.split(RegExp(r'<tr\b'))) {
      final courseMatch = _coursePattern.firstMatch(row);
      if (courseMatch == null) continue;

      final cells = _dataCellsAfterHeader(row);
      if (cells.length < 16) continue;

      result[int.parse(courseMatch.group(1)!)] = _Equipment(
        motorNo: int.tryParse(cells[7]),
        motorRankPoint: _cellNumber(cells, 8),
        motorTop2Rate: _cellNumber(cells, 9),
        motorTop3Rate: _cellNumber(cells, 10),
        boatNo: int.tryParse(cells[13]),
        boatRankPoint: _cellNumber(cells, 14),
        boatTop2Rate: _cellNumber(cells, 15),
      );
    }
    return result;
  }

  List<String> _dataCellsAfterHeader(String row) {
    final headerEnd = row.indexOf('</th>');
    final body = headerEnd >= 0 ? row.substring(headerEnd + 5) : row;
    return _tdCellPattern
        .allMatches(body)
        .map((m) => (m.group(1) ?? '').replaceAll(_tagStripPattern, '').trim())
        .toList();
  }

  /// '22.2%', '4.3', '-' 처럼 섞여 오는 셀에서 숫자만 뽑는다.
  static double? _cellNumber(List<String> cells, int index) {
    if (index >= cells.length) return null;
    return double.tryParse(cells[index].replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  void invalidateResultCache() {
    _resultCache = null;
    _resultCacheDate = null;
  }

  /// 수동 새로고침 시 호출 — 결과/출주표/경주목록 캐시는 비우고,
  /// 연간 날짜 매핑(`_dateMappingCache`)은 보존하여 재요청 비용을 줄임.
  void invalidateForRefresh() {
    _resultCache = null;
    _resultCacheDate = null;
    _cardRaceListCache.clear();
    _entryCache.clear();
  }

  void invalidateCache() {
    _cache.clear();
    _monthDatesCache.clear();
    _dateMappingCache.clear();
    _cardRaceListCache.clear();
    _resultCache = null;
    _resultCacheDate = null;
    _entryCache.clear();
  }
}

/// 확정출주표 둘째 표에서 읽은 정번별 모터·보트 연간 성적.
class _Equipment {
  final int? motorNo;
  final double? motorRankPoint;
  final double? motorTop2Rate;
  final double? motorTop3Rate;
  final int? boatNo;
  final double? boatRankPoint;
  final double? boatTop2Rate;

  const _Equipment({
    required this.motorNo,
    required this.motorRankPoint,
    required this.motorTop2Rate,
    required this.motorTop3Rate,
    required this.boatNo,
    required this.boatRankPoint,
    required this.boatTop2Rate,
  });
}
