import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JsException keeps the stack off the one-line form', () {
    expect(const JsException('boom').toString(), 'boom');
    expect(
      const JsException('boom', stack: 'at main.js:1').toString(),
      'boom\nat main.js:1',
    );
  });

  test('evaluate records source and refuses work after dispose', () {
    final engine = ScriptedJsEngine(
      onEvaluate: (source, name) => name == 'main.js' ? 42 : null,
    );

    expect(engine.evaluate('1+1', name: 'main.js'), 42);
    expect(engine.evaluated, ['1+1']);
    expect(engine.memoryUsage, 0);

    engine.dispose();
    expect(engine.isDisposed, isTrue);
    expect(
      () => engine.evaluate('still?'),
      throwsA(
        isA<JsException>().having(
          (error) => error.message,
          'message',
          'engine disposed',
        ),
      ),
    );
  });

  test(
    'call reaches host-installed functions and callGlobal prefers script globals',
    () {
      final engine = ScriptedJsEngine();
      engine.defineFunction('host.log', (String message) => 'logged:$message');
      engine.globals['plugin.run'] = (String id) => 'ran:$id';

      expect(engine.call('host.log', ['hi']), 'logged:hi');
      expect(engine.callGlobal('plugin.run', ['demo']), 'ran:demo');
      expect(
        engine.callGlobal('host.log', ['via-global']),
        'logged:via-global',
      );

      expect(
        () => engine.call('missing', const []),
        throwsA(
          isA<JsException>().having(
            (error) => error.message,
            'message',
            contains('not defined'),
          ),
        ),
      );
      expect(
        () => engine.callGlobal('missing', const []),
        throwsA(
          isA<JsException>().having(
            (error) => error.message,
            'message',
            contains('not a function'),
          ),
        ),
      );
    },
  );
}
