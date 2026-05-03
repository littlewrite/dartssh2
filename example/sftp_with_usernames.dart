import 'package:dartssh2/dartssh2.dart';

const host = '';
const port = 22;
const username = 'root';
const password = '';

void main() async {
  final socket = await SSHSocket.connect(host, port);

  final client = SSHClient(
    socket,
    username: username,
    onPasswordRequest: () => password,
  );

  final sftp = await client.sftp();
  final items = await sftp.listdir('/home');

  print('Directory listing with user/group names:');
  print('');

  for (final item in items) {
    final type = item.attr.isDirectory ? 'DIR' : 'FILE';
    final size = item.attr.size?.toString().padLeft(10) ?? '         -';
    final user = item.attr.userName ?? 'unknown';
    final group = item.attr.groupName ?? 'unknown';
    
    print('$type $size ${user.padRight(10)} ${group.padRight(10)} ${item.filename}');
  }

  client.close();
  await client.done;
}
