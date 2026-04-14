import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../../models/race.dart';
import '../../models/race_result.dart';

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
  final Dio _dio = dioClient;

  final Map<String, List<KboatVideoInfo>> _cache = {};
  final Map<String, Set<String>> _monthDatesCache = {};
  KboatRaceResultBundle? _resultCache;
  String? _resultCacheDate;

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
          options: Options(headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          }),
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

          results.add(KboatVideoInfo(
            dateYmd: dateYmd,
            raceNo: raceNo,
            weekTcnt: weekTcnt,
            dayTcnt: dayTcnt,
          ));
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
          options: Options(headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'text/html',
          }),
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
  Future<List<Race>> fetchRaceList({required String date}) async {
    final year = date.substring(0, 4);
    final mm = date.substring(4, 6);

    final videos = await fetchVideos(startDate: date, endDate: date);

    final filtered = videos.where((v) => v.dateYmd == date).toList();
    if (filtered.isEmpty) {
      final all = await fetchVideos(
        startDate: '$year${mm}01',
        endDate: '$year$mm${DateTime(int.parse(year), int.parse(mm) + 1, 0).day}',
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

  /// KBOAT 메인페이지 경주결과 API (당일 결과만 제공)
  Future<KboatRaceResultBundle?> fetchTodayResults() async {
    final now = DateTime.now();
    final todayYmd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    if (_resultCacheDate == todayYmd && _resultCache != null) {
      return _resultCache;
    }

    try {
      final res = await _dio.get(
        _resultUrl,
        options: Options(headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json',
        }),
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

        double _odds(String key) =>
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
          winOdds: _odds('win'),
          placeOdds: placeOdds,
          quinellaOdds: _odds('quinella'),
          exactaOdds: _odds('exacta'),
          triellaOdds: _odds('triella'),
          xlaOdds: _odds('xla'),
          trxOdds: _odds('trx'),
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

  void invalidateCache() {
    _cache.clear();
    _monthDatesCache.clear();
    _resultCache = null;
    _resultCacheDate = null;
  }
}
