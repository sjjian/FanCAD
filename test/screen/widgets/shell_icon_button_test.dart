import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover icon button stays 28', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: ShellIconButton(icon: Icons.add, onPressed: () {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ShellIconButton)).width, 28);
    expect(tester.getSize(find.byType(ShellIconButton)).height, 28);
  });
}
