import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover icon button stays 28', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: FanCadIconButton(icon: Icons.add, onPressed: () {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FanCadIconButton)).width, 28);
    expect(tester.getSize(find.byType(FanCadIconButton)).height, 28);
  });
}
