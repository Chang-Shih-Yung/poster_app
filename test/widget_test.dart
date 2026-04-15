import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:poster_app/main.dart';

void main() {
  testWidgets('App boots to browse tab', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PosterApp()));
    await tester.pumpAndSettle();
    expect(find.text('Poster App'), findsOneWidget);
  });
}
