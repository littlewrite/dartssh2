import 'dart:typed_data';

class OpenSSHChaChaKeys {
  const OpenSSHChaChaKeys({
    required this.lenKey,
    required this.encKey,
  });

  final Uint8List lenKey;
  final Uint8List encKey;
}

/// Splits OpenSSH ChaCha20-Poly1305 key material into length and payload keys.
///
/// OpenSSH derives 64 bytes per direction. The first 32 bytes rekey the packet
/// length stream cipher, while the remaining 32 bytes encrypt payloads and
/// derive Poly1305 one-time keys.
OpenSSHChaChaKeys splitOpenSSHChaChaKeys(
  Uint8List keyMaterial,
) {
  if (keyMaterial.length != 64) {
    throw ArgumentError.value(
      keyMaterial.length,
      'keyMaterial.length',
      'OpenSSH ChaCha20-Poly1305 requires exactly 64 bytes of key material',
    );
  }

  return OpenSSHChaChaKeys(
    lenKey: Uint8List.sublistView(keyMaterial, 0, 32),
    encKey: Uint8List.sublistView(keyMaterial, 32, 64),
  );
}
