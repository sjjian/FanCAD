@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// A Chinese R2004 process drawing from the HunterDouglas sample set.
/// CI does not ship it; the test is skipped when the file is absent.
const String _sample = '/Users/sunjian/Downloads/亨特道格拉斯/案例2/'
    'SOAS00002617---QC50+25mm+U型槽/工艺 -SOAS00002617.dwg';

void main() {
  test('a title-block INSERT is not stolen by an overlapping *D list', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final opened = await DrawingImporter().open(_sample);
    final document = opened.document;

    MTextEntity? label;
    for (final entity in document.entities) {
      if (entity is MTextEntity && entity.plainText.contains('XDFB-J15')) {
        label = entity;
        break;
      }
    }
    expect(label, isNotNull);

    final covers = [
      for (final entity in document.entitiesOf(document.modelSpaceBlockName))
        if (entity is InsertEntity && entity.blockName == 'bk')
          if (document
              .boundsOfEntity(entity)
              .containsPoint(label!.position.x, label.position.y))
            entity,
    ];
    expect(covers, isNotEmpty);
    expect(document.ownerOf(covers.first.id), document.modelSpaceBlockName);

    for (final entity in document.entities) {
      if (entity is! InsertEntity || entity.blockName != 'bk') continue;
      final owner = document.ownerOf(entity.id) ?? '';
      expect(owner.startsWith('*D'), isFalse);
    }
  });

  test('序号 24 title text is covered by a model-space bk INSERT', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    MTextEntity? label;
    for (final entity in document.entities) {
      if (entity is MTextEntity &&
          RegExp(r'序号：24(?!\d)').hasMatch(entity.plainText)) {
        label = entity;
        break;
      }
    }
    expect(label, isNotNull, reason: 'the sheet title for 序号 24 is in the file');
    final covers = [
      for (final entity in document.entitiesOf(document.modelSpaceBlockName))
        if (entity is InsertEntity && entity.blockName == 'bk')
          if (document
              .boundsOfEntity(entity)
              .containsPoint(label!.position.x, label.position.y))
            entity,
    ];
    expect(
      covers,
      isNotEmpty,
      reason: 'J24\'s bk INSERT shares a handle with a *D arrow; '
          'the later row is still the title frame',
    );
  });

  test('a sheet-number MTEXT is not dropped when its handle collides',
      () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    Vec2? at(String id) {
      final needle = RegExp('XDFB-$id(?!\\d)');
      for (final entity in document.entities) {
        final text = entity is MTextEntity
            ? entity.plainText
            : entity is TextEntity
            ? entity.content
            : null;
        if (text == null || !needle.hasMatch(text)) continue;
        return entity is MTextEntity
            ? entity.position
            : (entity as TextEntity).position;
      }
      return null;
    }

    final j104 = at('J104');
    final j105 = at('J105');
    final j106 = at('J106');
    expect(j104, isNotNull);
    expect(j106, isNotNull);
    expect(
      j105,
      isNotNull,
      reason: 'XDFB-J105 sits in the title box between J104 and J106; '
          'a later MTEXT row on a colliding handle is still that '
          'sheet number',
    );
    expect(j105!.x, greaterThan(j104!.x));
    expect(j105.x, lessThan(j106!.x));
  });

  test('a *D list does not steal model-space leaders or hatches', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final stolen = <String>[];
    var modelLeaders = 0;
    for (final entity in document.entities) {
      final owner = document.ownerOf(entity.id) ?? '';
      if (entity is MLeaderEntity &&
          owner == document.modelSpaceBlockName) {
        modelLeaders++;
      }
      if (!owner.startsWith('*D')) continue;
      if (entity is MLeaderEntity || entity is HatchEntity) {
        stolen.add('${entity.kind}#${entity.id}@$owner');
      }
    }
    expect(modelLeaders, greaterThan(0));
    expect(stolen, isEmpty, reason: stolen.join(', '));
  });

  test('orphaned *D headers cannot hide model-space drawing runs', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final referenced = <String>{
      for (final entity in document.entities)
        if (entity is DimensionEntity && entity.blockName.isNotEmpty)
          entity.blockName,
    };
    final hidden = [
      for (final entity in document.entities)
        if ((document.ownerOf(entity.id) ?? '').startsWith('*D') &&
            !referenced.contains(document.ownerOf(entity.id)))
          '${entity.kind}#${entity.id}@${document.ownerOf(entity.id)}',
    ];
    expect(hidden, isEmpty, reason: hidden.take(30).join(', '));
    expect(
      document.entitiesOf(document.modelSpaceBlockName).length,
      greaterThan(37000),
      reason: 'the two profile columns and their frame belong in model space',
    );
  });

  test('a part-scale edge is not left hanging on a *D block', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final stolen = <CadEntity>[];
    for (final entity in document.entities) {
      if (entity is! LineEntity &&
          entity is! PolylineEntity &&
          entity is! TextEntity) {
        continue;
      }
      final owner = document.ownerOf(entity.id) ?? '';
      if (!owner.startsWith('*D')) continue;
      // A 50–80k span is still a plausible dimension on this millimetre
      // process sheet. Title-frame edges are an order larger.
      if (document.boundsOfEntity(entity).diagonal < 200000) continue;
      stolen.add(entity);
    }
    expect(
      stolen,
      isEmpty,
      reason: stolen
          .map(
            (entity) =>
                '${entity.kind}#${entity.id} owner=${document.ownerOf(entity.id)} '
                'span=${document.boundsOfEntity(entity).diagonal}',
          )
          .join(', '),
    );
  });

  test('a referenced *D block cannot keep a part-scale profile edge', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    const profileLayers = {
      '折边线',
      '角码孔',
      'ATT',
      '1金属板竖分格线',
      '细实线',
      '编号',
      'xc',
      '问号',
      '虚线',
    };
    const dimLayers = {'dim', '标注', '标注线'};
    final stolen = <String>[];
    for (final entity in document.entities) {
      final owner = document.ownerOf(entity.id) ?? '';
      if (!owner.startsWith('*D')) continue;
      if (profileLayers.contains(entity.props.layer)) {
        stolen.add('${entity.kind}#${entity.id}@$owner ${entity.props.layer}');
        continue;
      }
      if (entity is! LineEntity && entity is! PolylineEntity) continue;
      if (dimLayers.contains(entity.props.layer)) continue;
      if (document.boundsOfEntity(entity).diagonal < 50) continue;
      stolen.add(
        '${entity.kind}#${entity.id}@$owner ${entity.props.layer} '
        'span=${document.boundsOfEntity(entity).diagonal.toStringAsFixed(0)}',
      );
    }
    expect(stolen, isEmpty, reason: stolen.take(20).join(', '));
  });

  test('a named layer cannot keep a ByLayer colour', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final sentinels = [
      for (final layer in document.layers.values)
        if (layer.color.kind == ColorKind.byLayer ||
            layer.color.kind == ColorKind.byBlock)
          '${layer.name}=${layer.color}',
    ];
    expect(sentinels, isEmpty, reason: sentinels.join(', '));
  });

  test('a R2004 layer CMC low byte is an ACI, not RGB(0,0,n)', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    expect(document.layers['折边线']?.color, const CadColor.indexed(213));
    expect(document.layers['角码孔']?.color, const CadColor.indexed(1));
    expect(document.layers['细实线']?.color, const CadColor.indexed(2));
    expect(document.layers['ATT']?.color, const CadColor.indexed(3));
    expect(document.layers['标注']?.color, const CadColor.indexed(4));
  });

  test('J18 板2 slotting view keeps its white outline', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final outlines = <String>[];
    for (final entity in document.entitiesOf(document.modelSpaceBlockName)) {
      if (entity is! LineEntity &&
          entity is! PolylineEntity &&
          entity is! UnknownEntity) {
        continue;
      }
      if (entity.props.layer == 'dim' || entity.props.layer == '标注') {
        continue;
      }
      final box = document.boundsOfEntity(entity);
      if (box.maxX < 209760 || box.minX > 209800) continue;
      if (box.height < 1500) continue;
      outlines.add(
        '${entity.kind}#${entity.id} ${entity.props.layer} '
        'h=${box.height.toStringAsFixed(0)}',
      );
    }
    expect(
      outlines,
      isNotEmpty,
      reason: 'J18 板2 right edge at x≈209764–209784 '
          '(LibreDWG reused that handle on a *D arrow)',
    );
  });

  test('an INSERT with extrusion (0,0,-1) stays on the sheet strip', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final leaked = <String>[];
    for (final entity in document.entitiesOf(document.modelSpaceBlockName)) {
      if (entity is! InsertEntity || entity.position.x >= 0) continue;
      final box = document.boundsOfEntity(entity);
      if (!box.isFinite || box.width >= 100 || box.height >= 100) continue;
      leaked.add(
        '${entity.blockName}@${entity.position.x.toStringAsFixed(0)}',
      );
    }
    expect(leaked, isEmpty, reason: '${leaked.length} mirrored-OCS inserts');
  });

  test('a compact insert far from the sheet strip is still imported',
      () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final kept = [
      for (final entity in document.entitiesOf(document.modelSpaceBlockName))
        if (entity is InsertEntity &&
            !entity.blockName.startsWith('*') &&
            !entity.blockName.startsWith('_') &&
            entity.position.y > 300000)
          '${entity.blockName}@${entity.position.x.toStringAsFixed(0)},'
          '${entity.position.y.toStringAsFixed(0)}',
    ];
    expect(
      kept,
      isNotEmpty,
      reason: '浩辰 keeps a compact JL-01A at y≈358556; isolation is not '
          'a reason to drop it',
    );
  });

  test('a colliding handle does not invent a second entity', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final handles = [
      for (final entity in document.entitiesOf(document.modelSpaceBlockName))
        if (entity.id < (1 << 40)) entity.id,
    ];
    expect(handles.toSet().length, handles.length);
    final leaked = [
      for (final entity in document.entitiesOf(document.modelSpaceBlockName))
        if (entity is PointEntity && entity.id > (1 << 40)) entity.id,
    ];
    expect(leaked, isEmpty, reason: '${leaked.length} synthetic POINTs');
  });

  test('an ACAD arrow definition stays arrow-sized', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final box = document.boundsOf('_Oblique');
    expect(box.isFinite, isTrue);
    expect(
      box.width < 100 && box.height < 100,
      isTrue,
      reason: '_Oblique ${box.width.toStringAsFixed(0)}x'
          '${box.height.toStringAsFixed(0)}',
    );
  });

  test('a dimension box is the tick geometry, not a million-unit leftover',
      () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final entity = _dimensionNear(
      document,
      measurement: 527.1,
      textX: 348183,
    );
    expect(entity, isA<DimensionEntity>());
    final box = document.boundsOfEntity(entity);
    expect(box.isFinite, isTrue);
    expect(
      box.width < 2000 && box.height < 2000,
      isTrue,
      reason: '527.1 dim ${box.width.toStringAsFixed(0)}x'
          '${box.height.toStringAsFixed(0)}',
    );
  });

  test('two DIMENSION entities do not share one *D block', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final document = (await DrawingImporter().open(_sample)).document;
    final a = _dimensionNear(document, measurement: 432.9, textX: 305);
    final b = _dimensionNear(document, measurement: 527.1, textX: 348183);
    expect(a, isA<DimensionEntity>());
    expect(b, isA<DimensionEntity>());
    expect(a.blockName, isNotEmpty);
    expect(
      b.blockName,
      isNot(a.blockName),
      reason: 'the 527.1 dim collided onto the 432.9 *D; the later '
          'dimension must not redraw those ticks at the origin',
    );
    final names = <String, int>{};
    for (final entity in document.entitiesOf(document.modelSpaceBlockName)) {
      if (entity is! DimensionEntity || entity.blockName.isEmpty) continue;
      names.update(entity.blockName, (v) => v + 1, ifAbsent: () => 1);
    }
    final shared = [
      for (final e in names.entries)
        if (e.value > 1) '${e.key}×${e.value}',
    ];
    expect(shared, isEmpty, reason: shared.join(', '));
  });
}

DimensionEntity _dimensionNear(
  CadDocument document, {
  required double measurement,
  required double textX,
}) {
  for (final entity in document.entities) {
    if (entity is DimensionEntity &&
        (entity.measurement - measurement).abs() < 0.2 &&
        (entity.textPosition.x - textX).abs() < 2) {
      return entity;
    }
  }
  fail('no DIMENSION with meas $measurement near x=$textX');
}
