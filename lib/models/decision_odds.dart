/// KBOAT 확정배당률 — 경주가 끝난 뒤 실제로 지급되는 승식별 배당.
///
/// 경주 전 시점의 최종배당률([Odds])과 달리 승식마다 적중 조합이 하나뿐이므로
/// 값도 하나씩만 존재한다. 취소되거나 승자가 없는 승식은 `null` 이다.
class DecisionOdds {
  /// 단승 — 1착 맞히기
  final double? win;

  /// 연승 — 1착 선수가 2착 이내
  final double? placeFirst;

  /// 연승 — 2착 선수가 2착 이내
  final double? placeSecond;

  /// 쌍승 — 1·2착 순서까지 일치
  final double? exacta;

  /// 복승 — 1·2착 순서 무관
  final double? quinella;

  /// 삼복승 — 1~3착 순서 무관
  final double? trio;

  /// 쌍복승 — 1착 지정 + 2·3착 순서 무관
  final double? xla;

  /// 삼쌍승 — 1~3착 순서까지 일치
  final double? trifecta;

  const DecisionOdds({
    this.win,
    this.placeFirst,
    this.placeSecond,
    this.exacta,
    this.quinella,
    this.trio,
    this.xla,
    this.trifecta,
  });

  bool get isEmpty =>
      win == null &&
      placeFirst == null &&
      placeSecond == null &&
      exacta == null &&
      quinella == null &&
      trio == null &&
      xla == null &&
      trifecta == null;
}
