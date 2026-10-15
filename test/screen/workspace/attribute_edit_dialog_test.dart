import 'package:fancad/fancad.dart';
import 'package:fancad/screen/workspace/attribute_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saving a changed attribute returns that value', (tester) async {
    Map<String, String>? saved;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AttributeEditDialog(
            blockName: 'TITLE',
            fields: const [
              AttributeEditField(
                tag: 'NO',
                label: 'Drawing number',
                value: 'A-01',
              ),
              AttributeEditField(
                tag: 'LOCK',
                label: 'Locked',
                value: 'KEEP',
                constant: true,
              ),
            ],
            onSave: (values) => saved = values,
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('attribute-edit-LOCK')),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('attribute-edit-NO')), 'A-02');
    await tester.tap(find.byKey(const Key('attribute-edit-save')));
    await tester.pump();

    expect(saved, {'NO': 'A-02'});
  });
}
