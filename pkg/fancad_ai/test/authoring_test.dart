import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('the default repair seam never claims an activation failure', () {
    const authoring = NoActivationRepair();
    expect(
      authoring.isActivationFailure(
        const CommandResult.failed('could not activate demo: SyntaxError'),
      ),
      isFalse,
    );
    expect(
      authoring.repairPrompt(pluginId: 'demo.wall', error: 'boom'),
      isEmpty,
    );
  });
}
