import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentos/main.dart';

void main() {
  testWidgets('App boots and shows splash content', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudentOSApp()));
    // First frame should render the splash screen ("StudentOS" branding) before
    // any network call to the (not-running-in-tests) backend resolves.
    await tester.pump();
    expect(find.text('StudentOS'), findsOneWidget);
  });
}
