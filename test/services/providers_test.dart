import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerOf(SettingsStore settings) {
  final container = ProviderContainer(
    overrides: [settingsProvider.overrideWithValue(settings)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an empty plugins folder does not spawn a host', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(SettingsStore.inMemory()),
        pluginsDirectoryProvider.overrideWithValue(''),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(pluginNotifierProvider.notifier).host, isNull);
    expect(container.read(pluginNotifierProvider.notifier).commands, isNull);
  });

  test(
    'a plugins folder wires a host without starting the isolate transport',
    () {
      final root = tempDir(prefix: 'fancad-plugins');

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          pluginsDirectoryProvider.overrideWithValue(root.path),
          pluginTransportProvider.overrideWithValue(LocalTransport()),
        ],
      );
      addTearDown(container.dispose);

      final plugins = container.read(pluginNotifierProvider.notifier);
      expect(plugins.host, isNotNull);
      expect(plugins.commands, isNotNull);
      expect(plugins.commands!.pluginsDirectory, root.path);
    },
  );

  test('selecting the open sidebar icon collapses it, as VS Code does', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.sidebarView: 'layers',
      SettingsKeys.sidebarOpen: true,
      SettingsKeys.sidebarWidth: 240,
    });
    final shell = containerOf(settings).read(shellNotifierProvider.notifier);
    expect(shell.state.sidebar.viewId, 'layers');
    expect(shell.state.sidebar.isOpen, isTrue);
    expect(shell.state.sidebar.width, 240);
    expect(Shell.sidebarDefaultWidth, FanCadTokens.sidePanelWidth);
    expect(Shell.sidebarMinWidth, FanCadTokens.sidePanelMinWidth);

    final narrow = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarWidth: 40}),
    ).read(shellNotifierProvider.notifier);
    expect(narrow.state.sidebar.width, Shell.sidebarMinWidth);

    shell.select('layers');
    expect(shell.state.sidebar.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.sidebarOpen), isFalse);

    shell.select('commands');
    expect(shell.state.sidebar.viewId, 'commands');
    expect(shell.state.sidebar.isOpen, isTrue);
    expect(settings.getString(SettingsKeys.sidebarView), 'commands');

    shell.setOpen(false);
    shell.reveal('properties');
    expect(shell.state.sidebar.viewId, 'properties');
    expect(shell.state.sidebar.isOpen, isTrue);

    shell.toggle();
    expect(shell.state.sidebar.isOpen, isFalse);

    shell.resize(40);
    expect(shell.state.sidebar.width, Shell.sidebarMinWidth);
    shell.resize(240.6);
    expect(shell.state.sidebar.width, 241);
    shell.resize(900);
    expect(shell.state.sidebar.width, Shell.sidebarMaxWidth);
    shell.commitWidth();
    expect(settings.getDouble(SettingsKeys.sidebarWidth), Shell.sidebarMaxWidth);
  });

  test('a leftover assistant view does not occupy the left sidebar', () {
    final shell = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarView: 'ai'}),
    ).read(shellNotifierProvider.notifier);
    expect(shell.state.sidebar.viewId, 'layers');
    shell.select('ai');
    expect(shell.state.sidebar.viewId, 'layers');
    expect(shell.state.sidebar.isOpen, isFalse);

    shell.reveal('history');
    expect(shell.state.sidebar.viewId, 'history');
    expect(shell.state.sidebar.isOpen, isTrue);

    shell.reveal('layouts');
    expect(shell.state.sidebar.viewId, 'layouts');
    expect(shell.state.sidebar.isOpen, isTrue);

    shell.reveal('preferences');
    expect(shell.state.sidebar.viewId, 'layers');
    expect(shell.state.sidebar.isOpen, isTrue);

    expect(
      containerOf(
        SettingsStore.inMemory({SettingsKeys.sidebarView: 'preferences'}),
      ).read(shellNotifierProvider).sidebar.viewId,
      'layers',
    );
  });

  test('the assistant pane opens on the right and keeps its own width', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.assistantOpen: true,
      SettingsKeys.assistantWidth: 40,
    });
    final shell = containerOf(settings).read(shellNotifierProvider.notifier);
    expect(shell.state.assistant.isOpen, isTrue);
    expect(shell.state.assistant.width, Shell.assistantMinWidth);

    shell.toggleAssistant();
    expect(shell.state.assistant.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.assistantOpen), isFalse);
    shell.resizeAssistant(320.4);
    expect(shell.state.assistant.width, 320);
    shell.resizeAssistant(900);
    shell.commitAssistantWidth();
    expect(
      settings.getDouble(SettingsKeys.assistantWidth),
      Shell.assistantMaxWidth,
    );
    shell.resetAssistantWidth();
    expect(shell.state.assistant.width, Shell.assistantDefaultWidth);
  });

  test('a stored pane height below the input row is lifted to collapsed', () {
    final shell = containerOf(
      SettingsStore.inMemory({SettingsKeys.commandPaneHeight: 12}),
    ).read(shellNotifierProvider.notifier);
    expect(shell.state.commandPane.height, Shell.commandCollapsedHeight);
  });

  test('the command pane default leaves the canvas most of the window', () {
    expect(
      Shell.commandCollapsedHeight,
      FanCadTokens.splitterHit + FanCadTokens.commandLineHeight,
    );
    expect(Shell.commandDefaultHeight, 84);
    expect(Shell.commandExpandedHeight, 200);
    expect(Shell.commandDefaultHeight, lessThan(Shell.commandExpandedHeight));
    expect(
      Shell.commandCollapsedHeight,
      lessThan(Shell.commandDefaultHeight),
    );
  });

  test('the command pane clamps height and expands to a taller history', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.commandPaneHeight: 100,
    });
    final shell = containerOf(settings).read(shellNotifierProvider.notifier);
    expect(shell.state.commandPane.height, 100);
    expect(shell.state.commandPane.isExpanded, isFalse);

    shell.resizeCommand(10);
    expect(shell.state.commandPane.height, Shell.commandMinHeight);
    shell.resizeCommand(800);
    expect(shell.state.commandPane.height, Shell.commandMaxHeight);
    shell.commitCommandHeight();
    expect(
      settings.getDouble(SettingsKeys.commandPaneHeight),
      Shell.commandMaxHeight,
    );

    shell.toggleCommandExpanded();
    expect(shell.state.commandPane.isExpanded, isTrue);
    expect(shell.state.commandPane.height, Shell.commandExpandedHeight);
    shell.toggleCommandExpanded();
    expect(shell.state.commandPane.isExpanded, isFalse);
    expect(shell.state.commandPane.height, Shell.commandCollapsedHeight);
  });

  test('theme brightness restores from settings and persists a toggle', () {
    final light = containerOf(
      SettingsStore.inMemory({SettingsKeys.themeBrightness: 'light'}),
    ).read(shellNotifierProvider.notifier);
    expect(light.state.theme, ThemePreference.light);

    final settings = SettingsStore.inMemory();
    final dark = containerOf(settings).read(shellNotifierProvider.notifier);
    expect(dark.state.theme, ThemePreference.dark);
    dark.toggleTheme();
    expect(dark.state.theme, ThemePreference.light);
    expect(settings.getString(SettingsKeys.themeBrightness), 'light');
    dark.toggleTheme();
    expect(settings.getString(SettingsKeys.themeBrightness), 'dark');

    dark.setPreference(ThemePreference.system);
    expect(settings.getString(SettingsKeys.themeBrightness), 'system');
    expect(dark.state.theme, ThemePreference.system);
  });

  test('language defaults to English and persists a supported switch', () {
    final settings = SettingsStore.inMemory();
    final shell = containerOf(settings).read(shellNotifierProvider.notifier);
    expect(shell.state.language, FanCadLanguage.english);

    shell.setLanguage(FanCadLanguage.chinese);
    expect(shell.state.language, FanCadLanguage.chinese);
    expect(settings.getString(SettingsKeys.language), FanCadLanguage.chinese);
  });

  test('a leftover language code is treated as English', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'fr'}),
    ).read(shellNotifierProvider.notifier);
    expect(leftover.state.language, FanCadLanguage.english);

    leftover.setLanguage('not-a-locale');
    expect(leftover.state.language, FanCadLanguage.english);
  });

  test('regional Chinese leftovers collapse to zh', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'zh_CN'}),
    ).read(shellNotifierProvider.notifier);
    expect(leftover.state.language, FanCadLanguage.chinese);
  });

  test('workspace slices ignore hover and follow dirty', () {
    final container = containerOf(SettingsStore.inMemory());
    final workspace = container.read(workspaceNotifierProvider.notifier);
    workspace.newDocument(title: 'A');

    final sessions = container.read(workspaceNotifierProvider).tabStrip;
    expect(sessions.sessions, hasLength(1));
    expect(sessions.sessions.single.title, 'A');
    expect(sessions.sessions.single.isDirty, isFalse);

    workspace.setHoverHighlights(const [7]);
    expect(container.read(workspaceNotifierProvider).tabStrip, sessions);
    expect(container.read(workspaceNotifierProvider).highlightIds, [7]);
    expect(container.read(workspaceNotifierProvider).assistantBusy, isFalse);

    workspace.setAssistantBusy(true);
    expect(container.read(workspaceNotifierProvider).assistantBusy, isTrue);
    expect(container.read(workspaceNotifierProvider).tabStrip, sessions);

    workspace.active!.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(
      container.read(workspaceNotifierProvider).tabStrip.sessions.single.isDirty,
      isTrue,
    );
    expect(container.read(workspaceNotifierProvider).highlightIds, [7]);
  });

  test('mcp config wraps bind and persists a toggle', () {
    final settings = SettingsStore.inMemory();
    final mcp = containerOf(settings).read(mcpNotifierProvider.notifier);
    expect(mcp.state.bind.enabled, isTrue);
    expect(mcp.state.bind.local, isTrue);

    mcp.setEnabled(false);
    expect(mcp.state.bind.enabled, isFalse);
    expect(settings.getBool(SettingsKeys.mcpEnabled), isFalse);

    mcp.setLocal(false);
    expect(mcp.state.bind.local, isFalse);
    expect(settings.getBool(SettingsKeys.mcpLocal), isFalse);
  });
}
