import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const authoring = PluginAuthoring();

  test('the authoring loop names the commands a repair turn must call', () {
    expect(
      PluginAuthoring.commandIds,
      containsAll([
        'plugins.scaffold',
        'plugins.write',
        'plugins.reload',
        'plugins.typings',
      ]),
    );
  });

  test('a repair prompt without source does not invent a main.js listing', () {
    final prompt = authoring.repairPrompt(pluginId: 'acme.safe', error: 'boom');
    expect(prompt, contains('acme.safe'));
    expect(prompt, contains('boom'));
    expect(prompt, isNot(contains('Current main.js:')));
    expect(prompt, isNot(contains('The fancad API')));
  });

  test('only activation-shaped results are offered for repair', () {
    expect(
      authoring.isActivationFailure(
        const CommandResult.ok(data: {'state': 'disabled'}),
      ),
      isTrue,
    );
    expect(
      authoring.isActivationFailure(
        const CommandResult.ok(data: {'error': 'eval threw'}),
      ),
      isTrue,
    );
    expect(
      authoring.isActivationFailure(
        const CommandResult.failed('plugins.eval: ReferenceError'),
      ),
      isTrue,
    );
    expect(
      authoring.isActivationFailure(
        const CommandResult.failed('No such file: main.js'),
      ),
      isFalse,
    );
    expect(
      authoring.isActivationFailure(const CommandResult.cancelled()),
      isFalse,
    );
  });
}
