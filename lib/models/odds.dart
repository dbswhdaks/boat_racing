class Odds {
  final Map<int, double> win;
  final Map<int, double> show;
  final Map<String, double> place;
  final Map<String, double> exacta;
  final Map<String, double> quinella;
  final Map<String, double> trio;
  final Map<String, double> xla;
  final Map<String, double> trifecta;

  const Odds({
    this.win = const {},
    this.show = const {},
    this.place = const {},
    this.exacta = const {},
    this.quinella = const {},
    this.trio = const {},
    this.xla = const {},
    this.trifecta = const {},
  });

  bool get isEmpty =>
      win.isEmpty &&
      show.isEmpty &&
      place.isEmpty &&
      exacta.isEmpty &&
      quinella.isEmpty &&
      trio.isEmpty &&
      xla.isEmpty &&
      trifecta.isEmpty;
}
