import 'dart:typed_data';

import 'package:dartssh2/src/utils/chacha.dart';
import 'package:test/test.dart';

void main() {
  group('splitOpenSSHChaChaKeys', () {
    test('splits length and payload keys in OpenSSH order', () {
      final material = Uint8List.fromList(List<int>.generate(64, (i) => i));

      final keys = splitOpenSSHChaChaKeys(material);

      expect(
          keys.lenKey,
          equals(Uint8List.fromList(List<int>.generate(32, (i) => i))));
      expect(keys.encKey,
          equals(Uint8List.fromList(List<int>.generate(32, (i) => i + 32))));
    });

    test('throws ArgumentError for incorrect key size', () {
      final material = Uint8List(63);

      expect(
        () => splitOpenSSHChaChaKeys(material),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
