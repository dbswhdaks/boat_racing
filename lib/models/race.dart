class Race {
  final int venueCode;
  final String date;
  final int raceNo;
  final String venueName;
  final int distance;
  final String _rawStatus;
  final String? departureTime;
  final int racerCount;

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

  String get status {
    if (_rawStatus == '종료' || _rawStatus == '확정' || _rawStatus == '완료') {
      return _rawStatus;
    }
    final cleaned = date.replaceAll('.', '').replaceAll('-', '');
    if (cleaned.length >= 8) {
      final raceDate = DateTime.tryParse(
        '${cleaned.substring(0, 4)}-${cleaned.substring(4, 6)}-${cleaned.substring(6, 8)}',
      );
      if (raceDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (raceDate.isBefore(today) || raceDate.isAtSameMomentAs(today)) {
          return '종료';
        }
      }
    }
    return _rawStatus;
  }

  String get displayDate {
    if (date.length >= 8) {
      return '${date.substring(4, 6)}/${date.substring(6, 8)}';
    }
    return date;
  }
}
