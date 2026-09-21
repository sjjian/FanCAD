import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover badge is an accent tag and a chip when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: Row(
            children: [
              const ShellBadge(text: 'LAST'),
              ShellBadge(text: 'default', selected: true, onTap: () {}),
              const ShellDot(color: Color(0xFF22C55E)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('LAST'), findsOneWidget);
    expect(find.text('default'), findsOneWidget);
    expect(find.byType(ShellBadge), findsNWidgets(2));
    expect(find.byType(ShellDot), findsOneWidget);
  });
}
