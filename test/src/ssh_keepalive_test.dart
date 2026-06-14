import 'dart:async';

import 'package:dartssh2/src/ssh_keepalive.dart';
import 'package:test/test.dart';

void main() {
  test('stops and reports ping errors without leaking to the zone', () async {
    final zoneErrors = <Object>[];
    final keepAliveErrors = <Object>[];
    late final SSHKeepAlive keepAlive;

    await runZonedGuarded(() async {
      keepAlive = SSHKeepAlive(
        interval: const Duration(milliseconds: 1),
        ping: () async => throw StateError('socket closed'),
        onError: (error, stackTrace) {
          keepAliveErrors.add(error);
        },
      );

      keepAlive.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      keepAlive.stop();
    }, (error, stackTrace) {
      zoneErrors.add(error);
    });

    expect(keepAliveErrors, hasLength(1));
    expect(keepAliveErrors.single, isA<StateError>());
    expect(zoneErrors, isEmpty);
  });

  test('does not start overlapping pings', () async {
    var activePings = 0;
    var maxActivePings = 0;
    var pingCount = 0;
    final completer = Completer<void>();
    final keepAlive = SSHKeepAlive(
      interval: const Duration(milliseconds: 1),
      ping: () async {
        pingCount += 1;
        activePings += 1;
        maxActivePings =
            activePings > maxActivePings ? activePings : maxActivePings;
        await completer.future;
        activePings -= 1;
      },
    );

    keepAlive.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    keepAlive.stop();

    expect(pingCount, greaterThanOrEqualTo(1));
    expect(maxActivePings, 1);
  });
}
