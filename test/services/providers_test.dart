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
    final sidebar = containerOf(
      settings,
    ).read(sidebarNotifierProvider.notifier);
    expect(sidebar.state.viewId, 'layers');
    expect(sidebar.state.isOpen, isTrue);
    expect(sidebar.state.width, SidebarLayout.defaultWidth);
    expect(
      SidebarLayout.defaultWidth,
      inInclusiveRange(SidebarLayout.minWidth, SidebarLayout.maxWidth),
    );

    final narrow = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarWidth: 40}),
    ).read(sidebarNotifierProvider.notifier);
    expect(narrow.state.width, SidebarLayout.minWidth);

    sidebar.select('layers');
    expect(sidebar.state.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.sidebarOpen), isFalse);

    sidebar.select('commands');
    expect(sidebar.state.viewId, 'commands');
    expect(sidebar.state.isOpen, isTrue);
    expect(settings.getString(SettingsKeys.sidebarView), 'commands');

    sidebar.setOpen(false);
    sidebar.reveal('properties');
    expect(sidebar.state.viewId, 'properties');
    expect(sidebar.state.isOpen, isTrue);

    sidebar.toggle();
    expect(sidebar.state.isOpen, isFalse);

    sidebar.resize(40);
    expect(sidebar.state.width, SidebarLayout.minWidth);
    sidebar.resize(240.6);
    expect(sidebar.state.width, 241);
    sidebar.resize(900);
    expect(sidebar.state.width, SidebarLayout.maxWidth);
    sidebar.commitWidth();
    expect(
      settings.getDouble(SettingsKeys.sidebarWidth),
      SidebarLayout.maxWidth,
    );
  });

  test('a leftover assistant view does not occupy the left sidebar', () {
    final sidebar = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarView: 'ai'}),
    ).read(sidebarNotifierProvider.notifier);
    expect(sidebar.state.viewId, 'layers');
    sidebar.select('ai');
    expect(sidebar.state.viewId, 'layers');
    expect(sidebar.state.isOpen, isFalse);

    sidebar.reveal('history');
    expect(sidebar.state.viewId, 'history');
    expect(sidebar.state.isOpen, isTrue);

    sidebar.reveal('layouts');
    expect(sidebar.state.viewId, 'layouts');
    expect(sidebar.state.isOpen, isTrue);

    sidebar.reveal('preferences');
    expect(sidebar.state.viewId, 'layers');
    expect(sidebar.state.isOpen, isTrue);

    expect(
      containerOf(
        SettingsStore.inMemory({SettingsKeys.sidebarView: 'preferences'}),
      ).read(sidebarNotifierProvider).viewId,
      'layers',
    );
  });

  test('the assistant pane opens on the right and keeps its own width', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.assistantOpen: true,
      SettingsKeys.assistantWidth: 40,
    });
    final assistant = containerOf(
      settings,
    ).read(assistantNotifierProvider.notifier);
    expect(assistant.state.pane.isOpen, isTrue);
    expect(assistant.state.pane.width, AssistantPaneLayout.minWidth);

    assistant.toggleAssistant();
    expect(assistant.state.pane.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.assistantOpen), isFalse);
    assistant.resizeAssistant(320.4);
    expect(assistant.state.pane.width, 320);
    assistant.resizeAssistant(900);
    assistant.commitAssistantWidth();
    expect(
      settings.getDouble(SettingsKeys.assistantWidth),
      AssistantPaneLayout.maxWidth,
    );
    assistant.resetAssistantWidth();
    expect(assistant.state.pane.width, AssistantPaneLayout.defaultWidth);
  });

  test('a stored pane height below the input row is lifted to collapsed', () {
    final commandLine = containerOf(
      SettingsStore.inMemory({SettingsKeys.commandPaneHeight: 12}),
    ).read(commandLineNotifierProvider.notifier);
    expect(commandLine.state.pane.height, CommandLineLayout.collapsedHeight);
  });

  test('the command pane default leaves the canvas most of the window', () {
    expect(
      CommandLineLayout.collapsedHeight,
      CommandLineLayout.splitterHit + CommandLineLayout.commandLineHeight,
    );
    expect(CommandLineLayout.defaultHeight, 84);
    expect(CommandLineLayout.expandedHeight, 200);
    expect(
      CommandLineLayout.defaultHeight,
      lessThan(CommandLineLayout.expandedHeight),
    );
    expect(
      CommandLineLayout.collapsedHeight,
      lessThan(CommandLineLayout.defaultHeight),
    );
  });

  test('the command pane clamps height and expands to a taller history', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.commandPaneHeight: 100,
    });
    final commandLine = containerOf(
      settings,
    ).read(commandLineNotifierProvider.notifier);
    expect(commandLine.state.pane.height, 100);
    expect(commandLine.state.pane.isExpanded, isFalse);

    commandLine.resizeCommand(10);
    expect(commandLine.state.pane.height, CommandLineLayout.minHeight);
    commandLine.resizeCommand(800);
    expect(commandLine.state.pane.height, CommandLineLayout.maxHeight);
    commandLine.commitCommandHeight();
    expect(
      settings.getDouble(SettingsKeys.commandPaneHeight),
      CommandLineLayout.maxHeight,
    );

    commandLine.toggleCommandExpanded();
    expect(commandLine.state.pane.isExpanded, isTrue);
    expect(commandLine.state.pane.height, CommandLineLayout.expandedHeight);
    commandLine.toggleCommandExpanded();
    expect(commandLine.state.pane.isExpanded, isFalse);
    expect(commandLine.state.pane.height, CommandLineLayout.collapsedHeight);
  });

  test('theme brightness restores from settings and persists a toggle', () {
    final light = containerOf(
      SettingsStore.inMemory({SettingsKeys.themeBrightness: 'light'}),
    ).read(appearanceNotifierProvider.notifier);
    expect(light.state.theme, ThemePreference.light);

    final settings = SettingsStore.inMemory();
    final dark = containerOf(
      settings,
    ).read(appearanceNotifierProvider.notifier);
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
    final appearance = containerOf(
      settings,
    ).read(appearanceNotifierProvider.notifier);
    expect(appearance.state.language, FanCadLanguage.english);

    appearance.setLanguage(FanCadLanguage.chinese);
    expect(appearance.state.language, FanCadLanguage.chinese);
    expect(settings.getString(SettingsKeys.language), FanCadLanguage.chinese);
  });

  test('a leftover language code is treated as English', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'fr'}),
    ).read(appearanceNotifierProvider.notifier);
    expect(leftover.state.language, FanCadLanguage.english);

    leftover.setLanguage('not-a-locale');
    expect(leftover.state.language, FanCadLanguage.english);
  });

  test('regional Chinese leftovers collapse to zh', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'zh_CN'}),
    ).read(appearanceNotifierProvider.notifier);
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
      container
          .read(workspaceNotifierProvider)
          .tabStrip
          .sessions
          .single
          .isDirty,
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
