@Tags(['integration'])
library ssh_hostkey_verification_details_test;

import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('host key verifier exposes raw key and SHA256 details', () async {
    SSHHostKeyVerificationDetails? captured;

    final client = SSHClient(
      await SSHSocket.connect(testSshHost, testSshPort),
      username: 'demo',
      onPasswordRequest: () => 'password',
      onVerifyHostKey: (details) async {
        captured = details;
        return true;
      },
    );

    try {
      await client.authenticated;
      expect(captured, isNotNull);
      expect(captured!.type, isNotEmpty);
      expect(captured!.hostKey, isNotEmpty);
      expect(captured!.fingerprintMd5, isNotEmpty);
      expect(captured!.fingerprintSha256, isNotEmpty);
      expect(captured!.fingerprintSha256Base64, isNotEmpty);
      expect(
        captured!.fingerprintMd5,
        orderedEquals(MD5Digest().process(captured!.hostKey)),
      );
      expect(
        captured!.fingerprintSha256,
        orderedEquals(SHA256Digest().process(captured!.hostKey)),
      );
      expect(
        captured!.fingerprintSha256Base64,
        base64.encode(captured!.fingerprintSha256).replaceAll('=', ''),
      );
      expect(
        captured!.fingerprintMd5Hex,
        captured!.fingerprintMd5
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':'),
      );
    } finally {
      client.close();
    }
  });
}
