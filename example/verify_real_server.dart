import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// Fill these fields before running:
///
///   dart run example/verify_real_server.dart
///
/// Set [printDebugLogs] / [printTraceLogs] only when you need transport-level
/// troubleshooting.
class VerifyConfig {
  static const host = '127.0.0.1';
  static const port = 22;
  static const username = 'root';

  /// Option 1: password auth
  static const password = '';

  /// Option 2: private key auth
  static const privateKeyPath = '';

  /// Optional strict pinning of the server host key MD5 fingerprint.
  /// Example: 'aa:bb:cc:dd:...'
  static const expectedHostKeyMd5 = '';

  /// Probes
  static const runExplicitHostKeyProbe = true;
  static const runCompatibilityProbeWithoutVerifier = true;
  static const runChannelCloseProbe = true;
  static const runLargeStdoutDefaultProbe = true;
  static const runLargeStdoutCtrProbe = true;
  static const runLargeStdoutCtrEtmProbe = true;
  static const runLargeStdoutGcmProbe = true;
  static const runLargeStdoutChaChaProbe = true;
  static const runSftpProbe = true;
  static const runCbcProbe = false;

  /// Logging
  static const printDebugLogs = false;
  static const printTraceLogs = false;

  /// Commands: change these if your server is not a typical Unix shell.
  static const basicCommand = 'uname -a';
  static const channelCloseCommand =
      r'''sh -lc "printf 'channel-close-ok\n'"''';
  static const largeStdoutCommand =
      r'''sh -lc "head -c 1048576 /dev/zero | tr '\0' 'A'"''';
  static const cbcCommand = r'''sh -lc "printf 'cbc-ok\n'"''';

  /// SFTP
  static const sftpListPath = '.';
}

Future<void> main() async {
  _validateConfig();

  final results = <String, Object>{};

  await _runProbe(
    results,
    'explicit-hostkey',
    enabled: VerifyConfig.runExplicitHostKeyProbe,
    body: () async {
      final client = await _connect(
        label: 'explicit-hostkey',
        useHostKeyVerifier: true,
      );
      try {
        await _authenticate(client, 'explicit-hostkey');
        await _runBasicCommand(client, 'explicit-hostkey');
      } finally {
        await _closeClient(client);
      }
    },
  );

  await _runProbe(
    results,
    'compat-without-verifier',
    enabled: VerifyConfig.runCompatibilityProbeWithoutVerifier,
    body: () async {
      final client = await _connect(
        label: 'compat-without-verifier',
        useHostKeyVerifier: false,
      );
      try {
        await _authenticate(client, 'compat-without-verifier');
        await _runBasicCommand(client, 'compat-without-verifier');
      } finally {
        await _closeClient(client);
      }
    },
  );

  await _runProbe(
    results,
    'channel-close',
    enabled: VerifyConfig.runChannelCloseProbe,
    body: () async {
      final client = await _connect(
        label: 'channel-close',
        useHostKeyVerifier: true,
      );
      try {
        await _authenticate(client, 'channel-close');
        await _runChannelCloseProbe(client);
      } finally {
        await _closeClient(client);
      }
    },
  );

  await _runLargeStdoutProbeWithAlgorithms(
    results,
    label: 'large-stdout-default',
    enabled: VerifyConfig.runLargeStdoutDefaultProbe,
    algorithms: const SSHAlgorithms(),
  );
  await _runLargeStdoutProbeWithAlgorithms(
    results,
    label: 'large-stdout-ctr',
    enabled: VerifyConfig.runLargeStdoutCtrProbe,
    algorithms: const SSHAlgorithms(
      cipher: [SSHCipherType.aes256ctr],
      mac: [SSHMacType.hmacSha256],
    ),
  );
  await _runLargeStdoutProbeWithAlgorithms(
    results,
    label: 'large-stdout-ctr-etm',
    enabled: VerifyConfig.runLargeStdoutCtrEtmProbe,
    algorithms: const SSHAlgorithms(
      cipher: [SSHCipherType.aes256ctr],
      mac: [SSHMacType.hmacSha256Etm],
    ),
  );
  await _runLargeStdoutProbeWithAlgorithms(
    results,
    label: 'large-stdout-gcm',
    enabled: VerifyConfig.runLargeStdoutGcmProbe,
    algorithms: const SSHAlgorithms(
      cipher: [SSHCipherType.aes128gcm],
    ),
  );
  await _runLargeStdoutProbeWithAlgorithms(
    results,
    label: 'large-stdout-chacha',
    enabled: VerifyConfig.runLargeStdoutChaChaProbe,
    algorithms: const SSHAlgorithms(
      cipher: [SSHCipherType.chacha20poly1305],
    ),
  );

  await _runProbe(
    results,
    'sftp',
    enabled: VerifyConfig.runSftpProbe,
    body: () async {
      final client = await _connect(
        label: 'sftp',
        useHostKeyVerifier: true,
      );
      try {
        await _authenticate(client, 'sftp');
        await _runSftpProbe(client);
      } finally {
        await _closeClient(client);
      }
    },
  );

  await _runProbe(
    results,
    'cbc',
    enabled: VerifyConfig.runCbcProbe,
    body: () async {
      final client = await _connect(
        label: 'cbc',
        useHostKeyVerifier: true,
        algorithms: const SSHAlgorithms(
          cipher: [SSHCipherType.aes128cbc],
          mac: [SSHMacType.hmacSha256],
        ),
      );
      try {
        await _authenticate(client, 'cbc');
        await _runCommand(client, VerifyConfig.cbcCommand, label: 'cbc');
      } finally {
        await _closeClient(client);
      }
    },
  );

  _log('\n=== Summary ===');
  for (final entry in results.entries) {
    _log('${entry.key}: ${entry.value}');
  }
}

Future<void> _runProbe(
  Map<String, Object> results,
  String label, {
  required bool enabled,
  required Future<void> Function() body,
}) async {
  if (!enabled) {
    results[label] = 'skipped';
    return;
  }

  _log('\n=== Probe: $label ===');
  try {
    await _runGuarded(body);
    results[label] = 'ok';
  } catch (error, stackTrace) {
    results[label] = 'failed: $error';
    _log('[$label] failed: $error');
    _log('[$label] stack: $stackTrace');
  }
}

Future<void> _runGuarded(Future<void> Function() body) async {
  final completer = Completer<void>();

  runZonedGuarded(() async {
    try {
      await body();
      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }, (error, stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    } else {
      _log('[guard] late uncaught error: $error');
      _log('[guard] late stack: $stackTrace');
    }
  });

  await completer.future;
}

Future<void> _runLargeStdoutProbeWithAlgorithms(
  Map<String, Object> results, {
  required String label,
  required bool enabled,
  required SSHAlgorithms algorithms,
}) async {
  await _runProbe(
    results,
    label,
    enabled: enabled,
    body: () async {
      final client = await _connect(
        label: label,
        useHostKeyVerifier: true,
        algorithms: algorithms,
      );
      try {
        await _authenticate(client, label);
        await _runLargeStdoutProbe(client, label: label);
      } finally {
        await _closeClient(client);
      }
    },
  );
}

Future<SSHClient> _connect({
  required String label,
  required bool useHostKeyVerifier,
  SSHAlgorithms algorithms = const SSHAlgorithms(),
}) async {
  _log('[$label] connecting to ${VerifyConfig.username}@'
      '${VerifyConfig.host}:${VerifyConfig.port}');
  _log(
      '[$label] requested ciphers=${algorithms.cipher.map((e) => e.name).join(",")}');
  _log(
      '[$label] requested macs=${algorithms.mac.map((e) => e.name).join(",")}');

  final identities = await _loadIdentities();
  final socket = await SSHSocket.connect(VerifyConfig.host, VerifyConfig.port);

  return SSHClient(
    socket,
    username: VerifyConfig.username,
    algorithms: algorithms,
    identities: identities.isEmpty ? null : identities,
    onPasswordRequest: _passwordHandler,
    onVerifyHostKey: useHostKeyVerifier ? _verifyHostKey : null,
    printDebug: VerifyConfig.printDebugLogs
        ? (message) => _log('[$label][debug] ${message ?? ''}')
        : null,
    printTrace: VerifyConfig.printTraceLogs
        ? (message) => _log('[$label][trace] ${message ?? ''}')
        : null,
  );
}

Future<void> _authenticate(SSHClient client, String label) async {
  await client.authenticated.timeout(const Duration(seconds: 20));
  _log('[$label] authenticated');
  _log('[$label] remoteVersion=${client.remoteVersion}');
}

Future<void> _runBasicCommand(SSHClient client, String label) async {
  await _runCommand(client, VerifyConfig.basicCommand, label: label);
}

Future<void> _runCommand(
  SSHClient client,
  String command, {
  required String label,
}) async {
  _log('[$label] command: $command');
  final result = await client.runWithResult(command);
  _log('[$label] exitCode=${result.exitCode} exitSignal=${result.exitSignal}');
  _log('[$label] stdout(${result.stdout.length} bytes): '
      '${_previewUtf8(result.stdout)}');
  if (result.stderr.isNotEmpty) {
    _log('[$label] stderr(${result.stderr.length} bytes): '
        '${_previewUtf8(result.stderr)}');
  }
}

Future<void> _runChannelCloseProbe(SSHClient client) async {
  _log('[channel-close] starting session');
  final session = await client.execute(VerifyConfig.channelCloseCommand);

  final stdoutDone =
      session.stdout.drain<void>().timeout(const Duration(seconds: 10));
  final stderrDone =
      session.stderr.drain<void>().timeout(const Duration(seconds: 10));

  await session.done.timeout(const Duration(seconds: 10));
  await Future.wait([stdoutDone, stderrDone]);

  _log('[channel-close] session.done completed');
  _log('[channel-close] stdout/stderr drain completed');
  _log('[channel-close] exitCode=${session.exitCode} '
      'exitSignal=${session.exitSignal}');
}

Future<void> _runLargeStdoutProbe(
  SSHClient client, {
  required String label,
}) async {
  _log('[$label] command: ${VerifyConfig.largeStdoutCommand}');
  final session = await client.execute(VerifyConfig.largeStdoutCommand);

  final stdoutBytesFuture = _countBytes(session.stdout);
  final stderrBytesFuture = _collectBytes(session.stderr);

  await session.done.timeout(const Duration(seconds: 30));

  final stdoutBytes = await stdoutBytesFuture;
  final stderrBytes = await stderrBytesFuture;

  _log('[$label] stdoutBytes=$stdoutBytes');
  _log('[$label] stderrBytes=${stderrBytes.length}');
  _log('[$label] exitCode=${session.exitCode} '
      'exitSignal=${session.exitSignal}');
  if (stdoutBytes != 1024 * 1024) {
    throw StateError(
      '$label expected 1048576 bytes, got $stdoutBytes',
    );
  }
}

Future<void> _runSftpProbe(SSHClient client) async {
  _log('[sftp] listing ${VerifyConfig.sftpListPath}');
  final sftp = await client.sftp();
  final items = await sftp.listdir(VerifyConfig.sftpListPath);
  _log('[sftp] itemCount=${items.length}');

  for (final item in items.take(10)) {
    _log('[sftp] ${item.longname}');
  }
}

Future<List<SSHKeyPair>> _loadIdentities() async {
  final path = VerifyConfig.privateKeyPath.trim();
  if (path.isEmpty) {
    return const <SSHKeyPair>[];
  }

  final pem = await File(path).readAsString();
  final keys = SSHKeyPair.fromPem(pem);
  _log('[config] loaded ${keys.length} private key(s) from $path');
  return keys;
}

Future<String?> _passwordHandler() async {
  if (VerifyConfig.password.isNotEmpty) {
    return VerifyConfig.password;
  }

  if (!stdin.hasTerminal || !stdout.hasTerminal) {
    return null;
  }

  stdout.write('Password for ${VerifyConfig.username}@${VerifyConfig.host}: ');
  try {
    stdin.echoMode = false;
    return stdin.readLineSync();
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }
}

Future<bool> _verifyHostKey(String type, Uint8List fingerprint) async {
  final actualMd5 = _fingerprintHex(fingerprint);
  _log('[hostkey] type=$type md5=$actualMd5');

  final expectedMd5 = VerifyConfig.expectedHostKeyMd5.trim().toLowerCase();
  if (expectedMd5.isEmpty) {
    _log('[hostkey] no pinned MD5 configured, accepting');
    return true;
  }

  final accepted = actualMd5.toLowerCase() == expectedMd5;
  _log('[hostkey] pinned-md5=$expectedMd5 match=$accepted');
  return accepted;
}

Future<int> _countBytes(Stream<Uint8List> stream) async {
  var total = 0;
  await for (final chunk in stream) {
    total += chunk.length;
  }
  return total;
}

Future<Uint8List> _collectBytes(Stream<Uint8List> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _previewUtf8(Uint8List bytes, {int limit = 160}) {
  final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\n', r'\n');
  if (text.length <= limit) {
    return text;
  }
  return '${text.substring(0, limit)}...';
}

String _fingerprintHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
}

void _validateConfig() {
  if (VerifyConfig.host == 'YOUR_SSH_HOST' ||
      VerifyConfig.username == 'YOUR_SSH_USERNAME') {
    stderr
        .writeln('Edit example/verify_real_server.dart and fill VerifyConfig.');
    exit(64);
  }

  if (VerifyConfig.password.isEmpty && VerifyConfig.privateKeyPath.isEmpty) {
    _log(
        '[config] no password/privateKeyPath configured; terminal prompt may be used');
  }
}

Future<void> _closeClient(SSHClient client) async {
  client.close();
  try {
    await client.done.timeout(const Duration(seconds: 5));
  } catch (_) {}
}

void _log(String message) {
  final timestamp = DateTime.now().toIso8601String();
  stdout.writeln('[$timestamp] $message');
}
