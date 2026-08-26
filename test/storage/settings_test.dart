import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed getters fall back when the stored value is the wrong kind', () {
    final store = SettingsStore.inMemory({
      SettingsKeys.showGrid: true,
      SettingsKeys.sidebarWidth: 240,
      SettingsKeys.themeBrightness: 'dark',
      SettingsKeys.recentFiles: ['a.dxf', 3, '  ', '', '  b.dwg  '],
      'blanks': ['', '  '],
      'bad': 'x',
    });
    expect(store.getBool(SettingsKeys.showGrid), isTrue);
    expect(store.getBool('missing', fallback: true), isTrue);
    expect(store.getBool('bad', fallback: true), isTrue);
    expect(store.getDouble(SettingsKeys.sidebarWidth), 240);
    expect(store.getInt(SettingsKeys.sidebarWidth), 240);
    expect(store.getString(SettingsKeys.themeBrightness), 'dark');
    expect(store.getStringList(SettingsKeys.recentFiles), ['a.dxf', 'b.dwg']);
    expect(store.getStringList('blanks'), isEmpty);
    expect(store.getStringList('missing'), isEmpty);
  });

  test('pushRecent keeps the newest path first and drops the tail', () {
    final store = SettingsStore.inMemory();
    store.pushRecent(SettingsKeys.recentFiles, 'a.dxf', limit: 2);
    store.pushRecent(SettingsKeys.recentFiles, 'b.dxf', limit: 2);
    store.pushRecent(SettingsKeys.recentFiles, 'a.dxf', limit: 2);
    expect(store.getStringList(SettingsKeys.recentFiles), ['a.dxf', 'b.dxf']);
    store.pushRecent(SettingsKeys.recentFiles, 'c.dxf', limit: 2);
    expect(store.getStringList(SettingsKeys.recentFiles), ['c.dxf', 'a.dxf']);
    store.set(SettingsKeys.showGrid, true);
    store.set(SettingsKeys.showGrid, true);
    store.set(SettingsKeys.showGrid, null);
    expect(store.values.containsKey(SettingsKeys.showGrid), isFalse);
  });

  test('pushRecent ignores a blank path so it cannot hide real files', () {
    final store = SettingsStore.inMemory({
      SettingsKeys.recentFiles: ['a.dxf'],
    });
    store.pushRecent(SettingsKeys.recentFiles, '   ');
    store.pushRecent(SettingsKeys.recentFiles, '');
    expect(store.getStringList(SettingsKeys.recentFiles), ['a.dxf']);
    store.pushRecent(SettingsKeys.recentFiles, '  b.dxf  ');
    expect(store.getStringList(SettingsKeys.recentFiles), ['b.dxf', 'a.dxf']);
  });

  test(
    'a corrupt file is treated as empty and a flush can be reread',
    () async {
      final dir = Directory.systemTemp.createTempSync('fancad-settings');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/settings.json').writeAsStringSync('{not json');

      final store = await SettingsStore.open(dir.path);
      expect(store.values, isEmpty);
      store.set(SettingsKeys.orthoMode, true);
      await store.flush();

      final reopened = await SettingsStore.open(dir.path);
      expect(reopened.getBool(SettingsKeys.orthoMode), isTrue);
      store.dispose();
      reopened.dispose();
    },
  );
}
