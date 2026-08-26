import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failed activation becomes a repair prompt that includes the API', () {
    const authoring = PluginAuthoring();
    final prompt = authoring.repairPrompt(
      pluginId: 'demo.wall',
      error: 'ReferenceError: fancadd is not defined',
      source: 'fancadd.commands.register("x", () => {});',
      typings: 'declare const fancad: FanCadApi;',
    );
    expect(prompt, contains('demo.wall'));
    expect(prompt, contains('ReferenceError'));
    expect(prompt, contains('plugins.write'));
    expect(prompt, contains('declare const fancad'));
  });

  test('activation-looking failures are recognised', () {
    const authoring = PluginAuthoring();
    expect(
      authoring.isActivationFailure(
        const CommandResult.failed('could not activate demo: SyntaxError'),
      ),
      isTrue,
    );
    expect(
      authoring.isActivationFailure(
        const CommandResult.ok(data: {'state': 'failed', 'error': 'boom'}),
      ),
      isTrue,
    );
    expect(
      authoring.isActivationFailure(const CommandResult.ok(message: 'ok')),
      isFalse,
    );
  });
}
