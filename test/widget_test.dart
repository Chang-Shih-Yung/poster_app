import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poster_app/core/theme/app_theme.dart';

void main() {
  testWidgets('Theme builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Center(child: Text('POSTER.'))),
      ),
    );
    expect(find.text('POSTER.'), findsOneWidget);
  });
}
