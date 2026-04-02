class RaceEntry {
  final int courseNo;
  final String racerName;
  final String racerId;
  final String grade;
  final double avgScore;
  final int recent3Wins;
  final int? boatNo;
  final int? motorNo;
  final double? weight;

  const RaceEntry({
    required this.courseNo,
    required this.racerName,
    required this.racerId,
    required this.grade,
    this.avgScore = 0,
    this.recent3Wins = 0,
    this.boatNo,
    this.motorNo,
    this.weight,
  });
}
