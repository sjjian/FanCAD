import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  group('eachCase', () {
    eachCase([
      (name: 'uses the record name', label: 'named'),
      (name: 'keeps a second row', label: 'again'),
    ], (c) {
      expect(c.label, isNotEmpty);
    });
  });

  group('eachNamed', () {
    eachNamed({
      'map key is the test name': 1,
      'another key': 2,
    }, (value) {
      expect(value, inInclusiveRange(1, 2));
    });
  });

  test('drawing places entities in model space', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    final document = drawing(entities: [line]);
    expect(document.entities, hasLength(1));
    expectOwner(document, document.entities.single, document.modelSpaceBlockName);
  });

  test('drawingOf can target a named block', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    final document = drawingOf(line, blockName: 'PART');
    expectOwner(document, document.entities.single, 'PART');
  });

  test('emit collects a line as one polyline', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(emit(line).polylines, hasLength(1));
  });

  test('closeVec matches nearby points', () {
    expect(const Vec2(1, 2), closeVec(const Vec2(1, 2.0000001)));
  });

  test('tempDir is created and torn down', () {
    final directory = tempDir(prefix: 'fancad-harness');
    expect(directory.existsSync(), isTrue);
  });

  test('docIds counts from one', () {
    final ids = docIds();
    expect(ids.next(), 1);
    expect(ids.next(), 2);
  });
}
