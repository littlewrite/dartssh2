import 'dart:async';

/// A wrapper around [Timer] that calls [ping] every [interval], and can be
/// started or stopped idempotently.
class SSHKeepAlive {
  Timer? _timer;
  bool _isPinging = false;

  final Duration interval;

  final Future<void> Function() ping;

  final void Function(Object error, StackTrace stackTrace)? onError;

  SSHKeepAlive({
    required this.ping,
    this.interval = const Duration(seconds: 10),
    this.onError,
  });

  void start() {
    _timer ??= Timer.periodic(interval, (timer) {
      if (_isPinging) return;
      _isPinging = true;
      ping().then((_) {
        _isPinging = false;
      }, onError: (Object error, StackTrace stackTrace) {
        _isPinging = false;
        stop();
        onError?.call(error, stackTrace);
      });
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPinging = false;
  }
}
