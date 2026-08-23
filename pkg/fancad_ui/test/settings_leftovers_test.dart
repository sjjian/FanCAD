import 'dart:io';

import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a missing file is treated as empty rather than a failed start',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'fancad-settings-missing',
      );
      addTearDown(() => dir.deleteSync(recursive: true));

      final store = await SettingsStore.open(dir.path);
      expect(store.values, isEmpty);
      expect(store.getString('missing', fallback: 'dark'), 'dark');
      expect(store.getDouble('missing', fallback: 1.5), 1.5);
      expect(store.getInt('missing', fallback: 7), 7);
      store.dispose();
    },
  );

  test(
    'a JSON array is treated as empty so a non-object file cannot load',
    () async {
      final dir = Directory.systemTemp.createTempSync('fancad-settings-array');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/settings.json').writeAsStringSync('[1, 2]');

      final store = await SettingsStore.open(dir.path);
      expect(store.values, isEmpty);
      store.dispose();
    },
  );

  test(
    'flush creates a missing support directory so first run can persist',
    () async {
      final parent = Directory.systemTemp.createTempSync(
        'fancad-settings-first',
      );
      addTearDown(() => parent.deleteSync(recursive: true));
      final support = Directory('${parent.path}/nested/support');
      expect(support.existsSync(), isFalse);

      final store = await SettingsStore.open(support.path);
      store.set(SettingsKeys.themeBrightness, 'light');
      await store.flush();

      expect(File('${support.path}/settings.json').existsSync(), isTrue);
      final reopened = await SettingsStore.open(support.path);
      expect(reopened.getString(SettingsKeys.themeBrightness), 'light');
      store.dispose();
      reopened.dispose();
    },
  );
}
