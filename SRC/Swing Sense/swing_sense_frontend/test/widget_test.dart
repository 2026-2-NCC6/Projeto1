import 'package:flutter_test/flutter_test.dart';

import 'package:swing_sense_app/main.dart';

void main() {
  testWidgets('App inicia na splash screen sem travar', (WidgetTester tester) async {
    await tester.pumpWidget(const SwingSenseApp());
    await tester.pump();

    expect(find.text('Swing Sense'), findsOneWidget);
  });
}
