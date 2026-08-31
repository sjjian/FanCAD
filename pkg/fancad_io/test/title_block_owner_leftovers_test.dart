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
}
