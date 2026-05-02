import 'package:dartssh2/src/sftp/sftp_name.dart';

void main() {
  print('Testing longname parsing...\n');

  // Test cases based on your examples
  final testCases = [
    'drwxr-xr-x    3 root     root         4096 Jul 11  2024 project',
    'drwxr-xr-x    4 root     root         4096 May 27  2024 node_projects',
    '-rw-r--r--    1 root     root         1607 Feb  8  2025 .prompt3',
    '-rw-r--r--    1 ubuntu   ubuntu       1024 Jan  1  2025 test.txt',
    'drwxr-xr-x    2 www-data www-data     4096 Dec 25  2024 web',
  ];

  for (int i = 0; i < testCases.length; i++) {
    final longname = testCases[i];
    final result = SftpName.parseLongname(longname);
    
    print('Test ${i + 1}:');
    print('  Longname: $longname');
    print('  Parsed User: ${result['user']}');
    print('  Parsed Group: ${result['group']}');
    print('');
  }

  // Test malformed cases
  print('Testing malformed cases:');
  final malformedCases = [
    '',
    'invalid',
    'drwxr-xr-x',
    'drwxr-xr-x 3',
    'drwxr-xr-x 3 root',
  ];

  for (final longname in malformedCases) {
    final result = SftpName.parseLongname(longname);
    print('  "$longname" -> User: ${result['user']}, Group: ${result['group']}');
  }
}