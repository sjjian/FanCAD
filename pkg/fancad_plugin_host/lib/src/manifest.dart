import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

/// Raised when a plugin manifest is missing, malformed or contradictory.
///
/// The message is shown verbatim in the extensions panel, so it names the field
/// at fault rather than describing the failure in the abstract.
class ManifestException implements Exception {
  const ManifestException(this.message, {this.path = ''});

  final String message;

  /// Where the manifest came from, when known.
  final String path;

  @override
  String toString() =>
      path.isEmpty ? 'ManifestException: $message' : '$path: $message';
}

/// A capability a plugin must ask for up front.
///
/// The point is not to sandbox a determined attacker — a plugin that can write
/// geometry can already ruin a drawing. It is to make the reach of a plugin
/// legible before it runs, which matters most for the extensions an AI turn
/// writes on the fly.
enum PluginPermission {
  /// Read the document model and the selection.
  documentRead,

  /// Create, modify or erase entities.
  documentWrite,

  /// Read files under the plugin's own directory.
  fileRead,

  /// Write files under the plugin's own storage directory.
  fileWrite,

  /// Reach the network.
  network,

  /// Run other commands, including built-ins.
  commands,

  /// Contribute panels and other UI.
  ui;

  static PluginPermission? parse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('_', '.');
    return switch (normalized) {
      'document.read' => documentRead,
      'document.write' => documentWrite,
      'file.read' || 'fs.read' => fileRead,
      'file.write' || 'fs.write' => fileWrite,
      'network' || 'net' => network,
      'commands' || 'command.execute' => commands,
      'ui' => ui,
      _ => null,
    };
  }

  String get wireName => switch (this) {
    documentRead => 'document.read',
    documentWrite => 'document.write',
    fileRead => 'file.read',
    fileWrite => 'file.write',
    network => 'network',
    commands => 'commands',
    ui => 'ui',
  };
}

/// When a plugin should be brought to life.
///
/// Loading every plugin at startup would put third-party code on the critical
/// path of the splash screen, so activation is deferred until something asks
/// for it.
@immutable
class ActivationEvent {
  const ActivationEvent(this.kind, [this.argument = '']);

  final ActivationKind kind;

  /// The part after the colon, for example the command id in `onCommand:x`.
  final String argument;

  static ActivationEvent? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed == '*') return const ActivationEvent(ActivationKind.always);
    final colon = trimmed.indexOf(':');
    final head = (colon < 0 ? trimmed : trimmed.substring(0, colon)).trim();
    final tail = colon < 0 ? '' : trimmed.substring(colon + 1).trim();
    return switch (head) {
      'onStartup' => const ActivationEvent(ActivationKind.startup),
      'onCommand' => ActivationEvent(ActivationKind.command, tail),
      'onLanguage' => ActivationEvent(ActivationKind.language, tail),
      'onFileOpen' => ActivationEvent(ActivationKind.fileOpen, tail),
      'onView' => ActivationEvent(ActivationKind.view, tail),
      _ => null,
    };
  }

  /// The manifest spelling, which is what [parse] accepts. Kept distinct from
  /// [toString] so serialising a manifest and reading it back is symmetric.
  String get wireName => switch (kind) {
    ActivationKind.always => '*',
    ActivationKind.startup => 'onStartup',
    ActivationKind.command => 'onCommand:$argument',
    ActivationKind.fileOpen => 'onFileOpen:$argument',
    ActivationKind.view => 'onView:$argument',
    ActivationKind.language => 'onLanguage:$argument',
  };

  @override
  String toString() => wireName;
}

enum ActivationKind {
  /// `*` — activate as soon as the host is ready. Discouraged.
  always,

  /// `onStartup` — activate after the first drawing is ready.
  startup,

  /// `onCommand:<id>` — activate when one of its commands is invoked.
  command,

  /// `onFileOpen:<extension>` — activate when a matching file opens.
  fileOpen,

  /// `onView:<panelId>` — activate when one of its panels is revealed.
  view,

  /// `onLanguage:<id>` — reserved for script editing support.
  language,
}

/// A command a plugin contributes.
///
/// Deliberately the same shape as [CommandDescriptor] minus the handler: a
/// contributed command is indistinguishable from a built-in once registered,
/// which is what makes "migrate a built-in to a plugin" a non-event.
@immutable
class CommandContribution {
  const CommandContribution({
    required this.id,
    required this.title,
    this.category = 'Extensions',
    this.description = '',
    this.aliases = const [],
    this.params = const [],
    this.risk = CommandRisk.edit,
    this.aiExposure = AiExposure.tool,
    this.icon,
    this.keybinding,
    this.when,
    this.repeatable = true,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final List<String> aliases;
  final List<ParamSpec> params;
  final CommandRisk risk;
  final AiExposure aiExposure;
  final String? icon;
  final String? keybinding;
  final String? when;
  final bool repeatable;

  static CommandContribution fromJson(Map<String, Object?> json, String where) {
    final id = _requireString(json, 'id', where);
    return CommandContribution(
      id: id,
      title: _optionalString(json, 'title') ?? id,
      category: _optionalString(json, 'category') ?? 'Extensions',
      description: _optionalString(json, 'description') ?? '',
      aliases: _stringList(json['aliases'], '$where.aliases'),
      params: [
        for (final (index, raw) in _mapList(
          json['params'],
          '$where.params',
        ).indexed)
          _paramFromJson(raw, '$where.params[$index]'),
      ],
      risk: _parseRisk(_optionalString(json, 'risk'), where),
      aiExposure: _parseExposure(_optionalString(json, 'aiExposure'), where),
      icon: _optionalString(json, 'icon'),
      keybinding: _optionalString(json, 'keybinding'),
      when: _optionalString(json, 'when'),
      repeatable: json['repeatable'] as bool? ?? true,
    );
  }

  /// Builds the registry descriptor, binding [handler] as the bridge back into
  /// the plugin.
  CommandDescriptor toDescriptor({
    required String extensionId,
    required CommandHandler handler,
  }) => CommandDescriptor(
    id: id,
    title: title,
    handler: handler,
    category: category,
    description: description,
    params: params,
    aliases: aliases,
    risk: risk,
    aiExposure: aiExposure,
    icon: icon,
    defaultKeybinding: keybinding,
    when: when,
    extensionId: extensionId,
    repeatable: repeatable,
  );
}

/// Where a contributed panel docks.
enum PanelLocation { sidebar, panel, properties }

/// A panel a plugin contributes to the shell.
@immutable
class PanelContribution {
  const PanelContribution({
    required this.id,
    required this.title,
    this.location = PanelLocation.sidebar,
    this.icon,
    this.order = 100,
  });

  final String id;
  final String title;
  final PanelLocation location;
  final String? icon;

  /// Sort key within its container; lower comes first.
  final int order;

  static PanelContribution fromJson(Map<String, Object?> json, String where) {
    final id = _requireString(json, 'id', where);
    final rawLocation = _optionalString(json, 'location') ?? 'sidebar';
    final location = switch (rawLocation) {
      'sidebar' => PanelLocation.sidebar,
      'panel' || 'bottom' => PanelLocation.panel,
      'properties' => PanelLocation.properties,
      _ => throw ManifestException(
        '$where.location: unknown location "$rawLocation"',
      ),
    };
    return PanelContribution(
      id: id,
      title: _optionalString(json, 'title') ?? id,
      location: location,
      icon: _optionalString(json, 'icon'),
      order: (json['order'] as num?)?.toInt() ?? 100,
    );
  }
}

/// One entry in a menu, referring to a command by id.
@immutable
class MenuContribution {
  const MenuContribution({
    required this.menu,
    required this.commandId,
    this.group = '',
    this.when,
    this.order = 100,
  });

  /// The menu it attaches to, for example `canvas/context` or `titlebar/tools`.
  final String menu;

  final String commandId;

  /// Grouping key; groups are separated by dividers and sorted by name.
  final String group;

  final String? when;
  final int order;
}

/// A keybinding a plugin contributes.
@immutable
class KeybindingContribution {
  const KeybindingContribution({
    required this.commandId,
    required this.key,
    this.when,
  });

  final String commandId;
  final String key;
  final String? when;
}

/// Everything a plugin declares before any of its code runs.
///
/// Contributions are static data on purpose: the palette, the menus and the AI
/// tool list are all complete before a single line of plugin JavaScript is
/// evaluated, so a plugin that never activates still costs nothing but is
/// still discoverable.
@immutable
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.entryPoint,
    this.publisher = '',
    this.description = '',
    this.hostConstraint = '',
    this.activation = const [],
    this.permissions = const {},
    this.commands = const [],
    this.panels = const [],
    this.menus = const [],
    this.keybindings = const [],
    this.directory = '',
  });

  /// Globally unique, conventionally `publisher.name`.
  final String id;

  final String name;
  final String version;

  /// The JavaScript file to evaluate, relative to [directory].
  final String entryPoint;

  final String publisher;
  final String description;

  /// The `engines.fancad` range this plugin claims to support.
  final String hostConstraint;

  final List<ActivationEvent> activation;
  final Set<PluginPermission> permissions;
  final List<CommandContribution> commands;
  final List<PanelContribution> panels;
  final List<MenuContribution> menus;
  final List<KeybindingContribution> keybindings;

  /// Absolute path to the plugin folder. Empty for manifests parsed in memory.
  final String directory;

  /// The manifest file name looked for during discovery.
  static const String fileName = 'fancad.plugin.json';

  bool get activatesAtStartup => activation.any(
    (event) =>
        event.kind == ActivationKind.startup ||
        event.kind == ActivationKind.always,
  );

  bool activatesOnCommand(String commandId) => activation.any(
    (event) =>
        event.kind == ActivationKind.command && event.argument == commandId,
  );

  bool has(PluginPermission permission) => permissions.contains(permission);

  PluginManifest withDirectory(String value) => PluginManifest(
    id: id,
    name: name,
    version: version,
    entryPoint: entryPoint,
    publisher: publisher,
    description: description,
    hostConstraint: hostConstraint,
    activation: activation,
    permissions: permissions,
    commands: commands,
    panels: panels,
    menus: menus,
    keybindings: keybindings,
    directory: value,
  );

  static PluginManifest parse(String source, {String path = ''}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ManifestException('not valid JSON (${error.message})', path: path);
    }
    if (decoded is! Map<String, Object?>) {
      throw ManifestException('expected a JSON object at the top level',
          path: path);
    }
    return fromJson(decoded, path: path);
  }

  static PluginManifest fromJson(
    Map<String, Object?> json, {
    String path = '',
  }) {
    try {
      final id = _requireString(json, 'id', 'manifest');
      final commands = [
        for (final (index, raw) in _mapList(
          _contributes(json)['commands'],
          'contributes.commands',
        ).indexed)
          CommandContribution.fromJson(raw, 'contributes.commands[$index]'),
      ];
      final seen = <String>{};
      for (final command in commands) {
        if (!seen.add(command.id)) {
          throw ManifestException(
            'contributes.commands: duplicate command id "${command.id}"',
            path: path,
          );
        }
      }
      return PluginManifest(
        id: id,
        name: _optionalString(json, 'name') ?? id,
        version: _optionalString(json, 'version') ?? '0.0.0',
        entryPoint: _optionalString(json, 'main') ?? 'main.js',
        publisher: _optionalString(json, 'publisher') ?? '',
        description: _optionalString(json, 'description') ?? '',
        hostConstraint: _hostConstraint(json),
        activation: _activation(json['activationEvents']),
        permissions: _permissions(json['permissions']),
        commands: commands,
        panels: [
          for (final (index, raw) in _mapList(
            _contributes(json)['panels'],
            'contributes.panels',
          ).indexed)
            PanelContribution.fromJson(raw, 'contributes.panels[$index]'),
        ],
        menus: _menus(_contributes(json)['menus']),
        keybindings: _keybindings(_contributes(json)['keybindings']),
        directory: '',
      );
    } on ManifestException catch (error) {
      // Re-throw with the file attached, so the panel can point at it.
      if (error.path.isNotEmpty || path.isEmpty) rethrow;
      throw ManifestException(error.message, path: path);
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'main': entryPoint,
    if (publisher.isNotEmpty) 'publisher': publisher,
    if (description.isNotEmpty) 'description': description,
    if (hostConstraint.isNotEmpty) 'engines': {'fancad': hostConstraint},
    if (activation.isNotEmpty)
      'activationEvents': [for (final event in activation) event.wireName],
    if (permissions.isNotEmpty)
      'permissions': [for (final value in permissions) value.wireName],
    'contributes': {
      if (commands.isNotEmpty)
        'commands': [
          for (final command in commands)
            {
              'id': command.id,
              'title': command.title,
              'category': command.category,
              if (command.description.isNotEmpty)
                'description': command.description,
              if (command.aliases.isNotEmpty) 'aliases': command.aliases,
              'risk': command.risk.name,
            },
        ],
      if (panels.isNotEmpty)
        'panels': [
          for (final panel in panels)
            {
              'id': panel.id,
              'title': panel.title,
              'location': panel.location.name,
              if (panel.icon != null) 'icon': panel.icon,
            },
        ],
    },
  };

  @override
  String toString() => 'PluginManifest($id@$version)';
}

Map<String, Object?> _contributes(Map<String, Object?> json) {
  final raw = json['contributes'];
  if (raw == null) return const {};
  if (raw is! Map<String, Object?>) {
    throw const ManifestException('contributes: expected an object');
  }
  return raw;
}

String _hostConstraint(Map<String, Object?> json) {
  final engines = json['engines'];
  if (engines == null) return '';
  if (engines is! Map<String, Object?>) {
    throw const ManifestException('engines: expected an object');
  }
  final value = engines['fancad'];
  return value is String ? value : '';
}

List<ActivationEvent> _activation(Object? raw) {
  final events = <ActivationEvent>[];
  for (final value in _stringList(raw, 'activationEvents')) {
    final event = ActivationEvent.parse(value);
    if (event == null) {
      throw ManifestException('activationEvents: unknown event "$value"');
    }
    events.add(event);
  }
  return events;
}

Set<PluginPermission> _permissions(Object? raw) {
  final permissions = <PluginPermission>{};
  for (final value in _stringList(raw, 'permissions')) {
    final permission = PluginPermission.parse(value);
    if (permission == null) {
      throw ManifestException('permissions: unknown permission "$value"');
    }
    permissions.add(permission);
  }
  return permissions;
}

List<MenuContribution> _menus(Object? raw) {
  if (raw == null) return const [];
  if (raw is! Map<String, Object?>) {
    throw const ManifestException('contributes.menus: expected an object');
  }
  final result = <MenuContribution>[];
  for (final entry in raw.entries) {
    final where = 'contributes.menus.${entry.key}';
    for (final (index, item) in _mapList(entry.value, where).indexed) {
      result.add(
        MenuContribution(
          menu: entry.key,
          commandId: _requireString(item, 'command', '$where[$index]'),
          group: _optionalString(item, 'group') ?? '',
          when: _optionalString(item, 'when'),
          order: (item['order'] as num?)?.toInt() ?? 100,
        ),
      );
    }
  }
  return result;
}

List<KeybindingContribution> _keybindings(Object? raw) {
  final where = 'contributes.keybindings';
  return [
    for (final (index, item) in _mapList(raw, where).indexed)
      KeybindingContribution(
        commandId: _requireString(item, 'command', '$where[$index]'),
        key: _requireString(item, 'key', '$where[$index]'),
        when: _optionalString(item, 'when'),
      ),
  ];
}

ParamSpec _paramFromJson(Map<String, Object?> json, String where) {
  final name = _requireString(json, 'name', where);
  final rawType = _optionalString(json, 'type') ?? 'text';
  final type = ParamType.values.firstWhere(
    (candidate) => candidate.name == rawType,
    orElse: () =>
        throw ManifestException('$where.type: unknown type "$rawType"'),
  );
  final options = _stringList(json['options'], '$where.options');
  if (type == ParamType.choice && options.isEmpty) {
    throw ManifestException('$where: a choice parameter needs "options"');
  }
  return ParamSpec(
    name: name,
    type: type,
    description: _optionalString(json, 'description') ?? '',
    required: json['required'] as bool? ?? false,
    defaultValue: json['default'],
    options: options,
    prompt: _optionalString(json, 'prompt'),
    min: json['min'] as num?,
    max: json['max'] as num?,
  );
}

CommandRisk _parseRisk(String? raw, String where) {
  if (raw == null) return CommandRisk.edit;
  return CommandRisk.values.firstWhere(
    (candidate) => candidate.name == raw,
    orElse: () => throw ManifestException('$where.risk: unknown risk "$raw"'),
  );
}

AiExposure _parseExposure(String? raw, String where) {
  if (raw == null) return AiExposure.tool;
  return AiExposure.values.firstWhere(
    (candidate) => candidate.name == raw,
    orElse: () =>
        throw ManifestException('$where.aiExposure: unknown value "$raw"'),
  );
}

String _requireString(Map<String, Object?> json, String key, String where) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ManifestException('$where: "$key" is required and must be a string');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw ManifestException('"$key" must be a string');
  }
  return value;
}

List<String> _stringList(Object? raw, String where) {
  if (raw == null) return const [];
  if (raw is! List) throw ManifestException('$where: expected an array');
  return [
    for (final value in raw)
      if (value is String)
        value
      else
        throw ManifestException('$where: expected an array of strings'),
  ];
}

List<Map<String, Object?>> _mapList(Object? raw, String where) {
  if (raw == null) return const [];
  if (raw is! List) throw ManifestException('$where: expected an array');
  return [
    for (final value in raw)
      if (value is Map<String, Object?>)
        value
      else
        throw ManifestException('$where: expected an array of objects'),
  ];
}
