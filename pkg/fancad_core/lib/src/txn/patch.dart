import 'package:meta/meta.dart';

import '../model/document.dart';
import '../model/entity.dart';
import '../model/style.dart';

/// Who produced a change. Surfaced in the undo list and used to decide whether
/// a change needs user approval before it is applied.
enum ChangeSource {
  /// Direct interaction: a tool, a grip drag, a property edit.
  user,

  /// A command invoked from the command line or command palette.
  command,

  /// Code running inside a plugin.
  plugin,

  /// An AI agent turn.
  ai,

  /// Reading a file. Never recorded on the undo stack.
  importer,
}

/// The smallest unit of document mutation.
///
/// Every patch knows how to apply itself and how to build its own inverse.
/// This is what makes undo, AI change previews and plugin sandboxing share one
/// mechanism: a preview is a patch list that has not been applied yet, and undo
/// is the inverted list.
@immutable
sealed class Patch {
  const Patch();

  /// Mutates [document] and reports what moved.
  DocumentChange applyTo(CadDocument document);

  /// The patch that undoes this one. Must be computed *before* [applyTo] runs,
  /// because it captures the prior state.
  Patch inverse(CadDocument document);

  /// A short human-readable description, used by the undo list and by the AI
  /// change preview.
  String describe();
}

/// Adds an entity at a specific position in a block's draw order.
final class AddEntityPatch extends Patch {
  const AddEntityPatch({
    required this.entity,
    required this.blockName,
    this.index,
  });

  final CadEntity entity;
  final String blockName;
  final int? index;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.insertEntity(entity, blockName: blockName, index: index);
    return DocumentChange(added: [entity.id]);
  }

  @override
  Patch inverse(CadDocument document) => RemoveEntityPatch(
    entity: entity,
    blockName: blockName,
    index: index,
  );

  @override
  String describe() => 'Add ${entity.kind.name}';
}

/// Removes an entity, remembering enough to put it back exactly.
final class RemoveEntityPatch extends Patch {
  const RemoveEntityPatch({
    required this.entity,
    required this.blockName,
    this.index,
  });

  final CadEntity entity;
  final String blockName;
  final int? index;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.removeEntity(entity.id);
    return DocumentChange(removed: [entity.id]);
  }

  @override
  Patch inverse(CadDocument document) => AddEntityPatch(
    entity: entity,
    blockName: blockName,
    index: index,
  );

  @override
  String describe() => 'Erase ${entity.kind.name}';
}

/// Replaces an entity with a new version of itself.
final class ModifyEntityPatch extends Patch {
  const ModifyEntityPatch({required this.before, required this.after});

  final CadEntity before;
  final CadEntity after;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.replaceEntity(after);
    return DocumentChange(modified: [after.id]);
  }

  @override
  Patch inverse(CadDocument document) =>
      ModifyEntityPatch(before: after, after: before);

  @override
  String describe() => before.props == after.props
      ? 'Modify ${after.kind.name}'
      : 'Change properties of ${after.kind.name}';
}

/// Creates or updates a layer definition.
final class PutLayerPatch extends Patch {
  const PutLayerPatch(this.layer);

  final LayerDef layer;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.putLayer(layer);
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) {
    final previous = document.layer(layer.name);
    return previous == null
        ? RemoveLayerPatch(layer.name, layer)
        : PutLayerPatch(previous);
  }

  @override
  String describe() => 'Layer "${layer.name}"';
}

/// Deletes a layer definition.
final class RemoveLayerPatch extends Patch {
  const RemoveLayerPatch(this.name, this.previous);

  final String name;
  final LayerDef previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.removeLayer(name);
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => PutLayerPatch(previous);

  @override
  String describe() => 'Delete layer "$name"';
}

/// Creates or updates a line type definition.
final class PutLineTypePatch extends Patch {
  const PutLineTypePatch(this.lineType, this.previous);

  final LineTypeDef lineType;
  final LineTypeDef? previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.putLineType(lineType);
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => PutLineTypePatch(
    previous ?? LineTypeDef(name: lineType.name),
    lineType,
  );

  @override
  String describe() => 'Line type "${lineType.name}"';
}

/// Creates or updates a text style definition.
final class PutTextStylePatch extends Patch {
  const PutTextStylePatch(this.style, this.previous);

  final TextStyleDef style;
  final TextStyleDef? previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.putTextStyle(style);
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) =>
      PutTextStylePatch(previous ?? TextStyleDef(name: style.name), style);

  @override
  String describe() => 'Text style "${style.name}"';
}

/// Creates or updates a block definition.
final class PutBlockPatch extends Patch {
  const PutBlockPatch(this.block, this.previous);

  final BlockRecord block;
  final BlockRecord? previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.putBlock(block);
    return const DocumentChange(structureChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => previous == null
      ? RemoveBlockPatch(block.name, block)
      : PutBlockPatch(previous!, block);

  @override
  String describe() => 'Block "${block.name}"';
}

/// Deletes a block definition together with the entities it owns.
final class RemoveBlockPatch extends Patch {
  const RemoveBlockPatch(this.name, this.previous, {this.entities = const []});

  final String name;
  final BlockRecord previous;
  final List<CadEntity> entities;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.removeBlock(name);
    return DocumentChange(
      removed: previous.entityIds,
      structureChanged: true,
    );
  }

  @override
  Patch inverse(CadDocument document) =>
      RestoreBlockPatch(previous, entities);

  @override
  String describe() => 'Delete block "$name"';
}

/// Puts back a block and every entity it owned.
final class RestoreBlockPatch extends Patch {
  const RestoreBlockPatch(this.block, this.entities);

  final BlockRecord block;
  final List<CadEntity> entities;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.putBlock(block.copyWith(entityIds: const []));
    for (final entity in entities) {
      document.insertEntity(entity, blockName: block.name);
    }
    return DocumentChange(
      added: entities.map((entity) => entity.id).toList(),
      structureChanged: true,
    );
  }

  @override
  Patch inverse(CadDocument document) =>
      RemoveBlockPatch(block.name, block, entities: entities);

  @override
  String describe() => 'Restore block "${block.name}"';
}

/// Sets a header variable such as `$LTSCALE` or `$INSUNITS`.
final class HeaderVariablePatch extends Patch {
  const HeaderVariablePatch(this.key, this.value, this.previous);

  final String key;
  final String value;
  final String? previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.setHeaderVariable(key, value);
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) =>
      HeaderVariablePatch(key, previous ?? '', value);

  @override
  String describe() => 'Set $key = $value';
}

/// Switches the active layout tab.
/// Changes the layer that new entities are created on.
///
/// Patched rather than set directly so that undoing a "new layer" command also
/// puts the current layer back; otherwise undo would leave the drawing pointing
/// at a layer that no longer exists.
final class CurrentLayerPatch extends Patch {
  const CurrentLayerPatch(this.name, this.previous);

  final String name;
  final String previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.currentLayer = name;
    return const DocumentChange(tablesChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => CurrentLayerPatch(previous, name);

  @override
  String describe() => 'Set current layer to "$name"';
}

final class ActiveLayoutPatch extends Patch {
  const ActiveLayoutPatch(this.name, this.previous);

  final String name;
  final String previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.setActiveLayout(name);
    return const DocumentChange(structureChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => ActiveLayoutPatch(previous, name);

  @override
  String describe() => 'Switch to layout "$name"';
}

/// Creates or replaces a layout tab.
final class PutLayoutPatch extends Patch {
  const PutLayoutPatch(this.layout);

  final Layout layout;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.addLayout(layout);
    return const DocumentChange(structureChanged: true);
  }

  @override
  Patch inverse(CadDocument document) {
    for (final existing in document.layouts) {
      if (existing.name == layout.name) {
        return PutLayoutPatch(existing);
      }
    }
    return RemoveLayoutPatch(layout);
  }

  @override
  String describe() => 'Layout "${layout.name}"';
}

/// Drops a paper layout tab.
final class RemoveLayoutPatch extends Patch {
  const RemoveLayoutPatch(this.previous);

  final Layout previous;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.removeLayout(previous.name);
    return const DocumentChange(structureChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => PutLayoutPatch(previous);

  @override
  String describe() => 'Delete layout "${previous.name}"';
}

/// Renames a block definition. Inserts are updated by separate entity patches.
final class RenameBlockPatch extends Patch {
  const RenameBlockPatch(this.from, this.to);

  final String from;
  final String to;

  @override
  DocumentChange applyTo(CadDocument document) {
    document.renameBlock(from, to);
    return const DocumentChange(structureChanged: true);
  }

  @override
  Patch inverse(CadDocument document) => RenameBlockPatch(to, from);

  @override
  String describe() => 'Rename block "$from" to "$to"';
}
