import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/race.dart';
import '../../models/race_entry.dart';
import '../../models/prediction.dart';

class SupabaseBackupService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── 경주 목록 ───

  Future<void> saveRaces(List<Race> races) async {
    if (races.isEmpty) return;
    try {
      final rows = races
          .map((r) => {
                'meet': r.venueCode.toString(),
                'race_date': r.date,
                'race_no': r.raceNo,
                'venue_name': r.venueName,
                'distance': r.distance,
                'status': r.status,
                'departure_time': r.departureTime,
                'racer_count': r.racerCount,
              })
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
          .map((e) => {
                'meet': '1',
                'race_date': date,
                'race_no': raceNo,
                'course_no': e.courseNo,
                'racer_name': e.racerName,
                'racer_id': e.racerId,
                'grade': e.grade,
                'avg_score': e.avgScore,
                'recent3_wins': e.recent3Wins,
                'boat_no': e.boatNo,
                'motor_no': e.motorNo,
                'weight': e.weight,
              })
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
          recent3Wins: (row['recent3_wins'] as int?) ?? 0,
          boatNo: row['boat_no'] as int?,
          motorNo: row['motor_no'] as int?,
          weight: (row['weight'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_entries 조회 실패: $e');
      return [];
    }
  }

  // ─── AI 예측 ───

  Future<void> savePrediction({
    required String date,
    required int raceNo,
    required RacePrediction prediction,
  }) async {
    try {
      final rows = prediction.rankings.map((r) => {
        'meet': '1',
        'race_date': date,
        'race_no': raceNo,
        'racer_no': r.courseNo,
        'racer_name': r.racerName,
        'win_probability': r.winProb,
        'place_probability': r.totalScore,
        'rank': r.rank,
        'total_score': r.totalScore,
        'factors': r.factors,
        'analysis': prediction.analysis,
        'confidence': prediction.confidence,
      }).toList();
      await _client
          .from('boat_predictions')
          .upsert(rows, onConflict: 'meet,race_date,race_no,racer_no');
      if (kDebugMode) debugPrint('[Supabase] boat_predictions ${rows.length}건 저장');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_predictions 저장 실패: $e');
    }
  }

  Future<RacePrediction?> loadPrediction({
    required String date,
    required int raceNo,
  }) async {
    try {
      final res = await _client
          .from('boat_predictions')
          .select()
          .eq('race_date', date)
          .eq('race_no', raceNo)
          .order('rank');
      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;

      final rankings = rows.map((r) => RacerPrediction(
        courseNo: r['racer_no'] as int,
        racerName: r['racer_name'] as String,
        racerId: '',
        grade: '',
        winProb: (r['win_probability'] as num?)?.toDouble() ?? 0,
        rank: (r['rank'] as int?) ?? 0,
        totalScore: (r['total_score'] as num?)?.toDouble() ?? 0,
        factors: r['factors'] != null
            ? Map<String, double>.from(
                (r['factors'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
            : const {},
      )).toList();

      return RacePrediction(
        rankings: rankings,
        confidence: (rows.first['confidence'] as num?)?.toDouble() ?? 0,
        winPicks: const [],
        placePicks: const [],
        quinellaPicks: const [],
        analysis: (rows.first['analysis'] as String?) ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] boat_predictions 조회 실패: $e');
      return null;
    }
  }
}
