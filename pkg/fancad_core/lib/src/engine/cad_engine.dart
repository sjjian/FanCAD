import '../geometry/bounds.dart';
import '../io/drawing_file_service.dart';
import '../model/document/drawing_data.dart';
import '../model/entity/entity.dart';
import '../presentation/contract/emit.dart';
import 'api.dart';
import 'change.dart';
import 'document.dart';
import 'runtime.dart';
import 'session.dart';

/// The single public entry point for a third-party consumer.
///
/// One [CadEngine] owns one drawing. A host with several open drawings keeps
/// one engine per drawing; the engine itself does not maintain a registry.
///
/// Create an empty drawing with the constructor, or open a file with
/// [CadEngine.open]. Edits go through [EditContext], reads through
/// [EntityQuery] and [EntitySnapshot], and rendering through
/// [GeometrySink]/[EmitRequest]. The mutable document model and the
/// per-drawing session are implementation details.
final class CadEngine {
  CadEngine({String? title}) : this._create(title: title);

  CadEngine._create({
    String? id,
    String? title,
    DrawingFileService files = const DrawingFileService(),
  }) : this._(
         DocumentSession(id: id ?? '${_nextId++}', document: CadDocument()),
         const [],
         files,
         title,
         null,
       );

  CadEngine._fromDocument(
    DrawingData document, {
    String? id,
    String? title,
    String? filePath,
    List<String> diagnostics = const [],
    DrawingFileService files = const DrawingFileService(),
  }) : this._(
         DocumentSession(
           id: id ?? '${_nextId++}',
           document: CadDocument.fromData(document),
         ),
         List.unmodifiable(diagnostics),
         files,
         title,
         filePath,
       );

  CadEngine._(
    this._session,
    this._diagnostics,
    this._files,
    this._title,
    this.filePath,
  );

  static int _nextId = 1;

  final DocumentSession _session;
  DrawingView? _view;
  final List<String> _diagnostics;
  final DrawingFileService _files;

  String? _title;

  /// File the drawing was opened from or last saved to.
  String? filePath;

  /// Opens [path] into a new engine.
  static Future<CadEngine> open(String path) =>
      _openWith(const DrawingFileService(), path);

  static Future<CadEngine> _openWith(
    DrawingFileService files,
    String path,
  ) async {
    final opened = await files.open(path);
    return CadEngine._(
      DocumentSession(
        id: '${_nextId++}',
        document: CadDocument.fromData(opened.document),
      ),
      List.unmodifiable(opened.diagnostics),
      files,
      null,
      path,
    );
  }

  String get title {
    if (_title != null) return _title!;
    final path = filePath?.trim();
    if (path == null || path.isEmpty) return 'Drawing${_session.id}';
    final separator = path.contains(r'\') ? r'\' : '/';
    final name = path.split(separator).last;
    // A trailing slash, or a path that is only whitespace, must not leave the
    // tab strip with an empty label.
    return name.isEmpty ? 'Drawing${_session.id}' : name;
  }

  set title(String value) => _title = value;

  bool get isDirty => _session.isDirty;
  int get version => _session.document.version;
  Bounds2 get extents => _session.document.extents;
  List<String> get diagnostics => _diagnostics;

  List<String> get layers => [
    for (final layer in _session.document.layers.keys) layer,
  ];

  List<String> get layouts => [
    for (final layout in _session.document.layouts) layout.name,
  ];

  String get activeLayout => _session.document.activeLayoutName;

  /// Read-only view of the drawing.
  DrawingView get drawing => _view ??= EngineDrawingView(_session);

  /// One entity by id, or null when it does not exist.
  Entity? entity(EntityId id) => drawing.entity(id);

  /// Every entity in the drawing.
  Iterable<Entity> get entities => drawing.entities;

  /// Committed changes. Undo and redo also emit here.
  Stream<EngineChange> get changes => _session.changes.map(_change);

  Future<SaveResult> save(String path, {String? format}) async {
    var target = path;
    final wanted = format?.trim().toLowerCase().replaceFirst('.', '');
    if (wanted != null &&
        wanted.isNotEmpty &&
        !target.toLowerCase().endsWith('.$wanted')) {
      target = '$target.$wanted';
    }
    final saved = await _files.save(target, _session.document);
    markSaved(saved.path);
    return SaveResult(
      path: saved.path,
      usedFallback: saved.usedFallback,
      reason: saved.reason,
    );
  }

  /// Records that the host wrote this drawing to [path].
  void markSaved(String path) {
    filePath = path;
    // Untitled tabs keep an explicit label such as Drawing1. Once there is a
    // file, the tab should follow that name, including after Save As.
    _title = null;
    _session.markSaved();
  }

  void dispose() => _session.dispose();

  EditResult edit(
    void Function(EditContext context) body, {
    String label = 'Edit',
  }) {
    final committed = _session.edit(
      label,
      (transaction) => body(EngineEditContext(transaction)),
    );
    if (committed == null) return EditResult(label: label);
    return EditResult(
      label: committed.label,
      added: committed.change.added,
      removed: committed.change.removed,
      modified: committed.change.modified,
      tablesChanged: committed.change.tablesChanged,
      structureChanged: committed.change.structureChanged,
    );
  }

  bool undo() => _session.undo();

  bool redo() => _session.redo();

  bool setActiveLayout(String name) {
    if (!_session.document.layouts.any((layout) => layout.name == name)) {
      return false;
    }
    final committed = _session.edit(
      'Set layout',
      (transaction) => transaction.setActiveLayout(name),
    );
    return committed != null;
  }

  EntityQueryResult query([EntityQuery query = const EntityQuery()]) =>
      EngineQueryRunner.run(_session, query);

  /// Emits the visible geometry of one layout into [sink].
  ///
  /// Paper-space model windows are emitted through their viewport transform.
  /// Text measurement and SHX resources are not part of the public contract;
  /// callers that need exact text should use the advanced API.
  void emit(GeometrySink sink, {EmitRequest request = const EmitRequest()}) =>
      EngineEmitter.emit(_session, sink, request);

  static EngineChange _change(DocumentChange change) => EngineChange(
    added: change.added,
    removed: change.removed,
    modified: change.modified,
    tablesChanged: change.tablesChanged,
    structureChanged: change.structureChanged,
  );
}

/// First-party helpers for creating an engine from an already loaded document.
///
/// Part of the public entry while the application migrates off the wide
/// internal barrel; the high-level [CadEngine] facade stays the preferred path.
final class AdvancedCadEngine {
  const AdvancedCadEngine._();

  /// Creates an empty drawing with an application-owned session id.
  static CadEngine create({
    String? id,
    String? title,
    DrawingFileService files = const DrawingFileService(),
  }) => CadEngine._create(id: id, title: title, files: files);

  /// Wraps a document that was already loaded by the host.
  static CadEngine fromDocument(
    DrawingData document, {
    String? id,
    String? title,
    String? filePath,
    List<String> diagnostics = const [],
    DrawingFileService files = const DrawingFileService(),
  }) => CadEngine._fromDocument(
    document,
    id: id,
    title: title,
    filePath: filePath,
    diagnostics: diagnostics,
    files: files,
  );

  /// Opens [path] with the host's file service.
  static Future<CadEngine> openWith(DrawingFileService files, String path) =>
      CadEngine._openWith(files, path);
}

/// First-party view of the mutable session behind a [CadEngine].
extension CadEngineAdvanced on CadEngine {
  DocumentSession get session => _session;
}
