import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('summaryJson leaves extents null on a blank drawing', () {
    final empty = const DocumentContextBuilder().summaryJson(CadDocument());
    expect(empty['entityCount'], 0);
    expect(empty['extents'], isNull);
    expect(empty['activeLayout'], 'Model');
    expect(empty['byKind'], isEmpty);
  });

  test('a capped summary lists blocks and plugin typings, not every type', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'BOLT_HOLE', entityIds: []));
    final session = DocumentSession(id: 't', document: document);
    session.edit('setup', (transaction) {
      for (var i = 0; i < 4; i++) {
        transaction.add(
          LineEntity(
            id: 0,
            start: Vec2(i.toDouble(), 0),
            end: Vec2(i.toDouble(), 1),
          ),
        );
      }
      transaction.add(CircleEntity(id: 0, center: const Vec2(0, 2), radius: 1));
      transaction.add(const PointEntity(id: 0, position: Vec2(3, 3)));
    });

    const builder = DocumentContextBuilder(maxKinds: 1, maxLayers: 1);
    final text = builder.summarize(document);
    expect(text, contains('line×4'));
    expect(text, isNot(contains('circle×')));
    expect(text, contains('blocks: BOLT_HOLE'));

    final json = builder.summaryJson(document);
    expect(json['byKind'], containsPair('line', 4));
    expect(json['extents'], isNotNull);

    final prompt = builder.systemPrompt(
      document: document,
      tools: const [],
      pluginTypings: 'declare const fancad: unknown;',
    );
    expect(prompt, contains('declare const fancad: unknown;'));
    expect(prompt, contains('When writing or repairing a plugin'));
  });
}
