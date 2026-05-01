// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_and_i_admin_web_serivce/app.dart';

void main() {
  testWidgets('Unauthenticated users are redirected to login page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pumpAndSettle();

    expect(find.text('관리자 로그인'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });
}
