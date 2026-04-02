class Odds {
  final Map<int, double> win;
  final Map<String, double> place;
  final Map<String, double> quinella;
  final Map<String, double> trio;
  final Map<String, double> trifecta;

  const Odds({
    this.win = const {},
    this.place = const {},
    this.quinella = const {},
    this.trio = const {},
    this.trifecta = const {},
  });
}
