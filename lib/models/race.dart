class Race {
  final int venueCode;
  final String date;
  final int raceNo;
  final String venueName;
  final int distance;
  final String _rawStatus;
  final String? departureTime;
  final int racerCount;

  static const defaultDepartureTimes = <int, String>{
    1: '11:40', 2: '12:03', 3: '12:26', 4: '12:49',
    5: '13:12', 6: '13:35', 7: '13:58', 8: '14:21',
    9: '14:45', 10: '15:09', 11: '15:33', 12: '15:57',
    13: '16:21', 14: '16:45', 15: '17:09', 16: '17:33',
    17: '17:57',
  };

  const Race({
    required this.venueCode,
    required this.date,
    required this.raceNo,
    required this.venueName,
    this.distance = 600,
    String status = '예정',
    this.departureTime,
    this.racerCount = 6,
  }) : _rawStatus = status;

  String get effectiveDepartureTime =>
      departureTime ?? defaultDepartureTimes[raceNo] ?? '';

  String get status {
    if (_rawStatus == '종료' || _rawStatus == '완료') return _rawStatus;

    final cleaned = date.replaceAll('.', '').replaceAll('-', '');
    if (cleaned.length < 8) {
      return _rawStatus == '확정' ? '확정' : _rawStatus;
    }

    final y = int.tryParse(cleaned.substring(0, 4)) ?? 0;
    final m = int.tryParse(cleaned.substring(4, 6)) ?? 0;
    final d = int.tryParse(cleaned.substring(6, 8)) ?? 0;
    final raceDate = DateTime(y, m, d);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 과거 날짜 → 확정이면 유지, 아니면 종료
    if (raceDate.isBefore(today)) {
      return _rawStatus == '확정' ? '확정' : '종료';
    }

    // 오늘 → 출발 시간 기준으로 판단
    if (raceDate.isAtSameMomentAs(today)) {
      final depTime = effectiveDepartureTime;
      if (depTime.isNotEmpty) {
        final parts = depTime.split(':');
        if (parts.length >= 2) {
          final hh = int.tryParse(parts[0].trim()) ?? 0;
          final mm = int.tryParse(parts[1].trim()) ?? 0;
          final startAt = DateTime(y, m, d, hh, mm);
          if (now.isBefore(startAt)) {
            return _rawStatus == '확정' ? '예정' : _rawStatus;
          }
        }
      }
      return _rawStatus == '확정' ? '확정' : '종료';
    }

    // 미래 → '확정'은 출주표 확정 의미이므로 '예정'으로 표시
    if (_rawStatus == '확정') return '예정';
    return _rawStatus;
  }

  String get displayDate {
    if (date.length >= 8) {
      return '${date.substring(4, 6)}/${date.substring(6, 8)}';
    }
    return date;
  }
}
