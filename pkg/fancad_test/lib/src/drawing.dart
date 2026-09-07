import 'package:fancad_core/fancad_core.dart';

/// A document with optional table rows and entities.
///
/// [entities] go to model space. [owned] maps a block name to members and
/// creates the block if needed.
CadDocument drawing({
  Iterable<CadEntity> entities = const [],
  Iterable<LayerDef> layers = const [],
  Iterable<LineTypeDef> lineTypes = const [],
  Iterable<TextStyleDef> textStyles = const [],
  Iterable<DimStyleDef> dimStyles = const [],
  Iterable<BlockRecord> blocks = const [],
  Map<String, Iterable<CadEntity>> owned = const {},
}) {
  final document = CadDocument();
  for (final layer in layers) {
    document.putLayer(layer);
  }
  for (final lineType in lineTypes) {
    document.putLineType(lineType);
  }
  for (final style in textStyles) {
    document.putTextStyle(style);
  }
  for (final style in dimStyles) {
    document.putDimStyle(style);
  }
  for (final block in blocks) {
    document.putBlock(block);
  }
  for (final entity in entities) {
    document.addEntity(entity);
  }
  for (final entry in owned.entries) {
    for (final entity in entry.value) {
      document.addEntity(entity, blockName: entry.key);
    }
  }
  return document;
}

/// A document that holds a single [entity].
CadDocument drawingOf(CadEntity entity, {String? blockName}) {
  if (blockName == null) return drawing(entities: [entity]);
  return drawing(owned: {blockName: [entity]});
}
