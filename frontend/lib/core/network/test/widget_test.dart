import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/features/splash/splash_screen.dart';

void main() {
  testWidgets('KomiVerse shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KomiVerseApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
