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
    final container = containerOf(settings);
    final layout = container.read(layoutNotifierProvider.notifier);
    expect(layout.state.sidebarView, 'layers');
    expect(layout.state.sidebarOpen, isTrue);
    expect(layout.state.sidebarWidth, SidebarLayout.defaultWidth);
    expect(
      SidebarLayout.defaultWidth,
      inInclusiveRange(SidebarLayout.minWidth, SidebarLayout.maxWidth),
    );

    final narrow = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarWidth: 40}),
    ).read(layoutNotifierProvider.notifier);
    expect(narrow.state.sidebarWidth, SidebarLayout.minWidth);

    layout.select('layers');
    expect(layout.state.sidebarOpen, isFalse);
    expect(settings.getBool(SettingsKeys.sidebarOpen), isFalse);

    layout.select('commands');
    expect(layout.state.sidebarView, 'commands');
    expect(layout.state.sidebarOpen, isTrue);
    expect(settings.getString(SettingsKeys.sidebarView), 'commands');

    layout.setSidebarOpen(false);
    layout.reveal('properties');
    expect(layout.state.sidebarView, 'properties');
    expect(layout.state.sidebarOpen, isTrue);

    layout.toggleSidebar();
    expect(layout.state.sidebarOpen, isFalse);

    layout.resizeSidebar(40);
    expect(layout.state.sidebarWidth, SidebarLayout.minWidth);
    layout.resizeSidebar(240.6);
    expect(layout.state.sidebarWidth, 241);
    layout.resizeSidebar(900);
    expect(layout.state.sidebarWidth, SidebarLayout.maxWidth);
    layout.commit();
    expect(
      settings.getDouble(SettingsKeys.sidebarWidth),
      SidebarLayout.maxWidth,
    );
  });

  test('a leftover assistant view does not occupy the left sidebar', () {
    final sidebar = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarView: 'ai'}),
    ).read(layoutNotifierProvider.notifier);
    expect(sidebar.state.sidebarView, 'layers');
    sidebar.select('ai');
    expect(sidebar.state.sidebarView, 'layers');
    expect(sidebar.state.sidebarOpen, isFalse);

    sidebar.reveal('history');
    expect(sidebar.state.sidebarView, 'history');
    expect(sidebar.state.sidebarOpen, isTrue);

    sidebar.reveal('layouts');
    expect(sidebar.state.sidebarView, 'layouts');
    expect(sidebar.state.sidebarOpen, isTrue);

    sidebar.reveal('preferences');
    expect(sidebar.state.sidebarView, 'layers');
    expect(sidebar.state.sidebarOpen, isTrue);

    expect(
      containerOf(
        SettingsStore.inMemory({SettingsKeys.sidebarView: 'preferences'}),
      ).read(layoutNotifierProvider).sidebarView,
      'layers',
    );
  });

  test('the assistant pane opens on the right and keeps its own width', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.assistantOpen: true,
      SettingsKeys.assistantWidth: 40,
    });
    final container = containerOf(settings);
    final layout = container.read(layoutNotifierProvider.notifier);
    expect(layout.state.assistantOpen, isTrue);
    expect(layout.state.assistantWidth, AssistantPaneLayout.minWidth);

    layout.toggleAssistant();
    expect(layout.state.assistantOpen, isFalse);
    expect(settings.getBool(SettingsKeys.assistantOpen), isFalse);
    layout.resizeAssistant(320.4);
    expect(layout.state.assistantWidth, 320);
    layout.resizeAssistant(900);
    layout.commit();
    expect(
      settings.getDouble(SettingsKeys.assistantWidth),
      AssistantPaneLayout.maxWidth,
    );
    layout.resetAssistantWidth();
    expect(layout.state.assistantWidth, AssistantPaneLayout.defaultWidth);
  });

  test('a stored pane height below the input row is lifted to collapsed', () {
    final layout = containerOf(
      SettingsStore.inMemory({SettingsKeys.commandPaneHeight: 12}),
    ).read(layoutNotifierProvider.notifier);
    expect(layout.state.commandHeight, CommandLineLayout.collapsedHeight);
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
    final container = containerOf(settings);
    final commandLine = container.read(commandLineNotifierProvider.notifier);
    final layout = container.read(layoutNotifierProvider.notifier);
    expect(layout.state.commandHeight, 100);
    expect(commandLine.state.pane.isExpanded, isFalse);

    layout.resizeCommand(10);
    expect(layout.state.commandHeight, CommandLineLayout.minHeight);
    layout.resizeCommand(800);
    expect(layout.state.commandHeight, CommandLineLayout.maxHeight);
    layout.commit();
    expect(
      settings.getDouble(SettingsKeys.commandPaneHeight),
      CommandLineLayout.maxHeight,
    );

    commandLine.toggleCommandExpanded();
    expect(commandLine.state.pane.isExpanded, isTrue);
    expect(layout.state.commandHeight, CommandLineLayout.expandedHeight);
    commandLine.toggleCommandExpanded();
    expect(commandLine.state.pane.isExpanded, isFalse);
    expect(layout.state.commandHeight, CommandLineLayout.collapsedHeight);
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
