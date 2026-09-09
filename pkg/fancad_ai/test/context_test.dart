import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
  test('a summary reports counts and extents without listing every entity', () {
    final document = CadDocument();
    document.editLike((transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 0)),
      );
      transaction.add(
        CircleEntity(id: 0, center: const Vec2(5, 5), radius: 2),
      );
    });

    final text = const DocumentContextBuilder().summarize(document);
    expect(text, contains('entities: 2'));
    expect(text, contains('line×1'));
    expect(text, contains('circle×1'));
    expect(text, contains('extents:'));
    // The whole point of the summary: it must not dump geometry.
    expect(text, isNot(contains('"start"')));
  });

  test('the system prompt tells the model to query instead of guessing', () {
    final prompt = const DocumentContextBuilder().systemPrompt(
      document: CadDocument(),
      tools: const [],
    );
    expect(prompt, contains('query.summary'));
    expect(prompt, contains('query.entities'));
    expect(prompt, contains('selection: none'));
    expect(prompt, contains('skill.read'));
    expect(prompt, contains(fancadCallExample));
    expect(prompt, contains('never inside args'));
  });

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

  test('an empty leftover selection is written as none, not omitted', () {
    const snapshot = SessionSnapshot();
    expect(snapshot.describe(), contains('selection: none'));
    expect(snapshot.describe(), isNot(contains('#')));

    final prompt = const DocumentContextBuilder().systemPrompt(
      document: CadDocument(),
      tools: const [],
      session: const SessionSnapshot(
        selectionCount: 2,
        selection: [
          SelectedObjectHint(id: 3, kind: 'line', layer: '0'),
          SelectedObjectHint(
            id: 5,
            kind: 'circle',
            layer: '0',
            bounds: [3, 3, 7, 7],
          ),
        ],
        snapEnabled: false,
        snapModes: ['endpoint'],
        ortho: true,
      ),
    );
    expect(prompt, contains('selection: 2 objects'));
    expect(prompt, contains('#3 line layer=0'));
    expect(prompt, contains('#5 circle'));
    expect(prompt, contains('snap: off (endpoint)'));
    expect(prompt, contains('ortho: on'));
  });

  test('a leftover skill index lists names without dumping the body', () {
    final prompt = const DocumentContextBuilder().systemPrompt(
      document: CadDocument(),
      tools: const [],
      skills: const [
        SkillSummary(
          name: 'inspect-drawing',
          description: 'Inspect the open drawing.',
        ),
      ],
    );
    expect(prompt, contains('inspect-drawing: Inspect the open drawing.'));
    expect(prompt, contains('skill.read'));
    expect(prompt, isNot(contains('Never dump the whole drawing')));
  });
}

extension on CadDocument {
  void editLike(void Function(Transaction transaction) body) {
    final session = DocumentSession(id: 't', document: this);
    session.edit('setup', body);
  }
}
