import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Workspace workspace;

  setUp(() {
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async => path,
        recentFiles: () => const [],
      ),
    );
    workspace.newDocument();
  });

  tearDown(() => workspace.dispose());

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

  test('a two-point circle sits on the diameter midpoint', () async {
    final result = await run('draw.circle2p', {
      'first': [0, 0],
      'second': [10, 0],
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    final circle = workspace.active!.document.entities
        .whereType<CircleEntity>()
        .single;
    expect(circle.center, const Vec2(5, 0));
    expect(circle.radius, closeTo(5, 1e-9));
  });

  test('coincident diameter ends cannot invent a circle', () async {
    final result = await run('draw.circle2p', {
      'first': [2, 2],
      'second': [2, 2],
    });
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('coincide'));
    expect(workspace.active!.document.entityCount, 0);
  });

  test(
    'leftover polyline vertices still draw; empty points fail, not cancel',
    () async {
      final drawn = await run('draw.polyline', {
        'points': {
          'vertices': [
            [0, 0],
            [20, 0],
            [20, 8],
          ],
        },
      });
      expect(drawn.status, CommandStatus.ok, reason: drawn.message);
      expect(
        workspace.active!.document.entities.whereType<PolylineEntity>(),
        hasLength(1),
      );

      final empty = await run('draw.polyline', {'points': <Object?>[]});
      expect(empty.status, CommandStatus.failed);
      expect(empty.message, contains('[[x, y]'));
      expect(empty.status, isNot(CommandStatus.cancelled));
    },
  );

  test('LINE undo drops the last vertex and Close returns to the start', () async {
    final result = await _runScripted(workspace, 'draw.line', const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(10, 10),
      'Undo',
      Vec2(0, 10),
      'Close',
    ]);
    expect(result.status, CommandStatus.ok, reason: result.message);
    final lines = workspace.active!.document.entities
        .whereType<LineEntity>()
        .toList();
    expect(lines, hasLength(3));
    expect(lines[0].start, const Vec2.zero());
    expect(lines[0].end, const Vec2(10, 0));
    expect(lines[1].start, const Vec2(10, 0));
    expect(lines[1].end, const Vec2(0, 10));
    expect(lines[2].start, const Vec2(0, 10));
    expect(lines[2].end, const Vec2.zero());
  });

  test('PLINE Close seals the last vertex back to the first', () async {
    final result = await _runScripted(workspace, 'draw.polyline', const [
      Vec2.zero(),
      Vec2(8, 0),
      Vec2(8, 6),
      'Close',
    ]);
    expect(result.status, CommandStatus.ok, reason: result.message);
    final polyline = workspace.active!.document.entities
        .whereType<PolylineEntity>()
        .single;
    expect(polyline.closed, isTrue);
    expect(polyline.vertexCount, 3);
  });
}

Future<CommandResult> _runScripted(
  Workspace workspace,
  String id,
  List<Object?> answers,
) async {
  final descriptor = workspace.commands.find(id)!;
  return await descriptor.handler(
    CommandContext(
      session: workspace.active!.session,
      args: CommandArgs.empty(),
      input: _ScriptedInput(answers),
      services: workspace,
      commandId: id,
    ),
  );
}

/// Answers point-or-keyword prompts from a script so Undo/Close can be tested
/// without a pointer race.
class _ScriptedInput implements CommandInput {
  _ScriptedInput(this._answers);

  final List<Object?> _answers;
  int _index = 0;
  Vec2? _lastPick;

  Object? _next() => _index < _answers.length ? _answers[_index++] : null;

  @override
  bool get isInteractive => true;

  @override
  bool get isCancelled => false;

  @override
  Vec2? get lastPick => _lastPick;

  @override
  Future<Vec2> point(String message, {Vec2? basePoint}) async {
    final value = await pointOrNull(message, basePoint: basePoint);
    if (value == null) throw const CommandCancelled();
    return value;
  }

  @override
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint}) async {
    final pick = await pointOrKeyword(message, basePoint: basePoint);
    return pick?.point;
  }

  @override
  Future<PointOrKeyword?> pointOrKeyword(
    String message, {
    Vec2? basePoint,
    List<String> keywords = const [],
  }) async {
    final value = _next();
    if (value == null) return null;
    if (value is String) {
      final matched = ArgsCommandInput.matchKeyword(value, keywords);
      return matched == null ? null : PointOrKeyword.keyword(matched);
    }
    if (value is Vec2) {
      _lastPick = value;
      return PointOrKeyword.point(value);
    }
    return null;
  }

  @override
  Future<double> distance(String message, {Vec2? basePoint}) async {
    throw const CommandCancelled();
  }

  @override
  Future<double> angle(String message, {Vec2? basePoint}) async {
    throw const CommandCancelled();
  }

  @override
  Future<double> number(String message, {double? defaultValue}) async {
    throw const CommandCancelled();
  }

  @override
  Future<int> integer(String message, {int? defaultValue}) async {
    throw const CommandCancelled();
  }

  @override
  Future<String> text(String message, {String? defaultValue}) async {
    throw const CommandCancelled();
  }

  @override
  Future<String> keyword(
    String message,
    List<String> options, {
    String? defaultOption,
  }) async {
    throw const CommandCancelled();
  }

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    return defaultValue;
  }

  @override
  Future<List<int>> selection(
    String message, {
    bool useExistingSelection = true,
    bool single = false,
  }) async {
    throw const CommandCancelled();
  }

  @override
  Future<Bounds2> window(String message) async {
    throw const CommandCancelled();
  }

  @override
  void write(String message) {}

  @override
  void status(String message) {}

  @override
  void setPreview(PreviewBuilder? builder) {}

  @override
  void setMarkers(List<Vec2> points) {}
}
