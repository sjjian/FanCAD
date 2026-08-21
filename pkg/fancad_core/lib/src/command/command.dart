import 'dart:async';

import 'package:meta/meta.dart';

import '../geometry/bounds.dart';
import '../geometry/vector.dart';
import '../model/document.dart';
import '../model/preview.dart';
import '../session/selection.dart';
import '../session/session.dart';
import '../txn/patch.dart';
import '../txn/transaction.dart';
import 'param.dart';

/// How risky a command is, which decides whether an AI turn may run it
/// unattended.
enum CommandRisk {
  /// Reads only. Safe to run without asking.
  readOnly,

  /// Creates or edits geometry. Undoable, so it runs then reports.
  edit,

  /// Deletes data, writes files, or touches settings. Requires confirmation
  /// when the caller is not the user.
  destructive,
}

/// Whether a command is offered to the language model as a tool.
enum AiExposure {
  /// Advertised as a callable tool.
  tool,

  /// Callable, but only after explicit user approval.
  approvalRequired,

  /// Hidden from the model, for example UI-only commands like `zoom.in`.
  hidden,
}

/// The outcome of running a command.
@immutable
class CommandResult {
  const CommandResult({
    required this.status,
    this.message = '',
    this.data,
    this.transaction,
  });

  const CommandResult.ok({this.message = '', this.data})
    : status = CommandStatus.ok,
      transaction = null;

  const CommandResult.cancelled([this.message = 'Cancelled'])
    : status = CommandStatus.cancelled,
      data = null,
      transaction = null;

  const CommandResult.failed(this.message)
    : status = CommandStatus.failed,
      data = null,
      transaction = null;

  final CommandStatus status;
  final String message;

  /// Structured payload. Returned verbatim to plugins and, for AI tool calls,
  /// serialized as the tool result.
  ///
  /// A map rather than a free-form object, because this value has to survive
  /// JSON serialisation on its way to a plugin or a model, and a named field is
  /// the difference between a result the caller can read and one it has to
  /// guess at.
  final Map<String, Object?>? data;

  /// The transaction this command produced, when it changed the drawing.
  final CommittedTransaction? transaction;

  bool get isOk => status == CommandStatus.ok;
  bool get isCancelled => status == CommandStatus.cancelled;
  bool get isFailed => status == CommandStatus.failed;

  CommandResult withTransaction(CommittedTransaction? value) => CommandResult(
    status: status,
    message: message,
    data: data,
    transaction: value,
  );

  Map<String, Object?> toJson() => {
    'status': status.name,
    if (message.isNotEmpty) 'message': message,
    if (data != null) 'data': data,
    if (transaction != null)
      'change': {
        'label': transaction!.label,
        'summary': transaction!.summarize(),
        'added': transaction!.change.added,
        'removed': transaction!.change.removed,
        'modified': transaction!.change.modified,
      },
  };

  @override
  String toString() => 'CommandResult(${status.name}: $message)';
}

enum CommandStatus { ok, cancelled, failed }

/// Raised when the user or the host cancels a running command.
class CommandCancelled implements Exception {
  const CommandCancelled([this.reason = 'Cancelled']);

  final String reason;

  @override
  String toString() => 'CommandCancelled($reason)';
}

/// Supplies command input.
///
/// A command written once against this interface works in all three entry
/// points: interactively at the crosshair, non-interactively from a script or
/// plugin, and as an AI tool call. The implementation decides where a value
/// comes from; the command never knows the difference.
abstract class CommandInput {
  /// Whether prompts can actually reach a user. AI and script callers report
  /// false, which lets a command choose a sensible non-interactive path
  /// instead of hanging.
  bool get isInteractive;

  /// Set when the run was cancelled; long loops should poll it.
  bool get isCancelled;

  /// Picks a point. [basePoint] draws a rubber band from that anchor.
  Future<Vec2> point(String message, {Vec2? basePoint});

  /// Picks a point, returning null instead of throwing when cancelled.
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint});

  /// A length, entered numerically or by picking a second point.
  Future<double> distance(String message, {Vec2? basePoint});

  /// An angle in radians.
  Future<double> angle(String message, {Vec2? basePoint});

  Future<double> number(String message, {double? defaultValue});

  Future<int> integer(String message, {int? defaultValue});

  Future<String> text(String message, {String? defaultValue});

  /// One of [options]. Values are matched case-insensitively by prefix, the
  /// way AutoCAD keyword prompts work.
  Future<String> keyword(String message, List<String> options, {String? defaultOption});

  Future<bool> confirm(String message, {bool defaultValue = false});

  /// Picks entities. Returns the current selection when the caller already has
  /// one and [useExistingSelection] is set.
  Future<List<int>> selection(
    String message, {
    bool useExistingSelection = true,
    bool single = false,
  });

  /// Picks a rectangular window in model space.
  Future<Bounds2> window(String message);

  /// Writes a line to the command history pane.
  void write(String message);

  /// Updates the transient status line without adding history.
  void status(String message);

  /// Installs live feedback for the prompts that follow.
  ///
  /// The builder is called with the resolved cursor position on every pointer
  /// move, which is what lets a command show the rectangle it is about to draw
  /// while still being written as a straight-line script. Non-interactive hosts
  /// ignore it, so a command needs no branch for the AI or scripting case.
  void setPreview(PreviewBuilder? builder);

  /// Extra points to mark, typically the vertices collected so far.
  void setMarkers(List<Vec2> points);
}

/// Host services a command may call: notifications, view control, file dialogs.
///
/// The core declares the interface; the Flutter layer implements it. This is
/// what keeps command implementations testable without a widget tree.
abstract class CommandServices {
  void notify(String message, {bool isError = false});

  /// Fits the view to [bounds], or to the drawing extents when null.
  void zoomTo(Bounds2? bounds);

  /// Multiplies the zoom about the centre of the view.
  void zoomBy(double factor);

  /// Centres the view on a point without changing the zoom.
  void panTo(Vec2 center);

  /// Requests a repaint, for commands that change render state only.
  void invalidate();

  /// Reveals a panel by id, for example `layers` or `properties`.
  void revealPanel(String panelId);

  /// Asks the user to approve a set of pending changes. Returns true when the
  /// caller may proceed. Non-interactive hosts return their default policy.
  Future<bool> requestApproval(String title, String details);

  static const CommandServices none = _NullServices();
}

class _NullServices implements CommandServices {
  const _NullServices();

  @override
  void notify(String message, {bool isError = false}) {}

  @override
  void zoomTo(Bounds2? bounds) {}

  @override
  void zoomBy(double factor) {}

  @override
  void panTo(Vec2 center) {}

  @override
  void invalidate() {}

  @override
  void revealPanel(String panelId) {}

  @override
  Future<bool> requestApproval(String title, String details) async => false;
}

/// Everything a command handler receives.
class CommandContext {
  CommandContext({
    required this.session,
    required this.args,
    required this.input,
    this.services = CommandServices.none,
    this.source = ChangeSource.user,
    this.commandId = '',
  });

  final DocumentSession session;
  final CommandArgs args;
  final CommandInput input;
  final CommandServices services;
  final ChangeSource source;
  final String commandId;

  CadDocument get document => session.document;
  SelectionSet get selection => session.selection;

  /// Runs [body] in a transaction attributed to this command's source.
  CommittedTransaction? edit(
    String label,
    void Function(Transaction transaction) body,
  ) => session.edit(label, body, source: source);

  /// Resolves a point parameter: an explicit argument wins, otherwise the user
  /// is prompted. This ordering is what lets the same command be scripted.
  Future<Vec2> resolvePoint(String name, String prompt, {Vec2? basePoint}) async {
    final provided = args.point(name);
    if (provided != null) return provided;
    return input.point(prompt, basePoint: basePoint);
  }

  Future<double> resolveNumber(
    String name,
    String prompt, {
    double? defaultValue,
  }) async {
    final provided = args.number(name);
    if (provided != null) return provided;
    return input.number(prompt, defaultValue: defaultValue);
  }

  Future<String> resolveText(
    String name,
    String prompt, {
    String? defaultValue,
  }) async {
    final provided = args.text(name);
    if (provided != null && provided.isNotEmpty) return provided;
    return input.text(prompt, defaultValue: defaultValue);
  }

  /// Resolves an entity set: explicit ids, then the current selection, then a
  /// pick prompt.
  Future<List<int>> resolveSelection(
    String name,
    String prompt, {
    bool single = false,
  }) async {
    final provided = args.ids(name);
    if (provided != null && provided.isNotEmpty) return provided;
    if (selection.isNotEmpty) return selection.ids.toList();
    return input.selection(prompt, single: single);
  }
}

/// The handler signature.
typedef CommandHandler =
    FutureOr<CommandResult> Function(CommandContext context);

/// A registered command.
///
/// This single declaration is simultaneously a command palette entry, a
/// command-line verb, a keybinding target, a plugin API surface and an AI tool.
@immutable
class CommandDescriptor {
  const CommandDescriptor({
    required this.id,
    required this.title,
    required this.handler,
    this.category = 'General',
    this.description = '',
    this.params = const [],
    this.aliases = const [],
    this.risk = CommandRisk.edit,
    this.aiExposure = AiExposure.tool,
    this.icon,
    this.defaultKeybinding,
    this.when,
    this.extensionId = '',
    this.repeatable = true,
  });

  /// Dotted, namespaced identifier, for example `draw.line`.
  final String id;

  /// Human-readable name for the palette.
  final String title;

  final CommandHandler handler;
  final String category;

  /// Longer explanation. Doubles as the tool description sent to the model, so
  /// it should read as instructions rather than as UI copy.
  final String description;

  final List<ParamSpec> params;

  /// Command-line abbreviations, mirroring AutoCAD's aliases such as `L` for
  /// line or `CO` for copy.
  final List<String> aliases;

  final CommandRisk risk;
  final AiExposure aiExposure;

  /// Icon identifier resolved by the UI layer.
  final String? icon;

  /// A keybinding such as `ctrl+shift+p`.
  final String? defaultKeybinding;

  /// Context expression that gates availability, for example
  /// `hasSelection && !readOnly`.
  final String? when;

  /// The plugin that contributed this command; empty for built-ins.
  final String extensionId;

  /// Whether pressing Enter on an empty command line repeats it.
  final bool repeatable;

  bool get isBuiltIn => extensionId.isEmpty;

  /// The tool name advertised to the model. Dots are not accepted by some
  /// providers, so they are normalized to underscores.
  String get toolName => id.replaceAll('.', '_').replaceAll('-', '_');

  /// The JSON Schema for this command's parameters.
  Map<String, Object?> toolSchema() => {
    'type': 'object',
    'properties': {
      for (final param in params) param.name: param.toJsonSchema(),
    },
    'required': [
      for (final param in params)
        if (param.required) param.name,
    ],
  };

  /// The full tool definition handed to the LLM provider.
  Map<String, Object?> toToolDefinition() => {
    'name': toolName,
    'description': description.isEmpty ? title : description,
    'parameters': toolSchema(),
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    if (description.isNotEmpty) 'description': description,
    if (aliases.isNotEmpty) 'aliases': aliases,
    'risk': risk.name,
    'params': [
      for (final param in params)
        {
          'name': param.name,
          'type': param.type.name,
          'required': param.required,
          if (param.description.isNotEmpty) 'description': param.description,
          if (param.options.isNotEmpty) 'options': param.options,
        },
    ],
    if (extensionId.isNotEmpty) 'extensionId': extensionId,
  };

  @override
  String toString() => 'CommandDescriptor($id)';
}
