import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/src/sftp/sftp_file_attrs.dart';
import 'package:dartssh2/src/message/base.dart';

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
    final filenameBytes = reader.readString();
    final longnameBytes = reader.readString();
    final attr = SftpFileAttrs.readFrom(reader);

    String filename;
    try {
      filename = utf8.decode(filenameBytes, allowMalformed: true);
    } catch (_) {
      filename = String.fromCharCodes(filenameBytes);
    }

    String longname;
    try {
      longname = utf8.decode(longnameBytes, allowMalformed: true);
    } catch (_) {
      longname = String.fromCharCodes(longnameBytes);
    }

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
    writer.writeString(Uint8List.fromList(utf8.encode(filename)));
    writer.writeString(Uint8List.fromList(utf8.encode(longname)));
    attr.writeTo(writer);
  }

  @override
  String toString() {
    return 'SftpName(filename: $filename, longname: $longname, attr: $attr)';
  }
}
