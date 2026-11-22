import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Códigos de 6 dígitos (TOTP, RFC 6238) como los de Google Authenticator.
/// Se usan para comprobar que el usuario configuró bien su app antes de
/// activar la verificación en dos pasos en el servidor.
class Totp {
  static Uint8List _base32(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in clean.split('')) {
      buffer = (buffer << 5) | alphabet.indexOf(ch);
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xFF);
      }
    }
    return Uint8List.fromList(out);
  }

  static String code(String secret, {DateTime? at}) {
    final t = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000 ~/ 30;
    final msg = ByteData(8)..setInt64(0, t);
    final hash = Hmac(sha1, _base32(secret)).convert(msg.buffer.asUint8List()).bytes;
    final offset = hash.last & 0x0f;
    final value = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
    return (value % 1000000).toString().padLeft(6, '0');
  }

  /// Acepta el código actual y el de 30 s antes o después (desfase del reloj).
  static bool verify(String secret, String input) {
    final c = input.replaceAll(RegExp(r'\s'), '');
    if (c.length != 6) return false;
    final now = DateTime.now();
    for (final d in [-30, 0, 30]) {
      if (code(secret, at: now.add(Duration(seconds: d))) == c) return true;
    }
    return false;
  }

  static String uri(String secret, String account) =>
      'otpauth://totp/GPS%20App:${Uri.encodeComponent(account)}'
      '?secret=$secret&issuer=GPS%20App&digits=6&period=30';
}
