import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover hairline is a 1px strong rule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const SizedBox(
          width: 80,
          height: 40,
          child: Column(
            children: [
              SizedBox(height: 10),
              FanCadHairline(),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
    final hairline = tester.widget<FanCadHairline>(find.byType(FanCadHairline));
    expect(hairline.strong, isTrue);
    expect(hairline.axis, Axis.horizontal);
    expect(tester.getSize(find.byType(FanCadHairline)).height, 1);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(FanCadHairline),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, FanCadTokens.dark.borderStrong);
  });
}
