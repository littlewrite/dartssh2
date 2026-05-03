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
/// OpenSSH derives 64 bytes per direction. Per the OpenSSH transport spec,
/// the first 32 bytes become K2 for payload encryption and Poly1305 key
/// derivation, while the remaining 32 bytes become K1 for encrypting the
/// packet length field.
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
    encKey: Uint8List.sublistView(keyMaterial, 0, 32),
    lenKey: Uint8List.sublistView(keyMaterial, 32, 64),
  );
}
