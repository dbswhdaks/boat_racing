class RacerPrediction {
  final int courseNo;
  final String racerName;
  final String racerId;
  final String grade;
  final double winProb;
  final int rank;
  final double totalScore;
  final Map<String, double> factors;

  const RacerPrediction({
    required this.courseNo,
    required this.racerName,
    required this.racerId,
    required this.grade,
    required this.winProb,
    required this.rank,
    required this.totalScore,
    required this.factors,
  });
}

class RacePrediction {
  final List<RacerPrediction> rankings;
  final double confidence;
  final List<BettingPick> winPicks;
  final List<BettingPick> placePicks;
  final List<BettingPick> quinellaPicks;
  final String analysis;

  const RacePrediction({
    required this.rankings,
    required this.confidence,
    required this.winPicks,
    required this.placePicks,
    required this.quinellaPicks,
    required this.analysis,
  });
}

class BettingPick {
  final String label;
  final String description;
  final double confidence;

  const BettingPick({
    required this.label,
    required this.description,
    required this.confidence,
  });
}
