import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/boat_racing_api_service.dart';
import '../../../core/services/kboat_scraper_service.dart';
import '../../../core/services/prediction_engine.dart';
import '../../../core/services/supabase_backup_service.dart';
import '../../../models/race.dart';
import '../../../models/race_entry.dart';
import '../../../models/race_result.dart';
import '../../../models/odds.dart';
import '../../../models/prediction.dart';
import '../../../models/racer_detail.dart';

final boatRacingApiProvider = Provider<BoatRacingApiService>((ref) {
  return BoatRacingApiService();
});

final supabaseBackupProvider = Provider<SupabaseBackupService>((ref) {
  return SupabaseBackupService();
});

final kboatScraperProvider = Provider<KboatScraperService>((ref) {
  return KboatScraperService();
});

final selectedRacerEntryProvider = StateProvider<RaceEntry?>((ref) => null);

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class DataWithSource<T> {
  final T data;
  final bool fromApi;
  final String? apiError;
  const DataWithSource({required this.data, this.fromApi = false, this.apiError});
}

String dateToYmd(DateTime d) {
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

String get todayYmd => dateToYmd(DateTime.now());


/// API 연결 상태
final apiStatusProvider = FutureProvider<ApiResult<String>>((ref) async {
  final api = ref.watch(boatRacingApiProvider);
  return api.testConnection();
});

/// 월별 경기 날짜
final monthRaceDatesProvider = FutureProvider.family<
    Set<String>,
    ({int year, int month})>((ref, params) async {
  final link = ref.keepAlive();
  final api = ref.watch(boatRacingApiProvider);
  final backup = ref.watch(supabaseBackupProvider);
  final kboat = ref.watch(kboatScraperProvider);

  final dates = <String>{};

  final result = await api.fetchRaceDatesForMonth(year: params.year, month: params.month);
  if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
    dates.addAll(result.data!);
  }

  try {
    final kboatDates = await kboat.fetchRaceDatesForMonth(
      year: params.year,
      month: params.month,
    );
    if (kboatDates.isNotEmpty) {
      dates.addAll(kboatDates);
      if (kDebugMode) debugPrint('[Provider] monthRaceDates: KBOAT ${kboatDates.length}일 병합');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Provider] monthRaceDates KBOAT 실패: $e');
  }

  if (dates.isNotEmpty) return dates;

  final cached = await backup.loadRaceDatesForMonth(
    year: params.year,
    month: params.month,
  );
  if (cached.isNotEmpty) {
    if (kDebugMode) debugPrint('[Provider] monthRaceDates: Supabase 캐시 ${cached.length}일');
    return cached;
  }

  link.close();
  return {};
});

/// 경주 목록
final raceListProvider =
    FutureProvider.family<DataWithSource<List<Race>>, ({String date})>(
        (ref, params) async {
  final link = ref.keepAlive();
  final api = ref.watch(boatRacingApiProvider);
  final backup = ref.watch(supabaseBackupProvider);
  final kboat = ref.watch(kboatScraperProvider);

  final result = await api.fetchRaceList(date: params.date);

  if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
    if (kDebugMode) debugPrint('[Provider] raceList(${params.date}): API ${result.data!.length}건');
    backup.saveRaces(result.data!);
    api.preWarmPayoffCache(year: int.parse(params.date.substring(0, 4)));
    return DataWithSource(data: result.data!, fromApi: true);
  }

  final cached = await backup.loadRaces(date: params.date);
  if (cached.isNotEmpty) {
    if (kDebugMode) debugPrint('[Provider] raceList(${params.date}): Supabase 캐시 ${cached.length}건');
    return DataWithSource(data: cached, fromApi: false, apiError: result.errorMessage);
  }

  try {
    final kboatRaces = await kboat.fetchRaceList(date: params.date);
    if (kboatRaces.isNotEmpty) {
      if (kDebugMode) debugPrint('[Provider] raceList(${params.date}): KBOAT ${kboatRaces.length}건');
      backup.saveRaces(kboatRaces);
      return DataWithSource(data: kboatRaces, fromApi: false, apiError: 'KBOAT 영상 기반');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Provider] raceList KBOAT 실패: $e');
  }

  link.close();
  if (kDebugMode) debugPrint('[Provider] raceList(${params.date}): 데이터 없음 → keepAlive 해제');
  return DataWithSource(
    data: [],
    fromApi: true,
    apiError: result.errorMessage,
  );
});

/// 출주표
final raceEntriesProvider = FutureProvider.family<DataWithSource<List<RaceEntry>>,
    ({String date, int raceNo})>((ref, params) async {
  ref.keepAlive();
  final api = ref.watch(boatRacingApiProvider);
  final backup = ref.watch(supabaseBackupProvider);

  final result = await api.fetchRaceEntries(date: params.date, rcNo: params.raceNo);
  if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
    if (kDebugMode) debugPrint('[Provider] entries(${params.date}, R${params.raceNo}): ${result.data!.length}명');
    backup.saveEntries(date: params.date, raceNo: params.raceNo, entries: result.data!);
    return DataWithSource(data: result.data!, fromApi: true);
  }

  final cached = await backup.loadEntries(date: params.date, raceNo: params.raceNo);
  if (cached.isNotEmpty) {
    if (kDebugMode) debugPrint('[Provider] entries(${params.date}, R${params.raceNo}): Supabase 캐시 ${cached.length}명');
    return DataWithSource(data: cached, fromApi: false, apiError: result.errorMessage);
  }

  return DataWithSource(
    data: <RaceEntry>[],
    fromApi: true,
    apiError: result.errorMessage,
  );
});

/// 배당률
final oddsProvider = FutureProvider.family<Odds, ({String date, int raceNo})>(
    (ref, params) async {
  ref.keepAlive();
  final api = ref.watch(boatRacingApiProvider);
  final result = await api.fetchPayoff(date: params.date, rcNo: params.raceNo);
  if (result.isSuccess && result.data != null) return result.data!;
  return const Odds();
});

/// 경주 결과
final raceResultProvider = FutureProvider.family<RaceResult,
    ({String date, int raceNo})>((ref, params) async {
  final api = ref.watch(boatRacingApiProvider);
  final kboat = ref.watch(kboatScraperProvider);

  // KBOAT 우선 (정확한 착순 + 배당률 7종 제공)
  if (params.date == todayYmd) {
    try {
      final bundle = await kboat.fetchTodayResults();
      if (bundle != null && bundle.results.containsKey(params.raceNo)) {
        if (kDebugMode) {
          debugPrint('[Provider] raceResult(R${params.raceNo}): KBOAT 사용');
        }
        return bundle.results[params.raceNo]!;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Provider] raceResult KBOAT 실패: $e');
    }
  }

  // 공공 API fallback
  final result = await api.fetchRaceResult(date: params.date, rcNo: params.raceNo);
  if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
    return result.data!.first;
  }

  throw Exception('NOT_YET');
});

/// 경주 순위
final raceRankProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String date, int raceNo})>((ref, params) async {
  final api = ref.watch(boatRacingApiProvider);
  final kboat = ref.watch(kboatScraperProvider);

  List<Map<String, dynamic>> top3 = [];

  // KBOAT 착순 (1~3위)
  if (params.date == todayYmd) {
    try {
      final bundle = await kboat.fetchTodayResults();
      if (bundle != null && bundle.ranks.containsKey(params.raceNo)) {
        top3 = bundle.ranks[params.raceNo]!;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Provider] raceRank KBOAT 실패: $e');
    }
  }

  // 공공 API (race_rank 필드가 있으면 그대로 사용)
  if (top3.isEmpty) {
    final result = await api.fetchRaceRank(date: params.date, rcNo: params.raceNo);
    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      final hasRank = result.data!.any((m) =>
          m['race_rank'] != null || m['rank'] != null);
      if (hasRank) return result.data!;
    }
  }

  if (top3.isEmpty) throw Exception('NOT_YET');

  // 출주표에서 나머지 선수 보충 → 전체 착순 표시
  try {
    final entriesResult = await ref.watch(raceEntriesProvider((
      date: params.date, raceNo: params.raceNo,
    )).future);
    final entries = entriesResult.data;
    if (entries.isNotEmpty) {
      final rankedCourses = top3.map((r) => r['course_no'] as int).toSet();
      final remaining = entries
          .where((e) => !rankedCourses.contains(e.courseNo))
          .toList()
        ..sort((a, b) => a.courseNo.compareTo(b.courseNo));

      int nextRank = top3.length + 1;
      for (final e in remaining) {
        top3.add({
          'rank': nextRank,
          'race_rank': nextRank,
          'course_no': e.courseNo,
          'racer_nm': e.racerName,
        });
        nextRank++;
      }
    }
  } catch (_) {}

  if (kDebugMode) {
    debugPrint('[Provider] raceRank(R${params.raceNo}): ${top3.length}명 (KBOAT+출주표)');
  }
  return top3;
});

/// AI 예측
final predictionProvider = FutureProvider.family<RacePrediction,
    ({String date, int raceNo})>((ref, params) async {
  final backup = ref.watch(supabaseBackupProvider);
  final entriesResult = await ref.watch(raceEntriesProvider((
    date: params.date, raceNo: params.raceNo,
  )).future);

  final prediction = PredictionEngine.predict(entriesResult.data);
  backup.savePrediction(
    date: params.date,
    raceNo: params.raceNo,
    prediction: prediction,
  );
  return prediction;
});

/// 선수 상세
final racerDetailProvider =
    FutureProvider.family<RacerDetail, ({RaceEntry entry})>(
        (ref, params) async {
  final api = ref.watch(boatRacingApiProvider);
  final result = await api.fetchRacerInfo(racerName: params.entry.racerName);
  if (result.isSuccess && result.data != null) {
    if (kDebugMode) {
      debugPrint('[Provider] racerDetail(${params.entry.racerName}): API 성공');
    }
    return RacerDetail.fromApiMap(result.data!, entry: params.entry);
  }
  if (kDebugMode) {
    debugPrint(
      '[Provider] racerDetail(${params.entry.racerName}): 목업 (${result.errorMessage})',
    );
  }
  return RacerDetail.fromRaceEntryDetailed(params.entry);
});

/// 선수 상세 (ID 기반)
final racerDetailByIdProvider =
    FutureProvider.family<RacerDetail, ({String racerId})>(
        (ref, params) async {
  final api = ref.watch(boatRacingApiProvider);
  final result = await api.fetchRacerInfo(racerName: params.racerId);
  if (result.isSuccess && result.data != null) {
    if (kDebugMode) {
      debugPrint('[Provider] racerDetailById(${params.racerId}): API 성공');
    }
    return RacerDetail.fromApiMap(result.data!);
  }
  return RacerDetail(
    racerId: params.racerId,
    racerName: params.racerId,
    grade: '-',
    avgScore: 0,
  );
});
