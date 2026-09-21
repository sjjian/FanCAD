import 'package:fancad/fancad.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open bumps the request so the same file still reloads', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(pluginEditorNotifierProvider.notifier);

    editor.open('demo', 'src/main.js');
    expect(
      editor.target,
      const PluginEditorTargetModel(id: 'demo', relative: 'src/main.js'),
    );
    expect(editor.request, 1);

    editor.open('demo', 'src/other.js');
    expect(editor.request, 2);
    expect(editor.target?.relative, 'src/other.js');
  });
}
