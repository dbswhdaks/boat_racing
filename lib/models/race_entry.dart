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

  /// 선수 연간 평균착순점 (0~10).
  final double? avgRankPoint;

  /// 선수 연간 연대율 (%). 2착 이내 비율.
  final double? top2Rate;

  /// 보트 연간 연대율 (%).
  final double? boatWinRate;

  /// 보트 연간 평균착순점 (0~10).
  final double? boatRankPoint;

  /// 모터 연간 이연대율 (%).
  final double? motorWinRate;

  /// 모터 연간 삼연대율 (%).
  final double? motorTop3Rate;

  /// 모터 연간 평균착순점 (0~10).
  final double? motorRankPoint;

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
    this.avgRankPoint,
    this.top2Rate,
    this.boatWinRate,
    this.boatRankPoint,
    this.motorWinRate,
    this.motorTop3Rate,
    this.motorRankPoint,
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
    double? avgRankPoint,
    double? top2Rate,
    double? boatWinRate,
    double? boatRankPoint,
    double? motorWinRate,
    double? motorTop3Rate,
    double? motorRankPoint,
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
      avgRankPoint: avgRankPoint ?? this.avgRankPoint,
      top2Rate: top2Rate ?? this.top2Rate,
      boatWinRate: boatWinRate ?? this.boatWinRate,
      boatRankPoint: boatRankPoint ?? this.boatRankPoint,
      motorWinRate: motorWinRate ?? this.motorWinRate,
      motorTop3Rate: motorTop3Rate ?? this.motorTop3Rate,
      motorRankPoint: motorRankPoint ?? this.motorRankPoint,
    );
  }
}
