// 试验：同一条 session channel 上先 exec 再 shell 会怎样？
// RFC 4254 规定一条 channel 只能一种请求（exec 或 shell），预期会失败。
// 运行：dart run example/experiment_exec_then_shell.dart [host] [port]

import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

void main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : 'localhost';
  final port = args.length > 1 ? int.tryParse(args[1]) ?? 22 : 22;

  final password = Platform.environment['SSH_PASS'];
  print('Connecting to $host:$port ...');
  final client = SSHClient(
    await SSHSocket.connect(host, port),
    username: args.isNotEmpty ? 'root' : (Platform.environment['USER'] ?? 'root'),
    onPasswordRequest: () {
      if (password != null && password.isNotEmpty) return password;
      stdout.write('Password: ');
      stdin.echoMode = false;
      return stdin.readLineSync() ?? '';
    },
  );

  try {
    final result = await client.experimentExecThenShell(
      'echo __EXEC_DONE__',
      shellTimeout: Duration(seconds: 3),
    );

    print('--- Exec output (${result.execOutput.length} bytes) ---');
    print(utf8.decode(result.execOutput));
    print('---');
    print('sendShell() after exec: shellOk=${result.shellOk}, shellError=${result.shellError}');
    if (result.shellOk == false) {
      print('=> Server replied CHANNEL_FAILURE (same channel cannot become shell after exec).');
    } else if (result.shellError != null) {
      print('=> sendShell() failed or timed out (channel likely already closed after exec).');
    } else if (result.shellOk == true) {
      print('=> Unexpected: server accepted shell on same channel (non-standard?).');
    }
  } finally {
    client.close();
    await client.done;
  }
}
