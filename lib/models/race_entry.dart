class RaceEntry {
  final int courseNo;
  final String racerName;
  final String racerId;
  final String grade;
  final double avgScore;
  final int recentWinCount;
  final double winRate;
  final int? boatNo;
  final int? motorNo;
  final double? weight;
  final double? avgStartTime;
  final double? boatWinRate;
  final double? motorWinRate;

  const RaceEntry({
    required this.courseNo,
    required this.racerName,
    required this.racerId,
    required this.grade,
    this.avgScore = 0,
    this.recentWinCount = 0,
    this.winRate = 0,
    this.boatNo,
    this.motorNo,
    this.weight,
    this.avgStartTime,
    this.boatWinRate,
    this.motorWinRate,
  });

  /// 이전 캐시/화면 코드와의 호환을 위한 별칭.
  @Deprecated('recentWinCount 또는 winRate를 사용하세요.')
  int get recent3Wins => recentWinCount;

  RaceEntry copyWith({
    double? avgScore,
    int? recentWinCount,
    double? winRate,
    double? weight,
    double? avgStartTime,
    double? boatWinRate,
    double? motorWinRate,
  }) {
    return RaceEntry(
      courseNo: courseNo,
      racerName: racerName,
      racerId: racerId,
      grade: grade,
      avgScore: avgScore ?? this.avgScore,
      recentWinCount: recentWinCount ?? this.recentWinCount,
      winRate: winRate ?? this.winRate,
      boatNo: boatNo,
      motorNo: motorNo,
      weight: weight ?? this.weight,
      avgStartTime: avgStartTime ?? this.avgStartTime,
      boatWinRate: boatWinRate ?? this.boatWinRate,
      motorWinRate: motorWinRate ?? this.motorWinRate,
    );
  }
}
