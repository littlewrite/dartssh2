import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/src/message/base.dart';

class SSHHostKeyVerificationDetails {
  const SSHHostKeyVerificationDetails({
    required this.type,
    required this.hostKey,
    required this.fingerprintMd5,
    required this.fingerprintSha256,
    required this.fingerprintSha256Base64,
  });

  /// The negotiated host key algorithm name (e.g. "ssh-ed25519", "ssh-rsa").
  final String type;

  /// The raw host key bytes, including the algorithm type prefix.
  final Uint8List hostKey;

  /// MD5 digest of [hostKey].
  ///
  /// Legacy fingerprint format. Prefer [fingerprintSha256] or
  /// [fingerprintSha256Base64] for modern use.
  final Uint8List fingerprintMd5;

  /// SHA-256 digest of [hostKey].
  final Uint8List fingerprintSha256;

  /// Base64-encoded SHA-256 fingerprint (without padding, matching OpenSSH
  /// output format).
  final String fingerprintSha256Base64;

  /// Colon-delimited hex encoding of [fingerprintMd5].
  ///
  /// Matches the legacy OpenSSH MD5 fingerprint format, e.g.
  /// `"43:51:43:a1:b5:fc:8b:b7:0a:3a:a9:b1:0f:66:73:a8"`.
  String get fingerprintMd5Hex =>
      fingerprintMd5.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
}

/// Handler called when the server's host key is received and cryptographically
/// verified.
///
/// The handler receives [SSHHostKeyVerificationDetails] with the negotiated
/// host key type, raw key bytes, and multiple fingerprint formats. Return
/// `true` to accept the host key and continue the connection, or `false` to
/// reject it.
///
/// Returning `null` from an async handler is treated as rejection. If no
/// handler is provided, the connection is rejected for security.
typedef SSHHostkeyVerifyHandler = FutureOr<bool> Function(
  SSHHostKeyVerificationDetails details,
);

abstract class SSHHostKey {
  /// Encode the host key to SSH encoded data.
  Uint8List encode();

  static String getType(Uint8List encodedHostKey) {
    if (encodedHostKey.length < 4) {
      throw ArgumentError('Invalid encoded host key');
    }
    final reader = SSHMessageReader(encodedHostKey);
    return reader.readUtf8();
  }
}

abstract class SSHSignature {
  /// Encode the host key to SSH encoded data.
  Uint8List encode();

  static String getType(Uint8List encodedHostKey) {
    if (encodedHostKey.length < 4) {
      throw ArgumentError('Invalid encoded host key');
    }
    final reader = SSHMessageReader(encodedHostKey);
    return reader.readUtf8();
  }
}
