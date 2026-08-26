// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$settingsHash() => r'f384c96e21ee56518feae4e992884d0e11cd89da';

/// Riverpod wiring for the application.
///
/// Only the genuinely global things live here. Per-document state hangs off
/// [Workspace] rather than off providers, because a provider per tab would make
/// "which document is this?" a question with two answers, and every CAD bug
/// worth fearing starts that way.
/// Provided by the app at startup, after settings have been loaded from disk.
///
/// Copied from [settings].
@ProviderFor(settings)
final settingsProvider = Provider<SettingsStore>.internal(
  settings,
  name: r'settingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SettingsRef = ProviderRef<SettingsStore>;
String _$appSettingsHash() => r'b68a7105a0731a82e51b069115db299577899396';

/// The same bag, split into the views services actually ask for.
///
/// Copied from [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = Provider<AppSettings>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppSettingsRef = ProviderRef<AppSettings>;
String _$fcbCacheHash() => r'dceff030cea335af36519ec63543323c90a12f5c';

/// The on-disk FCB cache, or null when no cache directory is available.
///
/// Overridden at startup once the platform support directory is known, and left
/// null in tests so that a test run never touches a real cache.
///
/// Copied from [fcbCache].
@ProviderFor(fcbCache)
final fcbCacheProvider = Provider<FcbCache?>.internal(
  fcbCache,
  name: r'fcbCacheProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fcbCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FcbCacheRef = ProviderRef<FcbCache?>;
String _$importerHash() => r'2e892a3dda185f80929abf1c488793c322c35f29';

/// The drawing importer. Overridden in tests with a stub backend.
///
/// Copied from [importer].
@ProviderFor(importer)
final importerProvider = Provider<DrawingImporter>.internal(
  importer,
  name: r'importerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$importerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImporterRef = ProviderRef<DrawingImporter>;
String _$commandRegistryHash() => r'4cd054338bd2ebf82d8d94fc3662f6f6199e0756';

/// See also [commandRegistry].
@ProviderFor(commandRegistry)
final commandRegistryProvider = Provider<CommandRegistry>.internal(
  commandRegistry,
  name: r'commandRegistryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$commandRegistryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommandRegistryRef = ProviderRef<CommandRegistry>;
String _$workspaceHash() => r'0423b50c62a0cf210392da50f730ee36498e07d5';

/// The application state.
///
/// A generated [Provider] over a [ChangeNotifier] rather than a
/// `ChangeNotifierProvider`, because there must be exactly one owner of its
/// disposal and the registration below has to be torn down first. Widgets
/// subscribe with a `ListenableBuilder`, which also keeps rebuilds scoped to the
/// part of the shell that actually changed — during a drag the workspace
/// notifies dozens of times a second, and rebuilding the whole tree at that rate
/// is the difference between a smooth pan and a stuttering one.
///
/// Copied from [workspace].
@ProviderFor(workspace)
final workspaceProvider = Provider<Workspace>.internal(
  workspace,
  name: r'workspaceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$workspaceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WorkspaceRef = ProviderRef<Workspace>;
String _$pluginsDirectoryHash() => r'883437af0aa766aa7633a91eeef02ee5dec57ab0';

/// Where user extensions live. Overridden at startup with a real path, and left
/// empty in tests so that a test run never scans the user's real folder.
///
/// Copied from [pluginsDirectory].
@ProviderFor(pluginsDirectory)
final pluginsDirectoryProvider = Provider<String>.internal(
  pluginsDirectory,
  name: r'pluginsDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginsDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginsDirectoryRef = ProviderRef<String>;
String _$pluginHostHash() => r'00d9102048aaec84bfd0a0ddd7a44ae39cc15e29';

/// The extension host, or null when this session has no extensions folder.
///
/// Null rather than a host with nowhere to load from: it keeps a test run from
/// spawning a worker isolate, and it gives the extensions panel something
/// honest to say instead of showing an empty list that will never fill.
///
/// Copied from [pluginHost].
@ProviderFor(pluginHost)
final pluginHostProvider = Provider<PluginHost?>.internal(
  pluginHost,
  name: r'pluginHostProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginHostHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginHostRef = ProviderRef<PluginHost?>;
String _$pluginTransportHash() => r'6aa1cc9005914190bf303062e87331e9ec22a5ae';

/// The transport plugins run over. Overridden in tests with [LocalTransport].
///
/// Copied from [pluginTransport].
@ProviderFor(pluginTransport)
final pluginTransportProvider = Provider<PluginTransport>.internal(
  pluginTransport,
  name: r'pluginTransportProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginTransportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginTransportRef = ProviderRef<PluginTransport>;
String _$pluginDelegateHash() => r'd8f623cf34183dfa3664c9464887c460d246e06d';

/// See also [pluginDelegate].
@ProviderFor(pluginDelegate)
final pluginDelegateProvider = Provider<WorkspacePluginDelegate>.internal(
  pluginDelegate,
  name: r'pluginDelegateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginDelegateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginDelegateRef = ProviderRef<WorkspacePluginDelegate>;
String _$aiControllerHash() => r'd4ad791f3a1f3683aef294d9fa7a78164f13b4f5';

/// The assistant session. Created even when no key is configured so the panel
/// can explain how to set one up.
///
/// Copied from [aiController].
@ProviderFor(aiController)
final aiControllerProvider = Provider<AiController>.internal(
  aiController,
  name: r'aiControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$aiControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiControllerRef = ProviderRef<AiController>;
String _$pluginCommandsHash() => r'b45ea4d306190438bab66d31750c1b6e9d9f35fc';

/// The extension management commands, or null when there is no plugins folder.
///
/// Copied from [pluginCommands].
@ProviderFor(pluginCommands)
final pluginCommandsProvider = Provider<PluginCommands?>.internal(
  pluginCommands,
  name: r'pluginCommandsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginCommandsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginCommandsRef = ProviderRef<PluginCommands?>;
String _$sidebarHash() => r'63c82b29bcd7d264f5c2ddfc6f0ab54bc0865337';

/// See also [Sidebar].
@ProviderFor(Sidebar)
final sidebarProvider = NotifierProvider<Sidebar, SidebarState>.internal(
  Sidebar.new,
  name: r'sidebarProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sidebarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Sidebar = Notifier<SidebarState>;
String _$commandPaneHash() => r'f1befb431df47d50e1f3dabbc36fe9beb14ed5bf';

/// See also [CommandPane].
@ProviderFor(CommandPane)
final commandPaneProvider =
    NotifierProvider<CommandPane, CommandPaneState>.internal(
      CommandPane.new,
      name: r'commandPaneProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$commandPaneHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CommandPane = Notifier<CommandPaneState>;
String _$assistantPaneHash() => r'276afff5a8f511a607624eb435289d2e828e1968';

/// See also [AssistantPane].
@ProviderFor(AssistantPane)
final assistantPaneProvider =
    NotifierProvider<AssistantPane, AssistantPaneState>.internal(
      AssistantPane.new,
      name: r'assistantPaneProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$assistantPaneHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AssistantPane = Notifier<AssistantPaneState>;
String _$paletteOpenHash() => r'bd56b76e9dd32de1c36aa09121b7e2190de27067';

/// Whether the command palette overlay is showing.
///
/// Copied from [PaletteOpen].
@ProviderFor(PaletteOpen)
final paletteOpenProvider = NotifierProvider<PaletteOpen, bool>.internal(
  PaletteOpen.new,
  name: r'paletteOpenProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paletteOpenHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PaletteOpen = Notifier<bool>;
String _$themeBrightnessHash() => r'f793b7f735345c0b595f666a3fdbc0ca22c77794';

/// The theme mode, persisted across launches.
///
/// Copied from [ThemeBrightness].
@ProviderFor(ThemeBrightness)
final themeBrightnessProvider =
    NotifierProvider<ThemeBrightness, Brightness>.internal(
      ThemeBrightness.new,
      name: r'themeBrightnessProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$themeBrightnessHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ThemeBrightness = Notifier<Brightness>;
String _$languageHash() => r'44c2182abf910a0ea39a2808694e7b0806f4980f';

/// UI language. Stored as `en` / `zh`, matching OpenHare. Unknown leftovers
/// fall back to English so a corrupt settings file cannot blank the shell.
///
/// Copied from [Language].
@ProviderFor(Language)
final languageProvider = NotifierProvider<Language, String>.internal(
  Language.new,
  name: r'languageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$languageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Language = Notifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
