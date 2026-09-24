import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 13, fontFamily: 'Roboto');

  testWidgets('a short name is shown whole', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FileName(name: 'plan.dwg', maxWidth: 180, style: style),
      ),
    );
    expect(find.text('plan.dwg'), findsOneWidget);
  });

  testWidgets('a long name keeps its head, ellipsis and extension', (
    tester,
  ) async {
    const name = '50A030000323-9479-9461-battery-board.dwg';
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.centerLeft,
          child: FileName(name: name, maxWidth: 180, style: style),
        ),
      ),
    );
    final shown = tester.widget<Text>(find.byType(Text)).data!;
    final parts = shown.split('…');
    expect(parts, hasLength(2));
    expect(parts[0].startsWith('50A'), isTrue);
    expect(parts[1].endsWith('.dwg'), isTrue);
    expect(parts[1].length, greaterThan('.dwg'.length));
    expect((parts[0].length - parts[1].length).abs(), lessThanOrEqualTo(2));
    expect(tester.getSize(find.byType(FileName)).width, lessThanOrEqualTo(180));
  });
}
