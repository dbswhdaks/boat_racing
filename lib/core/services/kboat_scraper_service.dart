import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../../models/race.dart';

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

class KboatScraperService {
  static const _baseUrl = 'https://www.kboat.or.kr/broadcast/racevideo';
  final Dio _dio = dioClient;

  final Map<String, List<KboatVideoInfo>> _cache = {};
  final Map<String, Set<String>> _monthDatesCache = {};

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
        status: '확정',
        departureTime: null,
        racerCount: 6,
      );
    }).toList();
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
  }
}
