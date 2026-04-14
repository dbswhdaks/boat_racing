import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';
import '../../models/race.dart';
import '../../models/race_entry.dart';
import '../../models/race_result.dart';
import '../../models/odds.dart';

class ApiResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  const ApiResult.success(this.data) : errorMessage = null, isSuccess = true;
  const ApiResult.failure(this.errorMessage) : data = null, isSuccess = false;
}

/// ① → 1, ② → 2, ... ⑩ → 10
const _circleNums = '①②③④⑤⑥⑦⑧⑨⑩';

int _circleToInt(String c) {
  final idx = _circleNums.indexOf(c);
  return idx >= 0 ? idx + 1 : 0;
}

/// "①류해광" → (1, "류해광")
(int, String) _parseRankStr(String? raw) {
  if (raw == null || raw.isEmpty) return (0, '');
  final first = raw[0];
  if (_circleNums.contains(first)) {
    return (_circleToInt(first), raw.substring(1).trim());
  }
  return (0, raw.trim());
}

/// "①-②1.9" → 1.9  /  "①1.1" → 1.1  /  "3.4" → 3.4
double? _extractTrailingNum(String? val) {
  if (val == null || val.isEmpty) return null;
  final match = RegExp(r'(\d+\.?\d*)\s*$').firstMatch(val);
  return match != null ? double.tryParse(match.group(1)!) : null;
}

class BoatRacingApiService {
  final Dio _dio = dioClient;

  final Map<String, List<Map<String, dynamic>>> _raceInfoCache = {};
  final Map<String, List<Map<String, dynamic>>> _raceDocCache = {};
  final Map<String, List<Map<String, dynamic>>> _raceResultCache = {};
  final Set<int> _loadedYears = {};

  /// date(yyyyMMdd) → (week_tcnt, day_tcnt)
  final Map<String, (int, int)> _dateToWeekDay = {};

  /// (week_tcnt, day_tcnt) → date(yyyyMMdd)
  final Map<(int, int), String> _weekDayToDate = {};

  Map<String, dynamic> _baseParams({int pageNo = 1, int numOfRows = 1000}) => {
    'serviceKey': ApiConstants.serviceKey,
    'pageNo': pageNo,
    'numOfRows': numOfRows,
    'resultType': 'json',
  };

  // ─── RACE_DOC (출주표 정보 - race_ymd 포함, 핵심 데이터 소스) ───

  Future<List<Map<String, dynamic>>> fetchAllRaceDoc({required int year}) async {
    final key = '$year';
    if (_raceDocCache.containsKey(key)) return _raceDocCache[key]!;

    final items = await _fetchPages(ApiConstants.raceDoc, {'stnd_yr': year.toString()});
    _raceDocCache[key] = items;

    for (final item in items) {
      final ymd = item['race_ymd']?.toString() ?? '';
      final wt = int.tryParse(item['week_tcnt']?.toString() ?? '') ?? 0;
      final dt = int.tryParse(item['day_tcnt']?.toString() ?? '') ?? 0;
      if (ymd.length == 8 && wt > 0 && dt > 0) {
        _dateToWeekDay[ymd] = (wt, dt);
        _weekDayToDate[(wt, dt)] = ymd;
      }
    }

    return items;
  }

  Future<(int, int)?> getWeekDayForDate(String dateYmd) async {
    if (_dateToWeekDay.containsKey(dateYmd)) return _dateToWeekDay[dateYmd];
    final year = int.parse(dateYmd.substring(0, 4));
    await fetchAllRaceDoc(year: year);
    return _dateToWeekDay[dateYmd];
  }

  // ─── RACE_INFO (상세 출주표 - 보조 소스) ───

  Future<List<Map<String, dynamic>>> fetchAllRaceInfo({required int year}) async {
    final key = '$year';
    if (_raceInfoCache.containsKey(key)) return _raceInfoCache[key]!;

    final items = await _fetchPages(ApiConstants.raceInfo, {'stnd_yr': year.toString()});
    _raceInfoCache[key] = items;
    _loadedYears.add(year);
    return items;
  }

  // ─── RACE_RESULT (경주결과 - 연간 전체 로드 후 필터) ───

  Future<List<Map<String, dynamic>>> _fetchAllRaceResult({required int year}) async {
    final key = '$year';
    if (_raceResultCache.containsKey(key)) return _raceResultCache[key]!;

    final items = await _fetchPages(ApiConstants.raceResult, {'stnd_yr': year.toString()});
    _raceResultCache[key] = items;
    return items;
  }

  Future<List<Map<String, dynamic>>> _fetchPages(
    String url,
    Map<String, dynamic> extraParams, {
    int rowsPerPage = 1000,
  }) async {
    final firstParams = {..._baseParams(pageNo: 1, numOfRows: rowsPerPage), ...extraParams};
    final firstRes = await _dio.get(url, queryParameters: firstParams);
    final firstError = _checkApiError(firstRes.data);
    if (firstError != null) return [];

    final totalCount = _extractTotalCount(firstRes.data);
    final firstExtracted = _extractItems(firstRes.data);
    if (firstExtracted.isEmpty) return [];

    final items = <Map<String, dynamic>>[];
    for (final item in firstExtracted) {
      if (item is Map) items.add(Map<String, dynamic>.from(item));
    }

    if (items.length >= totalCount) return items;

    final totalPages = (totalCount / rowsPerPage).ceil().clamp(1, 30);
    if (totalPages <= 1) return items;

    final futures = <Future<Response>>[];
    for (int page = 2; page <= totalPages; page++) {
      final params = {..._baseParams(pageNo: page, numOfRows: rowsPerPage), ...extraParams};
      futures.add(_dio.get(url, queryParameters: params));
    }

    final responses = await Future.wait(futures, eagerError: false);
    for (final res in responses) {
      final error = _checkApiError(res.data);
      if (error != null) continue;
      final extracted = _extractItems(res.data);
      for (final item in extracted) {
        if (item is Map) items.add(Map<String, dynamic>.from(item));
      }
    }

    return items;
  }

  void invalidateCache({int? year}) {
    _payoffPreWarmFuture = null;
    if (year != null) {
      _raceInfoCache.remove('$year');
      _raceDocCache.remove('$year');
      _raceResultCache.remove('$year');
      _payoffCache.remove('$year');
      _loadedYears.remove(year);
    } else {
      _raceInfoCache.clear();
      _raceDocCache.clear();
      _raceResultCache.clear();
      _payoffCache.clear();
      _loadedYears.clear();
      _dateToWeekDay.clear();
      _weekDayToDate.clear();
    }
  }

  // ─── 경주 목록 (RACE_DOC 기반) ───

  Future<ApiResult<List<Race>>> fetchRaceList({required String date}) async {
    try {
      final year = int.parse(date.substring(0, 4));
      final allItems = await fetchAllRaceDoc(year: year);
      final matched = allItems.where((m) {
        final ymd = m['race_ymd']?.toString() ?? '';
        return ymd == date;
      }).toList();

      if (matched.isNotEmpty) {
        return ApiResult.success(_buildRacesFromItems(matched, date));
      }
      return const ApiResult.success([]);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 월별 경기 날짜 (RACE_DOC 기반) ───

  Future<ApiResult<Set<String>>> fetchRaceDatesForMonth({
    required int year,
    required int month,
  }) async {
    try {
      final allItems = await fetchAllRaceDoc(year: year);
      final monthPrefix = '$year${month.toString().padLeft(2, '0')}';
      final dates = <String>{};

      for (final item in allItems) {
        final ymd = item['race_ymd']?.toString() ?? '';
        if (ymd.startsWith(monthPrefix)) {
          dates.add(ymd);
        }
      }
      return ApiResult.success(dates);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 출주표 (RACE_DOC 기반 + RACE_INFO 보조) ───

  Future<ApiResult<List<RaceEntry>>> fetchRaceEntries({
    required String date,
    int? rcNo,
  }) async {
    try {
      final year = int.parse(date.substring(0, 4));

      final allDocItems = await fetchAllRaceDoc(year: year);
      final docMatched = allDocItems.where((m) {
        final ymd = m['race_ymd']?.toString() ?? '';
        if (ymd != date) return false;
        if (rcNo != null) {
          final rn = int.tryParse(m['race_no']?.toString() ?? '');
          return rn == rcNo;
        }
        return true;
      }).toList();

      if (docMatched.length >= 6) {
        return ApiResult.success(_buildEntriesFromItems(docMatched));
      }

      final wd = await getWeekDayForDate(date);
      if (wd != null) {
        final allInfoItems = await fetchAllRaceInfo(year: year);
        final infoMatched = allInfoItems.where((m) {
          final wt = int.tryParse(m['week_tcnt']?.toString() ?? '') ?? 0;
          final dt = int.tryParse(m['day_tcnt']?.toString() ?? '') ?? 0;
          if (wt != wd.$1 || dt != wd.$2) return false;
          if (rcNo != null) {
            final rn = int.tryParse(m['race_no']?.toString() ?? '');
            return rn == rcNo;
          }
          return true;
        }).toList();

        if (infoMatched.length > docMatched.length) {
          return ApiResult.success(_buildEntriesFromItems(infoMatched));
        }
      }

      if (docMatched.isNotEmpty) {
        return ApiResult.success(_buildEntriesFromItems(docMatched));
      }
      return const ApiResult.success([]);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 경주결과 (연간 전체 → week_tcnt/day_tcnt 필터) ───

  Future<ApiResult<List<RaceResult>>> fetchRaceResult({
    required String date,
    int? rcNo,
  }) async {
    try {
      final year = int.parse(date.substring(0, 4));
      final wd = await getWeekDayForDate(date);
      if (wd == null) return const ApiResult.success([]);

      final allItems = await _fetchAllRaceResult(year: year);
      final matched = allItems.where((m) {
        final wt = int.tryParse(m['week_tcnt']?.toString() ?? '') ?? 0;
        final dt = int.tryParse(m['day_tcnt']?.toString() ?? '') ?? 0;
        if (wt != wd.$1 || dt != wd.$2) return false;
        if (rcNo != null) {
          final rn = int.tryParse(m['race_no']?.toString() ?? '');
          return rn == rcNo;
        }
        return true;
      }).toList();

      final results = matched.map((e) => _parseRaceResult(e)).toList();
      return ApiResult.success(results);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 배당률 (연간 전체 → race_ymd + race_no 필터) ───

  final Map<String, List<Map<String, dynamic>>> _payoffCache = {};
  Future<void>? _payoffPreWarmFuture;

  void preWarmPayoffCache({required int year}) {
    final key = '$year';
    if (_payoffCache.containsKey(key)) return;
    _payoffPreWarmFuture ??= _fetchPages(ApiConstants.payoff, {'stnd_yr': key}).then((items) {
      _payoffCache[key] = items;
      _payoffPreWarmFuture = null;
    }).catchError((_) {
      _payoffPreWarmFuture = null;
    });
  }

  Future<ApiResult<Odds>> fetchPayoff({
    required String date,
    required int rcNo,
  }) async {
    try {
      final year = date.substring(0, 4);
      if (!_payoffCache.containsKey(year)) {
        if (_payoffPreWarmFuture != null) {
          await _payoffPreWarmFuture;
        }
        if (!_payoffCache.containsKey(year)) {
          final items = await _fetchPages(ApiConstants.payoff, {'stnd_yr': year});
          _payoffCache[year] = items;
        }
      }
      final allItems = _payoffCache[year]!;

      final matched = allItems.where((m) {
        final ymd = m['race_ymd']?.toString() ?? '';
        final rn = int.tryParse(m['race_no']?.toString() ?? '') ?? 0;
        return ymd == date && rn == rcNo;
      }).toList();

      if (matched.isEmpty) return const ApiResult.failure('배당 데이터 없음');
      return ApiResult.success(_parseOddsFromItem(matched.first));
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 경주순위 (RACE_RANK: race_day 필드로 필터) ───

  Future<ApiResult<List<Map<String, dynamic>>>> fetchRaceRank({
    required String date,
    required int rcNo,
  }) async {
    try {
      final params = {
        ..._baseParams(numOfRows: 200),
        'stnd_year': date.substring(0, 4),
        'race_day': date,
      };
      final res = await _dio.get(ApiConstants.raceRank, queryParameters: params);
      final error = _checkApiError(res.data);
      if (error != null) return ApiResult.failure(error);

      final items = _extractItems(res.data);
      final all = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final matched = all.where((m) {
        final rd = m['race_day']?.toString() ?? '';
        final rn = int.tryParse(m['race_no']?.toString() ?? '') ?? 0;
        return rd == date && rn == rcNo;
      }).toList();

      if (matched.isNotEmpty) {
        for (final m in matched) {
          m['rank'] = m['race_rank'];
          m['course_no'] = m['back_no'] ?? m['race_reg_no'] ?? m['course_no'];
          m['racer_nm'] = m['racer_nm'] ?? '';
          m['race_time'] = m['rcrd_val'] ?? m['race_time'] ?? m['rcrd'] ?? '';
        }
        return ApiResult.success(matched);
      }
      return const ApiResult.success([]);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 선수정보 ───

  Future<ApiResult<Map<String, dynamic>>> fetchRacerInfo({
    required String racerName,
    int? year,
  }) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final params = {
        ..._baseParams(),
        'stnd_yr': targetYear.toString(),
        'racer_nm': racerName,
      };
      final res = await _dio.get(ApiConstants.racerInfo, queryParameters: params);
      final error = _checkApiError(res.data);
      if (error != null && year != null) return ApiResult.failure(error);

      final items = _extractItems(res.data);
      if (items.isNotEmpty) {
        return ApiResult.success(Map<String, dynamic>.from(items.first as Map));
      }

      if (year == null) {
        final prevParams = {
          ..._baseParams(),
          'stnd_yr': (targetYear - 1).toString(),
          'racer_nm': racerName,
        };
        final prevRes = await _dio.get(
          ApiConstants.racerInfo,
          queryParameters: prevParams,
        );
        final prevItems = _extractItems(prevRes.data);
        if (prevItems.isNotEmpty) {
          return ApiResult.success(
            Map<String, dynamic>.from(prevItems.first as Map),
          );
        }
      }

      return const ApiResult.failure('선수 정보 없음');
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 선수 회차별 성적 (컨디션 추이) ───

  Future<ApiResult<List<Map<String, dynamic>>>> fetchRacerTmsInfo({
    required String racerName,
    int? year,
  }) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final params = {
        ..._baseParams(numOfRows: 200),
        'stnd_yr': targetYear.toString(),
        'racer_nm': racerName,
      };
      final res = await _dio.get(ApiConstants.racerTmsInfo, queryParameters: params);
      final error = _checkApiError(res.data);
      if (error != null) return ApiResult.failure(error);
      final items = _extractItems(res.data);
      final result = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return ApiResult.success(result);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 선수 정상출발 정보 ───

  Future<ApiResult<Map<String, dynamic>>> fetchRacerStartInfo({
    required String racerName,
    int? year,
  }) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final params = {
        ..._baseParams(numOfRows: 10),
        'stnd_year': targetYear.toString(),
        'racer_nm': racerName,
      };
      final res = await _dio.get(ApiConstants.racerStrt, queryParameters: params);
      final error = _checkApiError(res.data);
      if (error != null) return ApiResult.failure(error);
      final items = _extractItems(res.data);
      if (items.isNotEmpty) {
        return ApiResult.success(Map<String, dynamic>.from(items.first as Map));
      }
      return const ApiResult.failure('정상출발 정보 없음');
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 코스별 우승전법 ───

  Future<ApiResult<List<Map<String, dynamic>>>> fetchCourseWinStrategy({
    required String racerName,
    int? year,
  }) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final params = {
        ..._baseParams(numOfRows: 200),
        'stnd_year': targetYear.toString(),
        'racer_nm': racerName,
      };
      final res = await _dio.get(ApiConstants.courseWin, queryParameters: params);
      final error = _checkApiError(res.data);
      if (error != null) return ApiResult.failure(error);
      final items = _extractItems(res.data);
      final result = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return ApiResult.success(result);
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('파싱 오류: $e');
    }
  }

  // ─── 연결 테스트 ───

  Future<ApiResult<String>> testConnection() async {
    try {
      final params = {..._baseParams(numOfRows: 1)};
      final res = await _dio.get(ApiConstants.raceInfo, queryParameters: params);
      if (res.statusCode == 200) {
        final error = _checkApiError(res.data);
        if (error != null) return ApiResult.failure(error);
        return const ApiResult.success('연결 성공');
      }
      return ApiResult.failure('HTTP ${res.statusCode}');
    } on DioException catch (e) {
      return ApiResult.failure(_dioErrorMsg(e));
    } catch (e) {
      return ApiResult.failure('$e');
    }
  }

  // ═══ 파싱 헬퍼 ═══

  int _extractTotalCount(dynamic data) {
    if (data is! Map) return 0;
    final body = (data as Map<String, dynamic>)['response']?['body'];
    if (body is Map) return (body['totalCount'] as num?)?.toInt() ?? 0;
    return 0;
  }

  List<Race> _buildRacesFromItems(List<Map<String, dynamic>> items, String dateYmd) {
    final raceMap = <int, _RaceAggregate>{};
    final seenRacers = <String>{};
    for (final m in items) {
      final rn = int.tryParse(m['race_no']?.toString() ?? '') ?? 0;
      if (rn == 0) continue;
      final name = m['racer_nm']?.toString().trim() ?? '';
      final regNo = m['race_reg_no']?.toString() ?? '';
      final key = '${rn}_${regNo}_$name';
      if (seenRacers.contains(key)) continue;
      seenRacers.add(key);

      raceMap.putIfAbsent(rn, () => _RaceAggregate());
      raceMap[rn]!.count++;
      raceMap[rn]!.distance ??= int.tryParse(m['race_dist']?.toString() ?? m['race_len']?.toString() ?? '');
      raceMap[rn]!.departureTime ??= m['dptre_tm']?.toString() ?? m['start_tm']?.toString();
      raceMap[rn]!.status ??= m['organ_stat_cd']?.toString();
    }

    final sorted = raceMap.keys.toList()..sort();
    return sorted.map((no) {
      final agg = raceMap[no]!;
      final rawStatus = agg.status ?? '';
      final status = rawStatus.contains('확정') ? '확정' : '예정';
      return Race(
        venueCode: 1,
        date: dateYmd,
        raceNo: no,
        venueName: '미사리경정공원',
        distance: agg.distance ?? 600,
        status: status,
        departureTime: agg.departureTime,
        racerCount: agg.count,
      );
    }).toList();
  }

  List<RaceEntry> _buildEntriesFromItems(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final entries = <RaceEntry>[];
    for (final m in items) {
      final courseNo = int.tryParse(
        m['course_no']?.toString() ?? m['race_reg_no']?.toString() ?? m['back_no']?.toString() ?? '',
      ) ?? (entries.length + 1);

      final name = m['racer_nm']?.toString().trim() ?? '';
      final key = '${courseNo}_$name';
      if (seen.contains(key)) continue;
      seen.add(key);

      String boatStr = m['boat_no']?.toString() ?? '';
      if (boatStr.startsWith('B')) boatStr = boatStr.replaceFirst(RegExp(r'^B\d*0*'), '');
      String motorStr = m['motor_no']?.toString() ?? '';
      if (motorStr.startsWith('M')) motorStr = motorStr.replaceFirst(RegExp(r'^M\d*0*'), '');

      entries.add(RaceEntry(
        courseNo: courseNo,
        racerName: m['racer_nm']?.toString().trim() ?? '선수$courseNo',
        racerId: m['racer_no']?.toString() ?? m['racer_nm']?.toString().trim() ?? 'R$courseNo',
        grade: m['racer_grd']?.toString() ?? m['racer_grd_cd']?.toString() ?? '',
        avgScore: double.tryParse(
          m['avg_scr']?.toString() ?? m['tot_tms_avg_scr']?.toString() ?? m['tms_6_avg_scr']?.toString() ?? '',
        ) ?? 0,
        recent3Wins: int.tryParse(m['pre_win_cnt']?.toString() ?? m['win_ratio']?.toString() ?? '') ?? 0,
        boatNo: int.tryParse(boatStr),
        motorNo: int.tryParse(motorStr),
        weight: double.tryParse(m['weight']?.toString() ?? m['racer_weight']?.toString() ?? m['wght']?.toString() ?? ''),
      ));
    }
    entries.sort((a, b) => a.courseNo.compareTo(b.courseNo));
    return entries;
  }

  /// "①류해광" 형식과 기존 형식 모두 지원
  RaceResult _parseRaceResult(Map<String, dynamic> m) {
    int firstNo = 0, secondNo = 0, thirdNo = 0;
    String first = '', second = '', third = '';

    final r1 = m['rank1']?.toString();
    final r2 = m['rank2']?.toString();
    final r3 = m['rank3']?.toString();

    if (r1 != null && r1.isNotEmpty && _circleNums.contains(r1[0])) {
      final p = _parseRankStr(r1);
      firstNo = p.$1;
      first = p.$2;
    }
    if (r2 != null && r2.isNotEmpty && _circleNums.contains(r2[0])) {
      final p = _parseRankStr(r2);
      secondNo = p.$1;
      second = p.$2;
    }
    if (r3 != null && r3.isNotEmpty && _circleNums.contains(r3[0])) {
      final p = _parseRankStr(r3);
      thirdNo = p.$1;
      third = p.$2;
    }

    if (first.isEmpty) {
      first = _strFrom(m, ['rank1_nm', 'first_nm']) ?? '';
      firstNo = _intFrom(m, ['rank1_no', 'first_no']) ?? firstNo;
    }
    if (second.isEmpty) {
      second = _strFrom(m, ['rank2_nm', 'second_nm']) ?? '';
      secondNo = _intFrom(m, ['rank2_no', 'second_no']) ?? secondNo;
    }
    if (third.isEmpty) {
      third = _strFrom(m, ['rank3_nm', 'third_nm']) ?? '';
      thirdNo = _intFrom(m, ['rank3_no', 'third_no']) ?? thirdNo;
    }

    return RaceResult(
      raceNo: _intFrom(m, ['race_no', 'rcNo']) ?? 0,
      first: first,
      firstNo: firstNo,
      second: second,
      secondNo: secondNo,
      third: third,
      thirdNo: thirdNo,
      winOdds: _extractTrailingNum(m['pool1_val']?.toString()) ??
          _doubleFrom(m, ['win_rt']) ?? 0,
      placeOdds: _extractTrailingNum(m['pool2_val']?.toString()) ??
          _doubleFrom(m, ['plc_rt']) ?? 0,
      quinellaOdds: _extractTrailingNum(m['pool4_val']?.toString()) ??
          _doubleFrom(m, ['qnl_rt', 'pool3_val']) ?? 0,
    );
  }

  Odds _parseOddsFromItem(Map<String, dynamic> m) {
    final win = <int, double>{};
    final place = <String, double>{};
    final quinella = <String, double>{};
    final trio = <String, double>{};
    final trifecta = <String, double>{};

    final p1 = _doubleFrom(m, ['pool1_val']);
    if (p1 != null) win[0] = p1;

    final p21 = _doubleFrom(m, ['pool2_1_val']);
    final p22 = _doubleFrom(m, ['pool2_2_val']);
    if (p21 != null) place['1위'] = p21;
    if (p22 != null) place['2위'] = p22;

    final p4 = _doubleFrom(m, ['pool4_val']);
    if (p4 != null) quinella['연승'] = p4;

    final p5 = _doubleFrom(m, ['pool5_val']);
    if (p5 != null) trio['쌍승'] = p5;

    final p6 = _doubleFrom(m, ['pool6_val']);
    if (p6 != null) trifecta['삼복승'] = p6;

    return Odds(win: win, place: place, quinella: quinella, trio: trio, trifecta: trifecta);
  }

  String? _checkApiError(dynamic data) {
    if (data is String) {
      if (data.contains('Unexpected errors')) return 'API 키가 유효하지 않거나 서비스 미신청';
      if (data.contains('SERVICE_KEY_IS_NOT_REGISTERED')) return 'API 키가 등록되지 않음';
      return 'API 응답 형식 오류';
    }
    if (data is! Map) return null;
    final map = data as Map<String, dynamic>;
    final header = map['response']?['header'] ?? map['header'] ?? map['cmmMsgHeader'];
    if (header is Map) {
      final code = header['resultCode']?.toString() ?? header['returnReasonCode']?.toString();
      final msg = header['resultMsg'] ?? header['returnAuthMsg'] ?? header['errMsg'];
      if (code != null && code != '00' && code != '0') {
        return _mapErrorCode(code, msg?.toString() ?? '');
      }
    }
    return null;
  }

  String _mapErrorCode(String code, String msg) {
    return switch (code) {
      '01' => '어플리케이션 에러: $msg',
      '02' => 'DB 에러: $msg',
      '03' => '데이터 없음',
      '04' => 'HTTP 에러: $msg',
      '10' => '잘못된 요청 파라미터: $msg',
      '20' => 'API 키 미등록',
      '22' => 'API 트래픽 초과',
      '30' => '등록되지 않은 API 키',
      _ => '[$code] $msg',
    };
  }

  String _dioErrorMsg(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout => '연결 시간 초과',
      DioExceptionType.receiveTimeout => '응답 시간 초과',
      DioExceptionType.connectionError => '네트워크 연결 실패',
      DioExceptionType.badResponse => 'HTTP ${e.response?.statusCode}',
      _ => '네트워크 오류: ${e.message}',
    };
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data == null || data is! Map) return [];
    final map = data as Map<String, dynamic>;
    Map<String, dynamic>? body;
    if (map['response']?['body'] != null) {
      body = Map<String, dynamic>.from(map['response']['body'] as Map);
    } else if (map['body'] != null) {
      body = Map<String, dynamic>.from(map['body'] as Map);
    }
    if (body == null) return [];
    final items = body['items'];
    if (items == null) return [];
    if (items is List) return items;
    if (items is Map) {
      final item = items['item'];
      if (item is List) return item;
      if (item != null) return [item];
    }
    return [];
  }

  int? _intFrom(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  double? _doubleFrom(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }

  String? _strFrom(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is String && v.isNotEmpty) return v;
      return v.toString();
    }
    return null;
  }
}

class _RaceAggregate {
  int count = 0;
  int? distance;
  String? departureTime;
  String? status;
}
