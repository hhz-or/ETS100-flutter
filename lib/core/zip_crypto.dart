import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'crypto.dart';

/// 资源包（ZipCrypto）解密与安全解压。
/// 包尾 336 字节口令块：company=MSTCHINA / product=EPLAT → 两级 MD5 口令。
class ZipPackage {
  static int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
  static int _u32(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
  static void _w16(Uint8List b, int o, int v) {
    b[o] = v & 0xff;
    b[o + 1] = (v >> 8) & 0xff;
  }

  static String _clean(Uint8List bytes) =>
      String.fromCharCodes(bytes.where((c) => c != 0)).trim();

  /// 从包尾派生 ZipCrypto 口令；不是加密包返回 null。
  static String? password(Uint8List package) {
    if (package.length >= 336) {
      final tail = package.sublist(package.length - 336);
      final company = _clean(tail.sublist(0, 8));
      final product = _clean(tail.sublist(144, 176));
      if (company == 'MSTCHINA' && product == 'EPLAT') {
        final first = EtsCrypto.md5Hex(_clean(tail.sublist(16, 144))).toUpperCase();
        return first + EtsCrypto.md5Hex(first).toUpperCase();
      }
    }
    if (package.length >= 40) {
      final text = _clean(package.sublist(package.length - 40));
      if (text.length > 8) {
        final first = EtsCrypto.md5Hex(text.substring(8)).toUpperCase();
        return first + EtsCrypto.md5Hex(first).toUpperCase();
      }
    }
    return null;
  }

  // ----- ZipCrypto keys -----
  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    return c;
  });

  static void _updateKeys(List<int> keys, int c) {
    keys[0] = _crcTable[(keys[0] ^ c) & 0xff] ^ (keys[0] >> 8);
    keys[1] = ((keys[1] + (keys[0] & 0xff)) * 134775813 + 1) & 0xffffffff;
    keys[2] = _crcTable[(keys[2] ^ (keys[1] >> 24)) & 0xff] ^ (keys[2] >> 8);
  }

  static int _decryptByte(List<int> keys) {
    final t = (keys[2] | 2) & 0xffff;
    return ((t * (t ^ 1)) >> 8) & 0xff;
  }

  static void _decryptRange(Uint8List data, int start, int length, List<int> keys) {
    for (var i = 0; i < length; i++) {
      final c = data[start + i];
      final p = c ^ _decryptByte(keys);
      data[start + i] = p;
      _updateKeys(keys, p);
    }
  }

  /// 原地解密包内的 ZipCrypto 条目，并清除加密标志位；返回是否加密。
  static bool decryptInPlace(Uint8List bytes, String password) {
    var eocd = -1;
    final minStart = bytes.length - 22 - 65535;
    for (var i = bytes.length - 22; i >= (minStart < 0 ? 0 : minStart); i--) {
      if (_u32(bytes, i) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) return false;
    final total = _u16(bytes, eocd + 10);
    var offset = _u32(bytes, eocd + 16);
    final keysBase = <int>[0x12345678, 0x23456789, 0x34567890];
    for (final b in password.codeUnits) {
      _updateKeys(keysBase, b & 0xff);
    }
    var encrypted = false;
    for (var n = 0; n < total; n++) {
      if (offset + 46 > bytes.length || _u32(bytes, offset) != 0x02014b50) break;
      final flags = _u16(bytes, offset + 8);
      final compSize = _u32(bytes, offset + 20);
      final nameLen = _u16(bytes, offset + 28);
      final extraLen = _u16(bytes, offset + 30);
      final commentLen = _u16(bytes, offset + 32);
      final localOff = _u32(bytes, offset + 42);
      if ((flags & 1) != 0 && localOff + 30 <= bytes.length) {
        final localNameLen = _u16(bytes, localOff + 26);
        final localExtraLen = _u16(bytes, localOff + 28);
        final dataStart = localOff + 30 + localNameLen + localExtraLen;
        final keys = List<int>.from(keysBase);
        _decryptRange(bytes, dataStart, 12, keys);
        if (compSize > 12 && dataStart + compSize <= bytes.length) {
          _decryptRange(bytes, dataStart + 12, compSize - 12, keys);
        }
        _w16(bytes, offset + 8, flags & ~1);
        _w16(bytes, localOff + 6, _u16(bytes, localOff + 6) & ~1);
        encrypted = true;
      }
      offset += 46 + nameLen + extraLen + commentLen;
    }
    return encrypted;
  }

  /// 解析中央目录（等价于 zipfile.infolist）。
  static List<_ZipEntry> _entries(Uint8List bytes) {
    var eocd = -1;
    final minStart = bytes.length - 22 - 65535;
    for (var i = bytes.length - 22; i >= (minStart < 0 ? 0 : minStart); i--) {
      if (_u32(bytes, i) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw Exception('不是合法 zip（找不到 EOCD）');
    final total = _u16(bytes, eocd + 10);
    var offset = _u32(bytes, eocd + 16);
    final out = <_ZipEntry>[];
    for (var n = 0; n < total; n++) {
      if (offset + 46 > bytes.length || _u32(bytes, offset) != 0x02014b50) {
        throw Exception('中央目录损坏');
      }
      final flags = _u16(bytes, offset + 8);
      final method = _u16(bytes, offset + 10);
      final crc = _u32(bytes, offset + 16);
      final csize = _u32(bytes, offset + 20);
      final usize = _u32(bytes, offset + 24);
      final nameLen = _u16(bytes, offset + 28);
      final extraLen = _u16(bytes, offset + 30);
      final commentLen = _u16(bytes, offset + 32);
      final localOff = _u32(bytes, offset + 42);
      final name = String.fromCharCodes(bytes.sublist(offset + 46, offset + 46 + nameLen));
      out.add(_ZipEntry(name, flags, method, crc, csize, usize, localOff));
      offset += 46 + nameLen + extraLen + commentLen;
    }
    return out;
  }

  static Uint8List _dataOf(Uint8List bytes, _ZipEntry e, String? password) {
    if (e.localOffset + 30 > bytes.length || _u32(bytes, e.localOffset) != 0x04034b50) {
      throw Exception('本地文件头损坏：${e.name}');
    }
    final nameLen = _u16(bytes, e.localOffset + 26);
    final extraLen = _u16(bytes, e.localOffset + 28);
    final start = e.localOffset + 30 + nameLen + extraLen;
    if (start + e.compressedSize > bytes.length) throw Exception('压缩数据越界：${e.name}');
    final raw = Uint8List.fromList(bytes.sublist(start, start + e.compressedSize));
    if ((e.flags & 1) != 0) {
      if (password == null) throw Exception('资源包已加密，但未能派生口令');
      final keys = <int>[0x12345678, 0x23456789, 0x34567890];
      for (final b in password.codeUnits) {
        _updateKeys(keys, b & 0xff);
      }
      // 先解密 12 字节加密头（最后一字节是校验值），再解密数据。
      _decryptRange(raw, 0, 12, keys);
      if (raw.length > 12) _decryptRange(raw, 12, raw.length - 12, keys);
      final plain = Uint8List.fromList(raw.sublist(12));
      if (e.method == 0) return plain;
      if (e.method == 8) return Inflate(plain).getBytes();
      throw Exception('不支持的压缩方法 ${e.method}：${e.name}');
    }
    if (e.method == 0) return raw;
    if (e.method == 8) return Inflate(raw).getBytes();
    throw Exception('不支持的压缩方法 ${e.method}：${e.name}');
  }

  /// 仅调试：返回指定条目的解密后压缩数据（未解压）。
  static Uint8List? debugDecryptedRaw(Uint8List package, String entryName) {
    final pwd = password(package);
    for (final e in _entries(package)) {
      if (e.name != entryName) continue;
      final nameLen = _u16(package, e.localOffset + 26);
      final extraLen = _u16(package, e.localOffset + 28);
      final start = e.localOffset + 30 + nameLen + extraLen;
      final raw = Uint8List.fromList(package.sublist(start, start + e.compressedSize));
      final keys = <int>[0x12345678, 0x23456789, 0x34567890];
      for (final b in (pwd ?? '').codeUnits) {
        _updateKeys(keys, b & 0xff);
      }
      _decryptRange(raw, 0, 12, keys);
      if (raw.length > 12) _decryptRange(raw, 12, raw.length - 12, keys);
      return raw;
    }
    return null;
  }

  /// 下载的 zip → 解密 → 安全解压到 [dest]；返回解压出的相对路径列表。
  static Future<List<String>> extractZip(Uint8List package, Directory dest) async {
    final pwd = password(package);
    final entries = _entries(package);
    await dest.create(recursive: true);
    final root = dest.absolute.path;
    String norm(String p) => p.replaceAll('\\', '/').toLowerCase();
    final rootNorm = norm(root);
    final files = <String>[];
    for (final e in entries) {
      if (e.name.endsWith('/')) continue;
      final name = e.name.replaceAll('\\', '/');
      final parts = name.split('/').where((p) => p.isNotEmpty && p != '.').toList();
      if (parts.any((p) => p == '..')) throw Exception('压缩包包含非法路径：$name');
      final data = _dataOf(package, e, pwd);
      final target = File('$root/${parts.join('/')}');
      final targetPath = norm(target.absolute.path);
      if (!targetPath.startsWith('$rootNorm/')) throw Exception('压缩包路径越界：$name');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(data, flush: true);
      files.add(parts.join('/'));
    }
    return files;
  }
}

class _ZipEntry {
  _ZipEntry(this.name, this.flags, this.method, this.crc, this.compressedSize, this.uncompressedSize, this.localOffset);
  final String name;
  final int flags;
  final int method;
  final int crc;
  final int compressedSize;
  final int uncompressedSize;
  final int localOffset;
}
