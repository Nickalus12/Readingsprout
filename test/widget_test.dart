import 'package:flutter_test/flutter_test.dart';
import 'package:sight_words/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SightWordsApp());
    // App should show splash screen initially
    expect(find.text('Loading...'), findsOneWidget);
  });
}
