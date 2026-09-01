import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/race.dart';
import '../../models/race_entry.dart';
import '../../models/prediction.dart';
import 'prediction_engine.dart';

class SupabaseBackupService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── 경주 목록 ───

  Future<void> saveRaces(List<Race> races) async {
    if (races.isEmpty) return;
    try {
      final rows = races
          .map(
            (r) => {
              'meet': r.venueCode.toString(),
              'race_date': r.date,
              'race_no': r.raceNo,
              'venue_name': r.venueName,
              'distance': r.distance,
              'status': r.status,
              'departure_time': r.departureTime,
              'racer_count': r.racerCount,
            },
          )
          .toList();
      await _client
          .from('boat_races')
          .upsert(rows, onConflict: 'meet,race_date,race_no');
      if (kDebugMode) debugPrint('[Supabase] boat_races ${rows.length}건 저장');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_races 저장 실패: $e');
    }
  }

  Future<Set<String>> loadRaceDatesForMonth({
    required int year,
    required int month,
  }) async {
    try {
      final mm = month.toString().padLeft(2, '0');
      final startDate = '$year${mm}01';
      final endDate = '$year${mm}31';
      final res = await _client
          .from('boat_races')
          .select('race_date')
          .gte('race_date', startDate)
          .lte('race_date', endDate);
      return (res as List)
          .map((m) => (m as Map<String, dynamic>)['race_date'] as String)
          .toSet();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] 월별 경기 날짜 조회 실패: $e');
      return {};
    }
  }

  Future<List<Race>> loadRaces({required String date}) async {
    try {
      final res = await _client
          .from('boat_races')
          .select()
          .eq('race_date', date)
          .order('race_no');
      return (res as List).map((m) {
        final row = Map<String, dynamic>.from(m);
        return Race(
          venueCode: int.tryParse(row['meet'] as String) ?? 1,
          date: row['race_date'] as String,
          raceNo: row['race_no'] as int,
          venueName: (row['venue_name'] as String?) ?? '미사리경정공원',
          distance: (row['distance'] as int?) ?? 600,
          status: (row['status'] as String?) ?? '예정',
          departureTime: row['departure_time'] as String?,
          racerCount: (row['racer_count'] as int?) ?? 6,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_races 조회 실패: $e');
      return [];
    }
  }

  Future<void> clearCacheForDate(String date) async {
    try {
      await _client.from('boat_races').delete().eq('race_date', date);
      await _client.from('boat_entries').delete().eq('race_date', date);
      await _client.from('boat_predictions').delete().eq('race_date', date);
      await _client
          .from('boat_prediction_evaluations')
          .delete()
          .eq('race_date', date);
      if (kDebugMode) debugPrint('[Supabase] $date 캐시 전체 삭제 완료');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] 캐시 삭제 실패: $e');
    }
  }

  // ─── 출주표 ───

  Future<void> saveEntries({
    required String date,
    required int raceNo,
    required List<RaceEntry> entries,
  }) async {
    if (entries.isEmpty) return;
    try {
      final rows = entries
          .map(
            (e) => {
              'meet': '1',
              'race_date': date,
              'race_no': raceNo,
              'course_no': e.courseNo,
              'racer_name': e.racerName,
              'racer_id': e.racerId,
              'grade': e.grade,
              'avg_score': e.avgScore,
              'recent3_wins': e.recentWinCount,
              'recent_win_count': e.recentWinCount,
              'win_rate': e.winRate,
              'boat_no': e.boatNo,
              'motor_no': e.motorNo,
              'weight': e.weight,
              'avg_start_time': e.avgStartTime,
              'avg_rank_point': e.avgRankPoint,
              'top2_rate': e.top2Rate,
              'boat_win_rate': e.boatWinRate,
              'boat_rank_point': e.boatRankPoint,
              'motor_win_rate': e.motorWinRate,
              'motor_top3_rate': e.motorTop3Rate,
              'motor_rank_point': e.motorRankPoint,
            },
          )
          .toList();
      await _client
          .from('boat_entries')
          .upsert(rows, onConflict: 'meet,race_date,race_no,course_no');
      if (kDebugMode) debugPrint('[Supabase] boat_entries ${rows.length}건 저장');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_entries 저장 실패: $e');
    }
  }

  Future<List<RaceEntry>> loadEntries({
    required String date,
    required int raceNo,
  }) async {
    try {
      final res = await _client
          .from('boat_entries')
          .select()
          .eq('race_date', date)
          .eq('race_no', raceNo)
          .order('course_no');
      return (res as List).map((m) {
        final row = Map<String, dynamic>.from(m);
        return RaceEntry(
          courseNo: row['course_no'] as int,
          racerName: row['racer_name'] as String,
          racerId: row['racer_id'] as String,
          grade: row['grade'] as String,
          avgScore: (row['avg_score'] as num?)?.toDouble() ?? 0,
          recentWinCount:
              (row['recent_win_count'] as num?)?.toInt() ??
              (row['recent3_wins'] as num?)?.toInt() ??
              0,
          winRate: (row['win_rate'] as num?)?.toDouble() ?? 0,
          boatNo: row['boat_no'] as int?,
          motorNo: row['motor_no'] as int?,
          weight: (row['weight'] as num?)?.toDouble(),
          avgStartTime: (row['avg_start_time'] as num?)?.toDouble(),
          avgRankPoint: (row['avg_rank_point'] as num?)?.toDouble(),
          top2Rate: (row['top2_rate'] as num?)?.toDouble(),
          boatWinRate: (row['boat_win_rate'] as num?)?.toDouble(),
          boatRankPoint: (row['boat_rank_point'] as num?)?.toDouble(),
          motorWinRate: (row['motor_win_rate'] as num?)?.toDouble(),
          motorTop3Rate: (row['motor_top3_rate'] as num?)?.toDouble(),
          motorRankPoint: (row['motor_rank_point'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_entries 조회 실패: $e');
      return [];
    }
  }

  // ─── AI 예측 ───

  Future<RaceConditions?> loadRaceConditions({
    required String date,
    required int raceNo,
  }) async {
    try {
      final response = await _client
          .from('race_weather')
          .select('wsd,pcp')
          .eq('race_date', date)
          .eq('race_no', raceNo)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      final precipitationText = response['pcp']?.toString() ?? '';
      final precipitation = double.tryParse(
        precipitationText.replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      return RaceConditions(
        windSpeed: (response['wsd'] as num?)?.toDouble(),
        precipitation: precipitation,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] 경주 기상 조회 실패: $e');
      return null;
    }
  }

  Future<void> savePrediction({
    required String date,
    required int raceNo,
    required RacePrediction prediction,
  }) async {
    try {
      final rows = prediction.rankings
          .map(
            (r) => {
              'meet': '1',
              'race_date': date,
              'race_no': raceNo,
              'racer_no': r.courseNo,
              'racer_name': r.racerName,
              'racer_id': r.racerId,
              'grade': r.grade,
              'win_probability': r.winProb,
              'rank': r.rank,
              'total_score': r.totalScore,
              'factors': r.factors,
              'analysis': prediction.analysis,
              'confidence': prediction.confidence,
              'model_version': prediction.modelVersion,
              'predicted_at': prediction.predictedAt.toIso8601String(),
            },
          )
          .toList();
      await _client
          .from('boat_predictions')
          .upsert(
            rows,
            onConflict: 'meet,race_date,race_no,racer_no,model_version',
            ignoreDuplicates: true,
          );
      if (kDebugMode) {
        debugPrint('[Supabase] boat_predictions ${rows.length}건 저장');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_predictions 저장 실패: $e');
    }
  }

  Future<RacePrediction?> loadPrediction({
    required String date,
    required int raceNo,
    String? modelVersion,
  }) async {
    try {
      var query = _client
          .from('boat_predictions')
          .select()
          .eq('race_date', date)
          .eq('race_no', raceNo);
      if (modelVersion != null) {
        query = query.eq('model_version', modelVersion);
      }
      final res = await query.order('rank');
      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;

      final rankings = rows
          .map(
            (r) => RacerPrediction(
              courseNo: r['racer_no'] as int,
              racerName: r['racer_name'] as String,
              racerId: (r['racer_id'] as String?) ?? '',
              grade: (r['grade'] as String?) ?? '',
              winProb: (r['win_probability'] as num?)?.toDouble() ?? 0,
              rank: (r['rank'] as int?) ?? 0,
              totalScore: (r['total_score'] as num?)?.toDouble() ?? 0,
              factors: r['factors'] != null
                  ? Map<String, double>.from(
                      (r['factors'] as Map).map(
                        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
                      ),
                    )
                  : const {},
            ),
          )
          .toList();

      return PredictionEngine.restore(
        rankings: rankings,
        confidence: (rows.first['confidence'] as num?)?.toDouble() ?? 0,
        analysis: (rows.first['analysis'] as String?) ?? '',
        modelVersion:
            (rows.first['model_version'] as String?) ?? 'heuristic-v1',
        predictedAt:
            DateTime.tryParse(rows.first['predicted_at']?.toString() ?? '') ??
            DateTime.tryParse(rows.first['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_predictions 조회 실패: $e');
      return null;
    }
  }

  Future<void> savePredictionEvaluation({
    required String date,
    required int raceNo,
    required RacePrediction prediction,
    required PredictionEvaluation evaluation,
  }) async {
    try {
      await _client.from('boat_prediction_evaluations').upsert({
        'meet': '1',
        'race_date': date,
        'race_no': raceNo,
        'model_version': prediction.modelVersion,
        'predicted_at': prediction.predictedAt.toIso8601String(),
        'win_hit': evaluation.winHit,
        'place_hit': evaluation.placeHit,
        'quinella_hit': evaluation.quinellaHit,
        'ordered_top3_hits': evaluation.orderedTop3Hits,
        'unordered_top3_hits': evaluation.unorderedTop3Hits,
        'evaluated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'meet,race_date,race_no,model_version');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] 예측 평가 저장 실패: $e');
    }
  }

  Future<PredictionStats> loadPredictionStats({
    String modelVersion = PredictionEngine.modelVersion,
  }) async {
    try {
      final response = await _client
          .from('boat_prediction_evaluations')
          .select('win_hit,place_hit,quinella_hit,ordered_top3_hits')
          .eq('model_version', modelVersion);
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        return const PredictionStats(
          raceCount: 0,
          winHits: 0,
          placeHits: 0,
          quinellaHits: 0,
          orderedTop3HitRate: 0,
        );
      }

      var winHits = 0;
      var placeHits = 0;
      var quinellaHits = 0;
      var orderedHits = 0;
      for (final row in rows) {
        if (row['win_hit'] == true) winHits++;
        if (row['place_hit'] == true) placeHits++;
        if (row['quinella_hit'] == true) quinellaHits++;
        orderedHits += (row['ordered_top3_hits'] as num?)?.toInt() ?? 0;
      }
      return PredictionStats(
        raceCount: rows.length,
        winHits: winHits,
        placeHits: placeHits,
        quinellaHits: quinellaHits,
        orderedTop3HitRate: orderedHits / (rows.length * 3) * 100,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] 예측 통계 조회 실패: $e');
      return const PredictionStats(
        raceCount: 0,
        winHits: 0,
        placeHits: 0,
        quinellaHits: 0,
        orderedTop3HitRate: 0,
      );
    }
  }
}
