import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selecting the open sidebar icon collapses it, as VS Code does', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.sidebarView: 'layers',
      SettingsKeys.sidebarOpen: true,
      SettingsKeys.sidebarWidth: 240,
    });
    final sidebar = SidebarController(settings);
    addTearDown(sidebar.dispose);
    expect(sidebar.state.viewId, 'layers');
    expect(sidebar.state.isOpen, isTrue);
    expect(sidebar.state.width, 240);
    expect(SidebarController.defaultWidth, FanCadTokens.sidePanelWidth);
    expect(SidebarController.minWidth, FanCadTokens.sidePanelMinWidth);

    final narrow = SidebarController(
      SettingsStore.inMemory({SettingsKeys.sidebarWidth: 40}),
    );
    addTearDown(narrow.dispose);
    expect(narrow.state.width, SidebarController.minWidth);

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
    expect(sidebar.state.width, SidebarController.minWidth);
    sidebar.resize(240.6);
    expect(sidebar.state.width, 241);
    sidebar.resize(900);
    expect(sidebar.state.width, SidebarController.maxWidth);
    sidebar.commitWidth();
    expect(
      settings.getDouble(SettingsKeys.sidebarWidth),
      SidebarController.maxWidth,
    );
  });

  test('a leftover assistant view does not occupy the left sidebar', () {
    final sidebar = SidebarController(
      SettingsStore.inMemory({SettingsKeys.sidebarView: 'ai'}),
    );
    addTearDown(sidebar.dispose);
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
  });

  test('the assistant pane opens on the right and keeps its own width', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.assistantOpen: true,
      SettingsKeys.assistantWidth: 40,
    });
    final pane = AssistantPaneController(settings);
    addTearDown(pane.dispose);
    expect(pane.state.isOpen, isTrue);
    expect(pane.state.width, AssistantPaneController.minWidth);

    pane.toggle();
    expect(pane.state.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.assistantOpen), isFalse);
    pane.resize(320.4);
    expect(pane.state.width, 320);
    pane.resize(900);
    pane.commitWidth();
    expect(
      settings.getDouble(SettingsKeys.assistantWidth),
      AssistantPaneController.maxWidth,
    );
    pane.resetWidth();
    expect(pane.state.width, AssistantPaneController.defaultWidth);
  });

  test('a stored pane height below the input row is lifted to collapsed', () {
    final pane = CommandPaneController(
      SettingsStore.inMemory({SettingsKeys.commandPaneHeight: 12}),
    );
    addTearDown(pane.dispose);
    expect(pane.state.height, CommandPaneController.collapsedHeight);
  });

  test('the command pane default leaves the canvas most of the window', () {
    expect(
      CommandPaneController.collapsedHeight,
      FanCadTokens.splitterHit + FanCadTokens.commandLineHeight,
    );
    expect(CommandPaneController.defaultHeight, 84);
    expect(CommandPaneController.expandedHeight, 200);
    expect(
      CommandPaneController.defaultHeight,
      lessThan(CommandPaneController.expandedHeight),
    );
    expect(
      CommandPaneController.collapsedHeight,
      lessThan(CommandPaneController.defaultHeight),
    );
  });

  test('the command pane clamps height and expands to a taller history', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.commandPaneHeight: 100,
    });
    final pane = CommandPaneController(settings);
    addTearDown(pane.dispose);
    expect(pane.state.height, 100);
    expect(pane.state.isExpanded, isFalse);

    pane.resize(10);
    expect(pane.state.height, CommandPaneController.minHeight);
    pane.resize(800);
    expect(pane.state.height, CommandPaneController.maxHeight);
    pane.commitHeight();
    expect(
      settings.getDouble(SettingsKeys.commandPaneHeight),
      CommandPaneController.maxHeight,
    );

    pane.toggleExpanded();
    expect(pane.state.isExpanded, isTrue);
    expect(pane.state.height, CommandPaneController.expandedHeight);
    pane.toggleExpanded();
    expect(pane.state.isExpanded, isFalse);
    expect(pane.state.height, CommandPaneController.collapsedHeight);
  });

  test('theme brightness restores from settings and persists a toggle', () {
    final light = ThemeModeController(
      SettingsStore.inMemory({SettingsKeys.themeBrightness: 'light'}),
    );
    addTearDown(light.dispose);
    expect(light.state, Brightness.light);

    final settings = SettingsStore.inMemory();
    final dark = ThemeModeController(settings);
    addTearDown(dark.dispose);
    expect(dark.state, Brightness.dark);
    dark.toggle();
    expect(dark.state, Brightness.light);
    expect(settings.getString(SettingsKeys.themeBrightness), 'light');
    dark.toggle();
    expect(settings.getString(SettingsKeys.themeBrightness), 'dark');
  });

  test('language defaults to English and persists a supported switch', () {
    final settings = SettingsStore.inMemory();
    final language = LanguageController(settings);
    addTearDown(language.dispose);
    expect(language.state, FanCadLanguage.english);

    language.setLanguage(FanCadLanguage.chinese);
    expect(language.state, FanCadLanguage.chinese);
    expect(settings.getString(SettingsKeys.language), FanCadLanguage.chinese);
  });

  test('a leftover language code is treated as English', () {
    final leftover = LanguageController(
      SettingsStore.inMemory({SettingsKeys.language: 'fr'}),
    );
    addTearDown(leftover.dispose);
    expect(leftover.state, FanCadLanguage.english);

    leftover.setLanguage('not-a-locale');
    expect(leftover.state, FanCadLanguage.english);
  });

  test('regional Chinese leftovers collapse to zh', () {
    final leftover = LanguageController(
      SettingsStore.inMemory({SettingsKeys.language: 'zh_CN'}),
    );
    addTearDown(leftover.dispose);
    expect(leftover.state, FanCadLanguage.chinese);
  });
}
