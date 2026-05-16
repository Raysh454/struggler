import 'package:flutter_test/flutter_test.dart';
import 'package:struggler/main.dart';

void main() {
  testWidgets('StruggleApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const StruggleApp());
    expect(find.byType(StruggleApp), findsOneWidget);
  });
}
