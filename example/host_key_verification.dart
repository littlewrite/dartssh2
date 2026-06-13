import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

Future<void> main() async {
  final host = Platform.environment['SSH_HOST'] ?? 'localhost';
  final port = int.tryParse(Platform.environment['SSH_PORT'] ?? '') ?? 22;
  final username = Platform.environment['SSH_USERNAME'] ?? 'root';
  final password = Platform.environment['SSH_PASSWORD'];
  final pinnedSha256 =
      (Platform.environment['SSH_HOSTKEY_SHA256'] ?? '').trim();

  final client = SSHClient(
    await SSHSocket.connect(host, port),
    username: username,
    onPasswordRequest: password == null ? null : () => password,
    onVerifyHostKey: (details) async {
      stdout.writeln('Host key type: ${details.type}');
      stdout.writeln('SHA256:${details.fingerprintSha256Base64}');
      stdout.writeln('MD5:${details.fingerprintMd5Hex}');

      if (pinnedSha256.isEmpty) {
        stdout.writeln(
          'No SSH_HOSTKEY_SHA256 pin provided. Accepting for this run only.',
        );
        stdout.writeln(
          'Set SSH_HOSTKEY_SHA256=${details.fingerprintSha256Base64} to pin this host key.',
        );
        return true;
      }

      final accepted = details.fingerprintSha256Base64 == pinnedSha256;
      stdout.writeln(
        accepted
            ? 'Host key matches pinned SHA256 fingerprint.'
            : 'Host key mismatch. Connection will be rejected.',
      );
      return accepted;
    },
  );

  try {
    await client.authenticated;
    stdout.writeln('Connected as $username@$host:$port');
  } finally {
    client.close();
    await client.done;
  }
}
