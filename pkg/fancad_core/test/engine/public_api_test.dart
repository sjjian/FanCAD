import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('entities, drawing view and changes are public objects', () async {
    final engine = CadEngine();
    addTearDown(engine.dispose);
    final changes = <EngineChange>[];
    final subscription = engine.changes.listen(changes.add);
    addTearDown(subscription.cancel);

    engine.edit((context) {
      final id = context.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 0)),
      );
      final line = engine.entity(id) as LineEntity;
      context.replace(
        LineEntity(id: line.id, start: line.start, end: const Vec2(2, 0)),
      );
    });

    final line = engine.drawing.entities.single as LineEntity;
    expect(line.end.x, 2);
    expect(engine.drawing.entity(line.id), same(line));
    expect(
      engine.drawing.entitiesIn(Bounds2.fromCorners(Vec2.zero(), Vec2(1, 1))),
      isNotEmpty,
    );
    expect(changes, isNotEmpty);
    expect(changes.last.modified, contains(line.id));
  });

  test(
    'a consumer can create, edit, query, undo and save through an engine',
    () {
      final engine = CadEngine(title: 'API');
      addTearDown(engine.dispose);

      final edited = engine.edit((context) {
        context.addEntity(const LineSpec(start: Vec2(0, 0), end: Vec2(10, 0)));
        context.addEntity(const CircleSpec(center: Vec2(5, 5), radius: 2));
      });

      expect(edited.added, hasLength(2));
      expect(engine.query().entities, hasLength(2));

      engine.edit((context) {
        context.transform([2], Mat3.translation(10, 0));
      });

      final circle =
          engine
                  .query(const EntityQuery(kinds: {EntityKind.circle}))
                  .entities
                  .single
              as CircleEntity;
      expect(circle.center.x, closeTo(15, 1e-9));

      expect(engine.undo(), isTrue);
      expect(engine.redo(), isTrue);

      final directory = Directory.systemTemp.createTempSync('fancad-api');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final path = '${directory.path}/api.dxf';

      return engine.save(path).then((saved) async {
        expect(saved.usedFallback, isFalse);
        expect(engine.isDirty, isFalse);

        final reopened = await CadEngine.open(saved.path);
        addTearDown(reopened.dispose);
        expect(reopened.query().entities, hasLength(2));
      });
    },
  );
}
