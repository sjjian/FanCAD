import 'package:fancad/models/assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format and parse round-trip object and drawing tags', () {
    final objects = ComposerPinModel.entities([1, 2, 3], tabId: '7');
    expect(formatComposerPin(objects), '@objects[tab=7 ids=1,2,3]');
    final parsedObjects = parseComposerPin(formatComposerPin(objects))!;
    expect(parsedObjects.kind, ComposerPinKind.entity);
    expect(parsedObjects.tabId, '7');
    expect(parsedObjects.ids, [1, 2, 3]);

    final drawing = ComposerPinModel.drawing(tabId: '9', tabTitle: 'Sheet');
    expect(formatComposerPin(drawing), '@drawing[tab=9]');
    final parsedDrawing = parseComposerPin(formatComposerPin(drawing))!;
    expect(parsedDrawing.kind, ComposerPinKind.drawing);
    expect(parsedDrawing.tabId, '9');
    expect(parsedDrawing.ids, isEmpty);
  });

  test('flatten with mention tokens writes inline tags, not chip labels', () {
    final pin = ComposerPinModel.entities([1, 2, 3], tabId: '7');
    expect(
      flattenComposerPins([pin], 'offset $composerMentionToken please'),
      'offset @objects[tab=7 ids=1,2,3] please',
    );
    expect(
      flattenComposerPins([pin], 'offset $composerMentionToken please'),
      isNot(contains('3 objects')),
    );
    expect(
      flattenComposerPins([pin], 'offset $composerMentionToken please'),
      isNot(contains('Pinned:')),
    );
  });

  test('flatten without tokens keeps the leftover Pinned footer', () {
    final pin = ComposerPinModel.entities([12], tabId: '4', tabTitle: 'Alpha');
    final flattened = flattenComposerPins([pin], 'offset these');
    expect(flattened, contains('Pinned:'));
    expect(flattened, contains('#12'));
    expect(flattened, contains('tab: 4'));
  });

  test('splitComposerPinSpans keeps surrounding prose', () {
    const text = 'Keep @objects[tab=7 ids=1,2] and @drawing[tab=9].';
    final spans = splitComposerPinSpans(text);
    expect(spans, hasLength(5));
    expect(spans[0], isA<ComposerPinTextModel>());
    expect((spans[0] as ComposerPinTextModel).text, 'Keep ');
    expect((spans[1] as ComposerPinChipModel).pin.ids, [1, 2]);
    expect((spans[2] as ComposerPinTextModel).text, ' and ');
    expect((spans[3] as ComposerPinChipModel).pin.kind, ComposerPinKind.drawing);
    expect((spans[4] as ComposerPinTextModel).text, '.');
    expect(parseComposerPins(text), hasLength(2));
  });
}
