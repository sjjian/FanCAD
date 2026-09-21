import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover empty state is a centered message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(body: ShellEmpty(message: 'Nothing here')),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(ShellEmpty), findsOneWidget);
  });
}
