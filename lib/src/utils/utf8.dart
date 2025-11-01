import 'dart:convert';
import 'dart:typed_data';

Uint8List utf8Encode(String input) {
  return Utf8Encoder().convert(input);
}

String utf8Decode(Uint8List input) {
  return Utf8Decoder().convert(input);
}

/// 智能解码字符串，尝试多种编码方式以处理各种特殊字符
///
/// 尝试顺序：
/// 1. UTF-8（标准）
/// 2. 如果UTF-8失败或包含大量替换字符，尝试Latin-1
/// 3. 对于包含中文字符的可能编码，尝试更好的处理
String smartDecodeString(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }

  // 首先尝试标准的UTF-8解码
  String? utf8Result;
  int replacementCharCount = 0;
  try {
    utf8Result = utf8.decode(bytes, allowMalformed: false);
    // 快速检查是否包含替换字符（遍历一次）
    const replacementChar = 0xFFFD; // \uFFFD 的 Unicode 码点
    for (int i = 0; i < utf8Result.length; i++) {
      if (utf8Result.codeUnitAt(i) == replacementChar) {
        replacementCharCount++;
      }
    }

    // 如果没有替换字符，直接返回（最优化路径）
    if (replacementCharCount == 0) {
      return utf8Result;
    }
  } catch (e) {
    // UTF-8解码失败，继续尝试其他方法
  }

  // 如果标准UTF-8解码失败或包含替换字符，使用allowMalformed模式
  String decoded;
  if (utf8Result != null) {
    decoded = utf8Result;
  } else {
    try {
      decoded = utf8.decode(bytes, allowMalformed: true);
      // 如果之前没有计数，现在计数替换字符
      if (replacementCharCount == 0) {
        const replacementChar = 0xFFFD;
        for (int i = 0; i < decoded.length; i++) {
          if (decoded.codeUnitAt(i) == replacementChar) {
            replacementCharCount++;
          }
        }
      }
    } catch (e) {
      // 即使allowMalformed也失败，使用Latin-1作为最后手段
      return latin1.decode(bytes);
    }
  }

  final totalChars = decoded.length;

  // 如果替换字符过多（超过30%），可能是编码不匹配，尝试其他编码
  if (replacementCharCount > 0 && replacementCharCount > totalChars * 0.3) {
    // 对于非UTF-8编码，使用Latin-1作为fallback
    // 注意：Latin-1不能正确显示GBK编码的中文，但可以保留字节信息
    // 对于其他单字节编码（如Windows-1252），Latin-1通常可以处理
    final latin1Result = latin1.decode(bytes);
    
    // 在字节级别高效计算可打印字符数量（避免字符串分割）
    int latin1PrintableChars = 0;
    int utf8PrintableChars = 0;
    
    // 统计Latin-1的可打印字符（直接在字节级别）
    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      if (byte >= 32 || byte == 9 || byte == 10 || byte == 13) {
        latin1PrintableChars++;
      }
    }

    // 统计UTF-8解码结果的可打印字符（排除替换字符）
    const replacementChar = 0xFFFD;
    for (int i = 0; i < decoded.length; i++) {
      final codeUnit = decoded.codeUnitAt(i);
      if (codeUnit != replacementChar) {
        if (codeUnit >= 32 || codeUnit == 9 || codeUnit == 10 || codeUnit == 13) {
          utf8PrintableChars++;
        }
      }
    }

    // 检查GBK模式（仅在需要时进行，并且限制检测范围以提高效率）
    // 如果Latin-1明显更好，就不需要检测GBK
    bool shouldUseLatin1 = latin1PrintableChars > utf8PrintableChars;

    if (!shouldUseLatin1 && bytes.length > 2) {
      // 仅在Latin-1不确定时检测GBK模式（采样检测以提高效率）
      int gbkPatternCount = 0;
      final step = bytes.length > 100 ? (bytes.length / 100).ceil() : 1;

      for (int i = 0; i < bytes.length - 1; i += step) {
        final byte1 = bytes[i];
        final byte2 = bytes[i + 1];
        // GBK字符范围
        if (byte1 >= 0x81 && byte1 <= 0xFE && 
            byte2 >= 0x40 && byte2 <= 0xFE) {
          gbkPatternCount++;
        }
      }

      // 如果检测到大量GBK模式，且Latin-1结果更完整，使用Latin-1
      final gbkRatio = (gbkPatternCount * step) / bytes.length;
      if (gbkRatio > 0.25) {
        final utf8ValidLength = totalChars - replacementCharCount;
        if (latin1Result.length > utf8ValidLength) {
          shouldUseLatin1 = true;
        }
      }
    }

    if (shouldUseLatin1) {
      return latin1Result;
    }
  }

  // 如果UTF-8结果相对合理，返回它（即使包含一些替换字符）
  return decoded;
}
