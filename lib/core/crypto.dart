import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// 协议加密工具：MD5 / AES-128-ECB(PKCS7) / HMAC-SHA1 / JWT payload。
class EtsCrypto {
  static String md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

  /// AES-128-ECB + PKCS7，Base64 输出；用于登录 phone / password 字段。
  static String aesEcbEncryptB64(String plain, {String key = 'f05323cb91d422b2'}) {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final input = Uint8List.fromList(utf8.encode(plain));
    final pad = 16 - (input.length % 16);
    final padded = Uint8List(input.length + pad)
      ..setAll(0, input)
      ..fillRange(input.length, input.length + pad, pad);
    final cipher = ECBBlockCipher(AESEngine())..init(true, KeyParameter(keyBytes));
    final out = Uint8List(padded.length);
    for (var i = 0; i < padded.length; i += 16) {
      cipher.processBlock(padded, i, out, i);
    }
    return base64Encode(out);
  }

  static String hmacSha1B64(List<int> data, String secret) {
    final hmac = HMac(SHA1Digest(), 64)..init(KeyParameter(Uint8List.fromList(utf8.encode(secret))));
    return base64Encode(hmac.process(Uint8List.fromList(data)));
  }

  static String sha1B64(List<int> data) => base64Encode(sha1.convert(data).bytes);

  /// 从登录 token 中取账号 uid（payload.id）。
  static String tokenUid(String? token) {
    if (token == null || token.isEmpty) return '';
    final parts = token.split('.');
    if (parts.length < 2) return '';
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final map = jsonDecode(utf8.decode(base64Decode(payload)));
      if (map is Map && map['id'] != null) return '${map['id']}';
    } catch (_) {}
    return '';
  }

  /// 生成 32 位 hex 随机串（requestId）。
  static String randomHex(int bytes) {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
