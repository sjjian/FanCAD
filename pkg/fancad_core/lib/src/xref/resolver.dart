import '../geometry/vector.dart';
import '../model/document.dart';
import '../model/entity.dart';
import '../txn/transaction.dart';

/// How an external drawing is brought into this one.
///
/// The host supplies the loaded document; this class remaps ids and installs
/// the foreign model space as a block with [BlockRecord.xrefPath] set. That
/// is what makes RELOAD possible: the block is identified by path, not by
/// the ids it happened to have last time.
class XrefResolver {
  const XrefResolver();

  /// Attaches [foreign] as an xref named [blockName].
  ///
  /// Existing entities of that name are replaced so a reload is the same
  /// operation as a first attach. Ids are remapped so they cannot collide
  /// with anything already in [host]. A first attach also places one
  /// [InsertEntity] in model space so the reference is visible; a reload
  /// keeps the inserts that already point at the block.
  String attach({
    required CadDocument host,
    required CadDocument foreign,
    required String path,
    String? blockName,
    Vec2 at = const Vec2.zero(),
    required Transaction transaction,
  }) {
    final name = blockName ?? _nameFromPath(path);
    final existing = host.blocks[name];
    if (existing != null) {
      for (final id in existing.entityIds.toList()) {
        transaction.erase(id);
      }
    }

    final remap = <int, int>{};
    final staged = <CadEntity>[];
    for (final entity in foreign.activeEntities) {
      final id = host.allocateId();
      remap[entity.id] = id;
      staged.add(entity.withId(id));
    }
    final copied = <int>[];
    for (final entity in staged) {
      copied.add(
        transaction.add(entity.remappedIds(remap), blockName: name),
      );
    }

    transaction.putBlock(
      BlockRecord(
        name: name,
        entityIds: copied,
        xrefPath: path,
        description: 'Xref $path',
      ),
    );

    final key = name.toUpperCase();
    final model = host.modelSpaceBlockName;
    final hasInsert = host.entitiesOf(model).any(
      (entity) =>
          entity is InsertEntity && entity.blockName.toUpperCase() == key,
    );
    if (!hasInsert) {
      transaction.add(
        InsertEntity(id: 0, blockName: name, position: at),
        blockName: model,
      );
    }
    return name;
  }

  /// Erases every insert of [name] and drops the xref block.
  bool detach({
    required CadDocument host,
    required String name,
    required Transaction transaction,
  }) {
    final needle = name.toLowerCase();
    BlockRecord? block;
    for (final item in host.blocks.values) {
      if (item.isXref && item.name.toLowerCase() == needle) {
        block = item;
        break;
      }
    }
    if (block == null) return false;
    final key = block.name.toUpperCase();
    for (final entity in host.entities.toList()) {
      if (entity is InsertEntity && entity.blockName.toUpperCase() == key) {
        transaction.erase(entity.id);
      }
    }
    return transaction.removeBlock(block.name);
  }

  /// Turns an xref into a local block. Inserts stay; the file path is dropped
  /// so reload and detach no longer apply.
  bool bind({
    required CadDocument host,
    required String name,
    required Transaction transaction,
  }) {
    final needle = name.toLowerCase();
    BlockRecord? block;
    for (final item in host.blocks.values) {
      if (item.isXref && item.name.toLowerCase() == needle) {
        block = item;
        break;
      }
    }
    if (block == null) return false;
    transaction.putBlock(
      block.copyWith(
        xrefPath: '',
        description: 'Bound ${block.name}',
      ),
    );
    return true;
  }

  static String _nameFromPath(String path) {
    final separator = path.contains(r'\') ? r'\' : '/';
    final base = path.split(separator).last;
    final dot = base.lastIndexOf('.');
    final stem = dot <= 0 ? base : base.substring(0, dot);
    return stem.isEmpty ? 'XREF' : stem.toUpperCase();
  }
}
