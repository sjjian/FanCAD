import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover strip tab underlines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: FanCadTab(
            selected: true,
            onTap: () {},
            child: const Text('Model'),
          ),
        ),
      ),
    );
    final tab = tester.widget<FanCadTab>(find.byType(FanCadTab));
    expect(tab.selected, isTrue);
    expect(tab.style, FanCadTabStyle.strip);
    final fill = tester.widget<Container>(
      find.descendant(
        of: find.byType(FanCadTab),
        matching: find.byType(Container),
      ),
    );
    final decoration = fill.decoration! as BoxDecoration;
    expect(decoration.color, FanCadTokens.dark.pressed);
    expect(decoration.border?.bottom.color, FanCadTokens.dark.accent);
    expect(decoration.border?.bottom.width, 1);
  });
}
