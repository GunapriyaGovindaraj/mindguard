import 'package:flutter_test/flutter_test.dart';
import 'package:mindguard/main.dart';

void main() {
  testWidgets('MindGuard app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(MindGuardApp());
    expect(find.byType(MindGuardApp), findsOneWidget);
  });
}