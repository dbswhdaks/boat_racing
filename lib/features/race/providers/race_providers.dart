import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/iap_constants.dart';
import '../../../core/services/boat_racing_api_service.dart';
import '../../../core/services/kboat_scraper_service.dart';
import '../../../core/services/prediction_engine.dart';
import '../../../core/services/supabase_backup_service.dart';
import '../../../features/subscription/providers/in_app_purchase_provider.dart';
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

/// 구독 활성 여부 — Google Play 인앱결제 보유 productId 중 하나가
/// [IapConstants.subscriptionProductIds]에 포함되면 잠금 해제.
final isSubscribedProvider = Provider<bool>((ref) {
  final iapState = ref.watch(inAppPurchaseProvider);
  return iapState.purchasedProductIds.any(
    IapConstants.subscriptionProductIds.contains,
  );
});

class DataWithSource<T> {
  final T data;
  final bool fromApi;
  final String? apiError;
  const DataWithSource({
    required this.data,
    this.fromApi = false,
    this.apiError,
  });
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
final monthRaceDatesProvider =
    FutureProvider.family<Set<String>, ({int year, int month})>((
      ref,
      params,
    ) async {
      final link = ref.keepAlive();
      final api = ref.watch(boatRacingApiProvider);
      final backup = ref.watch(supabaseBackupProvider);
      final kboat = ref.watch(kboatScraperProvider);

      final dates = <String>{};
      final monthPrefix =
          '${params.year}${params.month.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        api.fetchRaceDatesForMonth(year: params.year, month: params.month),
        kboat
            .fetchRaceDatesForMonth(year: params.year, month: params.month)
            .catchError((_) => <String>{}),
        kboat
            .fetchDateMappings(year: params.year)
            .catchError((_) => <String, (int, int)>{}),
      ]);

      final apiResult = results[0] as ApiResult<Set<String>>;
      final kboatDates = results[1] as Set<String>;
      final kboatMappings = results[2] as Map<String, (int, int)>;

      if (apiResult.isSuccess && apiResult.data != null) {
        dates.addAll(apiResult.data!);
      }
      if (kboatDates.isNotEmpty) {
        dates.addAll(kboatDates);
      }
      for (final ymd in kboatMappings.keys) {
        if (ymd.startsWith(monthPrefix)) dates.add(ymd);
      }

      if (dates.isNotEmpty) return dates;

      final cached = await backup.loadRaceDatesForMonth(
        year: params.year,
        month: params.month,
      );
      if (cached.isNotEmpty) return cached;

      link.close();
      return {};
    });

/// 경주 목록
final raceListProvider =
    FutureProvider.family<DataWithSource<List<Race>>, ({String date})>((
      ref,
      params,
    ) async {
      final link = ref.keepAlive();
      final api = ref.watch(boatRacingApiProvider);
      final backup = ref.watch(supabaseBackupProvider);
      final kboat = ref.watch(kboatScraperProvider);

      final apiResult = await api.fetchRaceList(date: params.date);

      if (apiResult.isSuccess &&
          apiResult.data != null &&
          apiResult.data!.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] raceList(${params.date}): API ${apiResult.data!.length}건',
          );
        }
        backup.saveRaces(apiResult.data!);
        api.preWarmPayoffCache(year: int.parse(params.date.substring(0, 4)));
        return DataWithSource(data: apiResult.data!, fromApi: true);
      }

      final kboatRaces = await kboat
          .fetchRaceList(date: params.date)
          .catchError((_) => <Race>[]);

      if (kboatRaces.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] raceList(${params.date}): KBOAT ${kboatRaces.length}건',
          );
        }
        backup.saveRaces(kboatRaces);
        return DataWithSource(
          data: kboatRaces,
          fromApi: false,
          apiError: 'KBOAT 영상 기반',
        );
      }

      final cached = await backup.loadRaces(date: params.date);
      if (cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] raceList(${params.date}): Supabase 캐시 ${cached.length}건',
          );
        }
        return DataWithSource(
          data: cached,
          fromApi: false,
          apiError: apiResult.errorMessage,
        );
      }

      link.close();
      return DataWithSource(
        data: [],
        fromApi: true,
        apiError: apiResult.errorMessage,
      );
    });

/// 출주표
final raceEntriesProvider =
    FutureProvider.family<
      DataWithSource<List<RaceEntry>>,
      ({String date, int raceNo})
    >((ref, params) async {
      ref.keepAlive();
      final api = ref.watch(boatRacingApiProvider);
      final backup = ref.watch(supabaseBackupProvider);
      final kboat = ref.watch(kboatScraperProvider);

      final result = await api.fetchRaceEntries(
        date: params.date,
        rcNo: params.raceNo,
      );
      final apiEntries = result.isSuccess
          ? (result.data ?? <RaceEntry>[])
          : <RaceEntry>[];

      if (apiEntries.length >= 6) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] entries(${params.date}, R${params.raceNo}): ${apiEntries.length}명',
          );
        }
        backup.saveEntries(
          date: params.date,
          raceNo: params.raceNo,
          entries: apiEntries,
        );
        return DataWithSource(data: apiEntries, fromApi: true);
      }

      if (apiEntries.length < 6) {
        try {
          final wd = await _resolveWeekDay(api, kboat, params.date);
          if (wd != null) {
            final kboatEntries = await kboat.fetchRaceEntries(
              weekTcnt: wd.$1,
              dayTcnt: wd.$2,
              raceNo: params.raceNo,
            );
            if (kboatEntries.length > apiEntries.length) {
              if (kDebugMode) {
                debugPrint(
                  '[Provider] entries(${params.date}, R${params.raceNo}): KBOAT ${kboatEntries.length}명',
                );
              }
              backup.saveEntries(
                date: params.date,
                raceNo: params.raceNo,
                entries: kboatEntries,
              );
              return DataWithSource(
                data: kboatEntries,
                fromApi: false,
                apiError: 'KBOAT 웹 기반',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Provider] KBOAT 출주표 실패: $e');
        }
      }

      if (apiEntries.isNotEmpty) {
        backup.saveEntries(
          date: params.date,
          raceNo: params.raceNo,
          entries: apiEntries,
        );
        return DataWithSource(data: apiEntries, fromApi: true);
      }

      final cached = await backup.loadEntries(
        date: params.date,
        raceNo: params.raceNo,
      );
      if (cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] entries(${params.date}, R${params.raceNo}): Supabase 캐시 ${cached.length}명',
          );
        }
        return DataWithSource(
          data: cached,
          fromApi: false,
          apiError: result.errorMessage,
        );
      }

      return DataWithSource(
        data: <RaceEntry>[],
        fromApi: true,
        apiError: result.errorMessage,
      );
    });

/// 배당률
final oddsProvider = FutureProvider.family<Odds, ({String date, int raceNo})>((
  ref,
  params,
) async {
  final api = ref.watch(boatRacingApiProvider);
  final kboat = ref.watch(kboatScraperProvider);
  final kboatOdds = await kboat.fetchFinalOdds(
    date: params.date,
    raceNo: params.raceNo,
  );
  if (!kboatOdds.isEmpty) return kboatOdds;

  final result = await api.fetchPayoff(date: params.date, rcNo: params.raceNo);
  if (result.isSuccess && result.data != null) return result.data!;
  return const Odds();
});

/// 날짜 → (회차, 일차) 변환. 공공 API 의 RACE_DOC 은 경주 당일 이후에 갱신되므로,
/// 매핑이 아직 없으면 KBOAT 확정출주표 페이지의 연간 매핑으로 보완한다.
Future<(int, int)?> _resolveWeekDay(
  BoatRacingApiService api,
  KboatScraperService kboat,
  String date,
) async {
  try {
    final fromApi = await api.getWeekDayForDate(date);
    if (fromApi != null) return fromApi;
  } catch (e) {
    if (kDebugMode) debugPrint('[Provider] 공공 API 회차 매핑 실패: $e');
  }

  try {
    return await kboat.getWeekDayForDate(date);
  } catch (e) {
    if (kDebugMode) debugPrint('[Provider] KBOAT 회차 매핑 실패: $e');
    return null;
  }
}

/// 경주 결과
final raceResultProvider =
    FutureProvider.family<RaceResult, ({String date, int raceNo})>((
      ref,
      params,
    ) async {
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
      final result = await api.fetchRaceResult(
        date: params.date,
        rcNo: params.raceNo,
        weekDay: await _resolveWeekDay(api, kboat, params.date),
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        return result.data!.first;
      }

      throw Exception('NOT_YET');
    });

/// 경주 순위
final raceRankProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String date, int raceNo})
    >((ref, params) async {
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
        final result = await api.fetchRaceRank(
          date: params.date,
          rcNo: params.raceNo,
        );
        if (result.isSuccess &&
            result.data != null &&
            result.data!.isNotEmpty) {
          final hasRank = result.data!.any(
            (m) => m['race_rank'] != null || m['rank'] != null,
          );
          if (hasRank) return result.data!;
        }
      }

      if (top3.isEmpty) throw Exception('NOT_YET');

      // 출주표에서 나머지 선수 보충 → 전체 착순 표시
      try {
        final entriesResult = await ref.watch(
          raceEntriesProvider((
            date: params.date,
            raceNo: params.raceNo,
          )).future,
        );
        final entries = entriesResult.data;
        if (entries.isNotEmpty) {
          final rankedCourses = top3.map((r) => r['course_no'] as int).toSet();
          final remaining =
              entries.where((e) => !rankedCourses.contains(e.courseNo)).toList()
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
        debugPrint(
          '[Provider] raceRank(R${params.raceNo}): ${top3.length}명 (KBOAT+출주표)',
        );
      }
      return top3;
    });

/// AI 예측
final predictionProvider =
    FutureProvider.family<RacePrediction, ({String date, int raceNo})>((
      ref,
      params,
    ) async {
      ref.keepAlive();
      final backup = ref.watch(supabaseBackupProvider);
      final api = ref.watch(boatRacingApiProvider);
      final currentSnapshot = await backup.loadPrediction(
        date: params.date,
        raceNo: params.raceNo,
        modelVersion: PredictionEngine.modelVersion,
      );
      if (currentSnapshot != null) return currentSnapshot;

      final legacySnapshot = await backup.loadPrediction(
        date: params.date,
        raceNo: params.raceNo,
      );
      if (_isPredictionLocked(params.date, params.raceNo) &&
          legacySnapshot != null) {
        return legacySnapshot;
      }

      final predictionYear =
          int.tryParse(params.date.substring(0, 4)) ?? DateTime.now().year;
      final results = await Future.wait([
        ref.watch(
          raceEntriesProvider((
            date: params.date,
            raceNo: params.raceNo,
          )).future,
        ),
        api.fetchBoatWinRates(year: predictionYear),
        api.fetchMotorWinRates(year: predictionYear),
        backup.loadRaceConditions(date: params.date, raceNo: params.raceNo),
      ]);

      final entriesResult = results[0] as DataWithSource<List<RaceEntry>>;
      final boatWinRates = results[1] as Map<int, double>;
      final motorWinRates = results[2] as Map<int, double>;
      final conditions = results[3] as RaceConditions?;
      final enrichedEntries = await _enrichPredictionEntries(
        api,
        entriesResult.data,
        params.date,
        boatWinRates: boatWinRates,
        motorWinRates: motorWinRates,
      );
      backup.saveEntries(
        date: params.date,
        raceNo: params.raceNo,
        entries: enrichedEntries,
      );
      final prediction = PredictionEngine.predict(
        enrichedEntries,
        conditions: conditions,
      );
      await backup.savePrediction(
        date: params.date,
        raceNo: params.raceNo,
        prediction: prediction,
      );
      return prediction;
    });

Future<List<RaceEntry>> _enrichPredictionEntries(
  BoatRacingApiService api,
  List<RaceEntry> entries,
  String date, {
  required Map<int, double> boatWinRates,
  required Map<int, double> motorWinRates,
}) async {
  final year = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
  return Future.wait(
    entries.map((entry) async {
      // 출주표에서 이미 읽은 장비 성적이 있으면 그대로 두고, 없을 때만 연간 집계로 채운다.
      final equippedEntry = entry.copyWith(
        boatWinRate:
            entry.boatWinRate ??
            (entry.boatNo == null ? null : boatWinRates[entry.boatNo]),
        motorWinRate:
            entry.motorWinRate ??
            (entry.motorNo == null ? null : motorWinRates[entry.motorNo]),
      );
      try {
        final result = await api.fetchRacerInfo(
          racerName: entry.racerName,
          year: year,
        );
        if (!result.isSuccess || result.data == null) return equippedEntry;
        final detail = RacerDetail.fromApiMap(
          result.data!,
          entry: equippedEntry,
        );
        // 선수정보 API 는 출주표(정수로 잘려 나옴)보다 정밀한 연간 지표를 준다.
        return equippedEntry.copyWith(
          avgScore: detail.avgScore > 0 ? detail.avgScore : null,
          winRate: (detail.winRatio ?? detail.winRate) > 0
              ? detail.winRatio ?? detail.winRate
              : null,
          avgStartTime: detail.avgStartTime,
          avgRankPoint: (detail.yearAvgRank ?? 0) > 0
              ? detail.yearAvgRank
              : null,
          top2Rate: (detail.consecutiveWinRate ?? 0) > 0
              ? detail.consecutiveWinRate
              : null,
        );
      } catch (_) {
        return equippedEntry;
      }
    }),
  );
}

bool _isPredictionLocked(String date, int raceNo) {
  if (date.length != 8) return false;
  final year = int.tryParse(date.substring(0, 4));
  final month = int.tryParse(date.substring(4, 6));
  final day = int.tryParse(date.substring(6, 8));
  if (year == null || month == null || day == null) return false;
  final departure = Race.defaultDepartureTimes[raceNo];
  if (departure == null) return false;
  final parts = departure.split(':');
  if (parts.length != 2) return false;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return false;
  return DateTime.now().isAfter(DateTime(year, month, day, hour, minute));
}

final predictionEvaluationProvider =
    FutureProvider.family<PredictionEvaluation, ({String date, int raceNo})>((
      ref,
      params,
    ) async {
      final backup = ref.watch(supabaseBackupProvider);
      final values = await Future.wait([
        ref.watch(predictionProvider(params).future),
        ref.watch(raceResultProvider(params).future),
      ]);
      final prediction = values[0] as RacePrediction;
      final result = values[1] as RaceResult;
      final evaluation = PredictionEngine.evaluate(prediction, result);
      await backup.savePredictionEvaluation(
        date: params.date,
        raceNo: params.raceNo,
        prediction: prediction,
        evaluation: evaluation,
      );
      ref.invalidate(predictionStatsProvider);
      return evaluation;
    });

final predictionStatsProvider = FutureProvider<PredictionStats>((ref) {
  return ref.watch(supabaseBackupProvider).loadPredictionStats();
});

Future<RacerDetail> _enrichRacerDetail(
  BoatRacingApiService api,
  RacerDetail base,
) async {
  final name = base.racerName;
  final futures = await Future.wait([
    api.fetchRacerTmsInfo(racerName: name),
    api.fetchRacerStartInfo(racerName: name),
    api.fetchCourseWinStrategy(racerName: name),
  ]);

  final tmsResult = futures[0] as ApiResult<List<Map<String, dynamic>>>;
  final strtResult = futures[1] as ApiResult<Map<String, dynamic>>;
  final cwResult = futures[2] as ApiResult<List<Map<String, dynamic>>>;

  List<RacerTmsRecord> tmsRecords = [];
  if (tmsResult.isSuccess && tmsResult.data != null) {
    tmsRecords = tmsResult.data!.map((m) => RacerTmsRecord.fromMap(m)).toList()
      ..sort((a, b) => a.weekTcnt.compareTo(b.weekTcnt));
  }

  int? normalStart, totalStart, violationCnt, elimCnt;
  String? lastViol;
  if (strtResult.isSuccess && strtResult.data != null) {
    final s = strtResult.data!;
    normalStart = parseIntVal(s['norm_strt_cnt']);
    final afNorm = parseIntVal(s['af_norm_strt_cnt']) ?? 0;
    violationCnt = parseIntVal(s['rect_voil_cnt']) ?? 0;
    elimCnt = parseIntVal(s['elim_cnt']) ?? 0;
    totalStart = (normalStart ?? 0) + violationCnt + elimCnt;
    if (afNorm > 0 && afNorm < (normalStart ?? 0)) {
      totalStart = normalStart;
      normalStart = afNorm;
    }
    lastViol = s['rect_voil']?.toString();
  }

  List<CourseStrategy> strategies = [];
  if (cwResult.isSuccess && cwResult.data != null) {
    for (final m in cwResult.data!) {
      final cnt = parseIntVal(m['cnt']) ?? 0;
      if (cnt <= 0) continue;
      strategies.add(
        CourseStrategy(
          course: m['entry_course']?.toString() ?? '',
          strategy: m['strategy_cd']?.toString() ?? '',
          count: cnt,
          rate: parseDoubleVal(m['rate']) ?? 0,
        ),
      );
    }
    strategies.sort((a, b) => b.count.compareTo(a.count));
  }

  return base.copyWith(
    normalStartCount: normalStart,
    totalStartCount: totalStart,
    violationCount: violationCnt,
    eliminationCount: elimCnt,
    lastViolation: lastViol,
    tmsRecords: tmsRecords,
    courseStrategies: strategies,
  );
}

/// 선수 상세
final racerDetailProvider =
    FutureProvider.family<RacerDetail, ({RaceEntry entry})>((
      ref,
      params,
    ) async {
      final api = ref.watch(boatRacingApiProvider);
      final result = await api.fetchRacerInfo(
        racerName: params.entry.racerName,
      );
      RacerDetail base;
      if (result.isSuccess && result.data != null) {
        if (kDebugMode) {
          debugPrint(
            '[Provider] racerDetail(${params.entry.racerName}): API 성공',
          );
        }
        base = RacerDetail.fromApiMap(result.data!, entry: params.entry);
      } else {
        if (kDebugMode) {
          debugPrint(
            '[Provider] racerDetail(${params.entry.racerName}): 목업 (${result.errorMessage})',
          );
        }
        return RacerDetail.fromRaceEntryDetailed(params.entry);
      }
      return _enrichRacerDetail(api, base);
    });

/// 선수 상세 (ID 기반)
final racerDetailByIdProvider =
    FutureProvider.family<RacerDetail, ({String racerId})>((ref, params) async {
      final api = ref.watch(boatRacingApiProvider);
      final result = await api.fetchRacerInfo(racerName: params.racerId);
      if (result.isSuccess && result.data != null) {
        if (kDebugMode) {
          debugPrint('[Provider] racerDetailById(${params.racerId}): API 성공');
        }
        final base = RacerDetail.fromApiMap(result.data!);
        return _enrichRacerDetail(api, base);
      }
      return RacerDetail(
        racerId: params.racerId,
        racerName: params.racerId,
        grade: '-',
        avgScore: 0,
      );
    });
