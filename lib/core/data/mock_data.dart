import '../../models/race.dart';
import '../../models/race_entry.dart';
import '../../models/race_result.dart';
import '../../models/odds.dart';

class MockData {
  static const _defaultRaceCount = 12;

  static const _startTimes = [
    '10:30', '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30', '15:00',
    '15:30', '16:00',
  ];

  static List<Race> racesFor(int venue, String date, {int count = _defaultRaceCount}) {
    return List.generate(count, (i) => Race(
      venueCode: venue,
      date: date,
      raceNo: i + 1,
      venueName: '미사리경정공원',
      distance: 600,
      departureTime: _startTimes[i % _startTimes.length],
      racerCount: 6,
    ));
  }

  static const _names = [
    '김동현', '이준호', '박성민', '최영수', '정우진', '한승재',
    '오태석', '장민혁', '나현우', '문정호', '임수빈', '배진형',
  ];

  static List<RaceEntry> entriesFor(int raceNo, [int venue = 1]) {
    final grades = ['A1', 'A2', 'B1', 'B2'];
    return List.generate(6, (i) => RaceEntry(
      courseNo: i + 1,
      racerName: _names[(raceNo + i) % _names.length],
      racerId: 'R${venue * 1000 + raceNo * 10 + i}',
      grade: grades[(i + venue) % grades.length],
      avgScore: 5.5 + (i * 0.4) + venue * 0.1,
      recent3Wins: (i + venue) % 3,
      boatNo: 30 + (raceNo * 6 + i) % 40,
      motorNo: 10 + (raceNo * 3 + i) % 30,
      weight: 52.0 + (i * 1.5),
    ));
  }

  static RaceResult raceResultFor(int raceNo, [List<RaceEntry>? realEntries, int venue = 1]) {
    final ranks = raceRanksFor(raceNo, realEntries, venue);
    final r1 = ranks[0];
    final r2 = ranks[1];
    final r3 = ranks[2];
    final seed = raceNo * 13 + venue * 7;
    return RaceResult(
      raceNo: raceNo,
      first: r1['racer_nm'] as String,
      firstNo: r1['course_no'] as int,
      second: r2['racer_nm'] as String,
      secondNo: r2['course_no'] as int,
      third: r3['racer_nm'] as String,
      thirdNo: r3['course_no'] as int,
      winOdds: 3.0 + raceNo * 0.4 + venue * 0.5,
      placeOdds: 1.5 + raceNo * 0.2 + venue * 0.3,
      quinellaOdds: 7.0 + seed * 0.2,
    );
  }

  static List<Map<String, dynamic>> raceRanksFor(int raceNo, [List<RaceEntry>? realEntries, int venue = 1]) {
    final entries = (realEntries != null && realEntries.isNotEmpty)
        ? realEntries
        : entriesFor(raceNo, venue);
    final shuffled = List.of(entries);
    final seed = raceNo * 7 + venue * 11;
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = (seed + i * 3) % (i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    return List.generate(shuffled.length, (i) {
      final e = shuffled[i];
      return {
        'rank': i + 1,
        'course_no': e.courseNo,
        'racer_nm': e.racerName,
        'racer_grd': e.grade,
        'race_time': '0:${(38 + i * 2).toString().padLeft(2, '0')}.${(30 + i * 15 + venue * 5) % 100}',
        'arrival_diff': i == 0 ? '-' : '+${(i * 0.2).toStringAsFixed(1)}초',
      };
    });
  }

  static Odds oddsFor(int raceNo, [int venue = 1]) {
    final v = venue * 0.3;
    final r = raceNo * 0.2;
    return Odds(
      win: {1: 3.2 + v, 2: 5.1 + r, 3: 8.4 + v + r, 4: 12.0 + v, 5: 18.5 + r, 6: 25.0 + v + r},
      place: {'1-2': 2.1 + v, '1-3': 4.5 + r, '1-4': 5.2 + v, '2-3': 6.2 + r, '2-4': 8.1 + v + r, '3-4': 12.5 + v},
      quinella: {'1-2': 4.8 + v, '1-3': 12.2 + r, '2-1': 5.1 + v + r, '2-3': 18.5 + v, '3-1': 15.0 + r, '3-2': 22.0 + v + r},
      trio: {'1-2-3': 8.5 + v, '1-2-4': 15.2 + r, '1-3-2': 9.0 + v + r, '2-1-3': 12.0 + v, '2-3-1': 18.5 + r},
      trifecta: {'1-2-3': 25.0 + v + r, '1-2-4': 45.0 + v, '1-3-2': 38.0 + r, '2-1-3': 52.0 + v + r, '2-3-1': 68.0 + v},
    );
  }
}
