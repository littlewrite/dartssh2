import 'package:dartssh2/src/sftp/sftp_file_attrs.dart';
import 'package:dartssh2/src/ssh_message.dart';

class SftpName {
  final String filename;

  final String longname;

  final SftpFileAttrs attr;

  SftpName({
    required this.filename,
    required this.longname,
    required this.attr,
  });

  factory SftpName.readFrom(SSHMessageReader reader) {
    final filename = reader.readUtf8(allowMalformed: true);
    final longname = reader.readUtf8(allowMalformed: true);
    final attr = SftpFileAttrs.readFrom(reader);
    return SftpName(
      filename: filename,
      longname: longname,
      attr: attr,
    );
  }

  /// Parse user and group names from longname string
  /// Format: drwxr-xr-x    3 root     root         4096 Jul 11  2024 project
  static Map<String, String?> parseLongname(String longname) {
    final result = <String, String?>{
      'user': null,
      'group': null,
    };

    try {
      // Split by whitespace and filter out empty strings
      final parts = longname.split(RegExp(r'\s+'));
      
      if (parts.length >= 4) {
        // Standard format: permissions links user group size date filename
        // Index:           0           1     2    3     4    5+   6+
        result['user'] = parts[2];
        result['group'] = parts[3];
      }
    } catch (e) {
      // If parsing fails, return nulls
    }

    return result;
  }

  void writeTo(SSHMessageWriter writer) {
    writer.writeUtf8(filename);
    writer.writeUtf8(longname);
    attr.writeTo(writer);
  }

  @override
  String toString() {
    return 'SftpName(filename: $filename, longname: $longname, attr: $attr)';
  }
}
