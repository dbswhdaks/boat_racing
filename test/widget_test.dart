import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boat_racing/main.dart';
import 'package:boat_racing/features/race/providers/race_providers.dart';
import 'package:boat_racing/models/race.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raceListProvider((date: todayYmd)).overrideWith(
            (ref) async => const DataWithSource<List<Race>>(data: []),
          ),
        ],
        child: const BoatRacingApp(),
      ),
    );
    await tester.pump();

    expect(find.text('경정 Plus'), findsOneWidget);
  });
}
