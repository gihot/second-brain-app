import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/main.dart';

void main() {
  testWidgets('App renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SecondBrainApp());
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
