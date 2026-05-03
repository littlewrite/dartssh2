import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/message/base.dart';
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:test/test.dart';

void main() {
  group('SSHChannel', () {
    test('stdout stream handles remote channel close correctly', () async {
      final sentMessages = <SSHMessage>[];
      final controller = SSHChannelController(
        localId: 1,
        localMaximumPacketSize: 1024 * 1024,
        localInitialWindowSize: 1024 * 1024,
        remoteId: 2,
        remoteMaximumPacketSize: 1024 * 1024,
        remoteInitialWindowSize: 1024 * 1024,
        sendMessage: sentMessages.add,
      );
      final session = SSHSession(controller.channel);
      final drainFuture = session.stdout.drain<void>();

      controller.handleMessage(
        SSH_Message_Channel_Close(recipientChannel: controller.localId),
      );

      await drainFuture.timeout(const Duration(seconds: 2));

      expect(
        sentMessages.whereType<SSH_Message_Channel_Close>(),
        hasLength(1),
      );
      expect(sentMessages.whereType<SSH_Message_Channel_EOF>(), isEmpty);
    });

    test('window adjust clamps remote window instead of wrapping', () {
      final controller = SSHChannelController(
        localId: 1,
        localMaximumPacketSize: 1024 * 1024,
        localInitialWindowSize: 1024 * 1024,
        remoteId: 2,
        remoteMaximumPacketSize: 1024 * 1024,
        remoteInitialWindowSize: 0xFFFFFFFE,
        sendMessage: (_) {},
      );

      controller.handleMessage(
        SSH_Message_Channel_Window_Adjust(
          recipientChannel: controller.localId,
          bytesToAdd: 10,
        ),
      );

      expect(controller.debugRemoteWindow, 0xFFFFFFFF);
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
