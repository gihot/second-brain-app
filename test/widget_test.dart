import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/widgets/brain_bottom_nav.dart';

void main() {
  // The full SecondBrainApp pulls in Hive (via providers) which needs an
  // IndexedDB-capable platform — not available in `flutter test`. So this
  // smoke test pumps just the bottom-nav widget and asserts the real,
  // current German labels are present.
  testWidgets('BrainBottomNav renders the canonical German labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BrainBottomNav(currentIndex: 0, onTap: (_) {}),
      ),
    ));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SUCHE'), findsOneWidget);
    expect(find.text('ERFASSEN'), findsOneWidget);
    expect(find.text('INBOX'), findsOneWidget);
    expect(find.text('OPTIONEN'), findsOneWidget);
  });
}
