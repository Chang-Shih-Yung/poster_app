import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/core/theme/app_theme.dart';
import 'package:poster_app/features/home/home_drawer.dart';

/// Smoke test for the IG-style home drawer. The user's v18 spec is
/// exactly three rows: 收藏 / 為你推薦 / 追蹤中. If any of those labels
/// get renamed or removed we want to hear about it at CI time, not
/// via a screenshot days later.
void main() {
  testWidgets('HomeDrawer renders the three v18 nav rows', (tester) async {
    AppTheme.setDayMode(false);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            drawer: HomeDrawer(),
            body: SizedBox.expand(),
          ),
        ),
      ),
    );

    // Open the drawer.
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // The three rows + the 動態消息 header.
    expect(find.text('動態消息'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('為你推薦'), findsOneWidget);
    expect(find.text('追蹤中'), findsOneWidget);
  });
}
