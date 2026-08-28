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
  final String modelVersion;
  final DateTime predictedAt;

  RacePrediction({
    required this.rankings,
    required this.confidence,
    required this.winPicks,
    required this.placePicks,
    required this.quinellaPicks,
    required this.analysis,
    this.modelVersion = 'heuristic-v2',
    DateTime? predictedAt,
  }) : predictedAt = predictedAt ?? DateTime.now().toUtc();
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

class RaceConditions {
  final double? windSpeed;
  final double? precipitation;

  const RaceConditions({this.windSpeed, this.precipitation});

  bool get isAdverse => (windSpeed ?? 0) >= 5 || (precipitation ?? 0) > 0;
}

class PredictionEvaluation {
  final bool winHit;
  final bool placeHit;
  final bool quinellaHit;
  final int orderedTop3Hits;
  final int unorderedTop3Hits;

  const PredictionEvaluation({
    required this.winHit,
    required this.placeHit,
    required this.quinellaHit,
    required this.orderedTop3Hits,
    required this.unorderedTop3Hits,
  });
}

class PredictionStats {
  final int raceCount;
  final int winHits;
  final int placeHits;
  final int quinellaHits;
  final double orderedTop3HitRate;

  const PredictionStats({
    required this.raceCount,
    required this.winHits,
    required this.placeHits,
    required this.quinellaHits,
    required this.orderedTop3HitRate,
  });

  double get winHitRate => raceCount == 0 ? 0 : winHits / raceCount * 100;
  double get placeHitRate => raceCount == 0 ? 0 : placeHits / raceCount * 100;
  double get quinellaHitRate =>
      raceCount == 0 ? 0 : quinellaHits / raceCount * 100;
}
