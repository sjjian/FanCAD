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

    sidebar.select('layers');
    expect(sidebar.state.isOpen, isFalse);
    expect(settings.getBool(SettingsKeys.sidebarOpen), isFalse);

    sidebar.select('ai');
    expect(sidebar.state.viewId, 'ai');
    expect(sidebar.state.isOpen, isTrue);
    expect(settings.getString(SettingsKeys.sidebarView), 'ai');

    sidebar.setOpen(false);
    sidebar.reveal('properties');
    expect(sidebar.state.viewId, 'properties');
    expect(sidebar.state.isOpen, isTrue);

    sidebar.toggle();
    expect(sidebar.state.isOpen, isFalse);

    sidebar.resize(40);
    expect(sidebar.state.width, SidebarController.minWidth);
    sidebar.resize(900);
    expect(sidebar.state.width, SidebarController.maxWidth);
    sidebar.commitWidth();
    expect(
      settings.getDouble(SettingsKeys.sidebarWidth),
      SidebarController.maxWidth,
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
    expect(pane.state.height, 320);
    pane.toggleExpanded();
    expect(pane.state.isExpanded, isFalse);
    expect(pane.state.height, 132);
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
}
