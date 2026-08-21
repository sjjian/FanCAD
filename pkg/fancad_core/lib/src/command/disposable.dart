/// Something that can be torn down.
///
/// Every registry in FanCAD hands back a [Disposable] instead of exposing an
/// `unregister` call. Plugin unload then becomes a single operation: dispose
/// the plugin's bag and every contribution it ever made disappears, which is
/// what makes hot reloading safe.
abstract class Disposable {
  void dispose();

  /// Wraps a callback as a [Disposable].
  factory Disposable.callback(void Function() onDispose) =>
      _CallbackDisposable(onDispose);

  /// A disposable that does nothing.
  static const Disposable noop = _NoopDisposable();
}

class _CallbackDisposable implements Disposable {
  _CallbackDisposable(this._onDispose);

  final void Function() _onDispose;
  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose();
  }
}

class _NoopDisposable implements Disposable {
  const _NoopDisposable();

  @override
  void dispose() {}
}

/// Owns a set of disposables and tears them down together.
class DisposableBag implements Disposable {
  DisposableBag({this.debugLabel = ''});

  final String debugLabel;
  final List<Disposable> _children = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;
  int get length => _children.length;

  /// Adds [child] to the bag and returns it for chaining. Disposing an
  /// already-disposed bag disposes the new child immediately, which keeps late
  /// registrations from leaking after a plugin has been unloaded.
  T add<T extends Disposable>(T child) {
    if (_disposed) {
      child.dispose();
      return child;
    }
    _children.add(child);
    return child;
  }

  void addCallback(void Function() onDispose) =>
      add(Disposable.callback(onDispose));

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Reverse order so dependants are torn down before their dependencies.
    for (var i = _children.length - 1; i >= 0; i--) {
      _children[i].dispose();
    }
    _children.clear();
  }
}
