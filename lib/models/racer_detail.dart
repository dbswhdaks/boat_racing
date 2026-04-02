import 'race_entry.dart';

class RacerDetail {
  final String racerId;
  final String racerName;
  final String grade;
  final double avgScore;
  final int yearRaceCount;
  final int year1stCount;
  final int year2ndCount;
  final int year3rdCount;
  final double? yearAvgRank;
  final int? age;
  final double? weight;
  final double? recentAvgScore;
  final List<double> recentScores;
  final Map<int, int> courseWins;

  final double? avgStartTime;
  final double? avgAccidentScore;
  final double? consecutiveWinRate;
  final int rank4Count;
  final int rank5Count;
  final int rank6Count;
  final String? stndYear;
  final bool fromApi;

  const RacerDetail({
    required this.racerId,
    required this.racerName,
    required this.grade,
    this.avgScore = 0,
    this.yearRaceCount = 0,
    this.year1stCount = 0,
    this.year2ndCount = 0,
    this.year3rdCount = 0,
    this.yearAvgRank,
    this.age,
    this.weight,
    this.recentAvgScore,
    this.recentScores = const [],
    this.courseWins = const {},
    this.avgStartTime,
    this.avgAccidentScore,
    this.consecutiveWinRate,
    this.rank4Count = 0,
    this.rank5Count = 0,
    this.rank6Count = 0,
    this.stndYear,
    this.fromApi = false,
  });

  int get totalWins => year1stCount;

  double get winRate =>
      yearRaceCount > 0 ? (year1stCount / yearRaceCount) * 100 : 0;

  double get podiumRate => yearRaceCount > 0
      ? ((year1stCount + year2ndCount + year3rdCount) / yearRaceCount) * 100
      : 0;

  factory RacerDetail.fromApiMap(
    Map<String, dynamic> m, {
    RaceEntry? entry,
  }) {
    return RacerDetail(
      racerId: entry?.racerId ?? m['racer_nm']?.toString().trim() ?? '',
      racerName: m['racer_nm']?.toString().trim() ?? entry?.racerName ?? '',
      grade: entry?.grade ?? '-',
      avgScore: _dbl(m['avg_scr']) ?? entry?.avgScore ?? 0,
      yearRaceCount: _int(m['race_tcnt']) ?? 0,
      year1stCount: _int(m['rank1_tcnt']) ?? 0,
      year2ndCount: _int(m['rank2_tcnt']) ?? 0,
      year3rdCount: _int(m['rank3_tcnt']) ?? 0,
      yearAvgRank: _dbl(m['avg_rank']),
      weight: entry?.weight,
      avgStartTime: _dbl(m['avg_strt_tm']),
      avgAccidentScore: _dbl(m['avg_acdnt_scr']),
      consecutiveWinRate: _dbl(m['high_rate']),
      rank4Count: _int(m['rank4_tcnt']) ?? 0,
      rank5Count: _int(m['rank5_tcnt']) ?? 0,
      rank6Count: _int(m['rank6_tcnt']) ?? 0,
      stndYear: m['stnd_yr']?.toString(),
      fromApi: true,
    );
  }

  factory RacerDetail.fromRaceEntry(RaceEntry entry) {
    return RacerDetail(
      racerId: entry.racerId,
      racerName: entry.racerName,
      grade: entry.grade,
      avgScore: entry.avgScore,
    );
  }

  factory RacerDetail.fromRaceEntryDetailed(RaceEntry entry) {
    final seed = entry.racerName.hashCode.abs();
    final r = seed % 100;

    final gradeMultiplier = switch (entry.grade) {
      'A1' => 1.3,
      'A2' => 1.0,
      'B1' => 0.8,
      'B2' => 0.6,
      _ => 0.7,
    };

    final yearRaces = (20 + (r % 30) * gradeMultiplier).round();
    final winPct = (0.05 + (r % 15) * 0.006) * gradeMultiplier;
    final year1st = (yearRaces * winPct).round().clamp(0, yearRaces);
    final year2nd =
        (yearRaces * winPct * 0.9).round().clamp(0, yearRaces - year1st);
    final year3rd = (yearRaces * winPct * 0.7)
        .round()
        .clamp(0, yearRaces - year1st - year2nd);

    final courseWins = <int, int>{};
    for (int c = 1; c <= 6; c++) {
      courseWins[c] =
          ((year1st * (0.1 + (seed + c * 7) % 10 * 0.02))).round();
    }

    final base = entry.avgScore;
    final scores = List.generate(5, (i) {
      final variance = ((seed + i * 7) % 10 - 5) * 0.08;
      return double.parse((base + variance).toStringAsFixed(1));
    });
    final recentAvg = scores.reduce((a, b) => a + b) / scores.length;

    final ageBase = switch (entry.grade) {
      'A1' => 30,
      'A2' => 28,
      'B1' => 26,
      _ => 24,
    };

    return RacerDetail(
      racerId: entry.racerId,
      racerName: entry.racerName,
      grade: entry.grade,
      avgScore: entry.avgScore,
      yearRaceCount: yearRaces,
      year1stCount: year1st,
      year2ndCount: year2nd,
      year3rdCount: year3rd,
      recentAvgScore: recentAvg,
      recentScores: scores,
      age: ageBase + (r % 10),
      weight: 52.0 + (r % 12).toDouble(),
      courseWins: courseWins,
    );
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
