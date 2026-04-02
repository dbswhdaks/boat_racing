import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boat_racing/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BoatRacingApp()),
    );
    await tester.pump();

    expect(find.text('경정 Plus'), findsOneWidget);
  });
}
