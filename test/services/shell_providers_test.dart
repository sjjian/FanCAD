import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
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
  test('selecting the open sidebar icon collapses it, as VS Code does', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.sidebarView: 'layers',
      SettingsKeys.sidebarOpen: true,
      SettingsKeys.sidebarWidth: 240,
    });
    final sidebar = containerOf(settings).read(sidebarProvider.notifier);
    expect(sidebar.state.viewId, 'layers');
    expect(sidebar.state.isOpen, isTrue);
    expect(sidebar.state.width, 240);
    expect(Sidebar.defaultWidth, FanCadTokens.sidePanelWidth);
    expect(Sidebar.minWidth, FanCadTokens.sidePanelMinWidth);

    final narrow = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarWidth: 40}),
    ).read(sidebarProvider.notifier);
    expect(narrow.state.width, Sidebar.minWidth);

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
    expect(sidebar.state.width, Sidebar.minWidth);
    sidebar.resize(240.6);
    expect(sidebar.state.width, 241);
    sidebar.resize(900);
    expect(sidebar.state.width, Sidebar.maxWidth);
    sidebar.commitWidth();
    expect(settings.getDouble(SettingsKeys.sidebarWidth), Sidebar.maxWidth);
  });

  test('a leftover assistant view does not occupy the left sidebar', () {
    final sidebar = containerOf(
      SettingsStore.inMemory({SettingsKeys.sidebarView: 'ai'}),
    ).read(sidebarProvider.notifier);
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
    expect(sidebar.state.viewId, 'preferences');
    expect(sidebar.state.isOpen, isTrue);
  });

  test('the assistant pane opens on the right and keeps its own width', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.assistantOpen: true,
      SettingsKeys.assistantWidth: 40,
    });
    final pane = containerOf(settings).read(assistantPaneProvider.notifier);
    expect(pane.state.isOpen, isTrue);
    expect(pane.state.width, AssistantPane.minWidth);

    pane.toggle();
    expect(pane.state.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.assistantOpen), isFalse);
    pane.resize(320.4);
    expect(pane.state.width, 320);
    pane.resize(900);
    pane.commitWidth();
    expect(
      settings.getDouble(SettingsKeys.assistantWidth),
      AssistantPane.maxWidth,
    );
    pane.resetWidth();
    expect(pane.state.width, AssistantPane.defaultWidth);
  });

  test('a stored pane height below the input row is lifted to collapsed', () {
    final pane = containerOf(
      SettingsStore.inMemory({SettingsKeys.commandPaneHeight: 12}),
    ).read(commandPaneProvider.notifier);
    expect(pane.state.height, CommandPane.collapsedHeight);
  });

  test('the command pane default leaves the canvas most of the window', () {
    expect(
      CommandPane.collapsedHeight,
      FanCadTokens.splitterHit + FanCadTokens.commandLineHeight,
    );
    expect(CommandPane.defaultHeight, 84);
    expect(CommandPane.expandedHeight, 200);
    expect(CommandPane.defaultHeight, lessThan(CommandPane.expandedHeight));
    expect(CommandPane.collapsedHeight, lessThan(CommandPane.defaultHeight));
  });

  test('the command pane clamps height and expands to a taller history', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.commandPaneHeight: 100,
    });
    final pane = containerOf(settings).read(commandPaneProvider.notifier);
    expect(pane.state.height, 100);
    expect(pane.state.isExpanded, isFalse);

    pane.resize(10);
    expect(pane.state.height, CommandPane.minHeight);
    pane.resize(800);
    expect(pane.state.height, CommandPane.maxHeight);
    pane.commitHeight();
    expect(
      settings.getDouble(SettingsKeys.commandPaneHeight),
      CommandPane.maxHeight,
    );

    pane.toggleExpanded();
    expect(pane.state.isExpanded, isTrue);
    expect(pane.state.height, CommandPane.expandedHeight);
    pane.toggleExpanded();
    expect(pane.state.isExpanded, isFalse);
    expect(pane.state.height, CommandPane.collapsedHeight);
  });

  test('theme brightness restores from settings and persists a toggle', () {
    final light = containerOf(
      SettingsStore.inMemory({SettingsKeys.themeBrightness: 'light'}),
    ).read(themeBrightnessProvider.notifier);
    expect(light.state, Brightness.light);

    final settings = SettingsStore.inMemory();
    final dark = containerOf(settings).read(themeBrightnessProvider.notifier);
    expect(dark.state, Brightness.dark);
    dark.toggle();
    expect(dark.state, Brightness.light);
    expect(settings.getString(SettingsKeys.themeBrightness), 'light');
    dark.toggle();
    expect(settings.getString(SettingsKeys.themeBrightness), 'dark');

    dark.setPreference('system');
    expect(settings.getString(SettingsKeys.themeBrightness), 'system');
    expect(dark.preference, 'system');
  });

  test('language defaults to English and persists a supported switch', () {
    final settings = SettingsStore.inMemory();
    final language = containerOf(settings).read(languageProvider.notifier);
    expect(language.state, FanCadLanguage.english);

    language.setLanguage(FanCadLanguage.chinese);
    expect(language.state, FanCadLanguage.chinese);
    expect(settings.getString(SettingsKeys.language), FanCadLanguage.chinese);
  });

  test('a leftover language code is treated as English', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'fr'}),
    ).read(languageProvider.notifier);
    expect(leftover.state, FanCadLanguage.english);

    leftover.setLanguage('not-a-locale');
    expect(leftover.state, FanCadLanguage.english);
  });

  test('regional Chinese leftovers collapse to zh', () {
    final leftover = containerOf(
      SettingsStore.inMemory({SettingsKeys.language: 'zh_CN'}),
    ).read(languageProvider.notifier);
    expect(leftover.state, FanCadLanguage.chinese);
  });
}
