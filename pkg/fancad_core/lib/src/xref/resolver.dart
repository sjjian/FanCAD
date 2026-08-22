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
    final copied = <int>[];
    for (final entity in foreign.activeEntities) {
      final id = host.allocateId();
      remap[entity.id] = id;
      copied.add(transaction.add(entity.withId(id), blockName: name));
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

  static String _nameFromPath(String path) {
    final separator = path.contains(r'\') ? r'\' : '/';
    final base = path.split(separator).last;
    final dot = base.lastIndexOf('.');
    final stem = dot <= 0 ? base : base.substring(0, dot);
    return stem.isEmpty ? 'XREF' : stem.toUpperCase();
  }
}
