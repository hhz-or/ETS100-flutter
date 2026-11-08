import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

typedef _SizeNative = Int32 Function(Int32 samples);
typedef _SizeDart = int Function(int samples);
typedef _EncodeNative = Int32 Function(Pointer<Int16> pcm, Int32 samples, Pointer<Uint8> out,
    Int32 outCap, Pointer<Int32> outLen, Pointer<Int32> outFrames);
typedef _EncodeDart = int Function(Pointer<Int16> pcm, int samples, Pointer<Uint8> out,
    int outCap, Pointer<Int32> outLen, Pointer<Int32> outFrames);

/// 16k mono speex 编码（quality 10 / CBR 84800 → 106B/帧），与官方客户端一致。
class SpeexEncoder {
  SpeexEncoder._(this._lib)
      : _size = _lib.lookupFunction<_SizeNative, _SizeDart>('ets_speex_encode_size'),
        _encode = _lib.lookupFunction<_EncodeNative, _EncodeDart>('ets_speex_encode');

  // ignore: unused_field
  final DynamicLibrary _lib;
  final _SizeDart _size;
  final _EncodeDart _encode;

  static SpeexEncoder? _instance;

  /// 测试/自定义路径加载。
  factory SpeexEncoder.fromPath(String path) => SpeexEncoder._(DynamicLibrary.open(path));

  static Future<SpeexEncoder> instance() async {
    if (_instance != null) return _instance!;
    final lib = DynamicLibrary.open(await _dllPath());
    _instance = SpeexEncoder._(lib);
    return _instance!;
  }

  static Future<String> _dllPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final beside = File('${exeDir.path}/ets_speex.dll');
    if (await beside.exists()) return beside.path;
    final temp = await getTemporaryDirectory();
    final target = File('${temp.path}/ets_speex.dll');
    final data = await rootBundle.load('assets/native/ets_speex.dll');
    await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return target.path;
  }

  /// 输入 16k mono PCM16LE，输出 spx 裸流。
  Uint8List encode(Uint8List pcmBytes) {
    final samples = pcmBytes.length ~/ 2;
    if (samples < 320) throw StateError('录音太短');
    final cap = _size(samples);
    final pcmPtr = calloc<Int16>(samples);
    final outPtr = calloc<Uint8>(cap);
    final lenPtr = calloc<Int32>();
    final framesPtr = calloc<Int32>();
    try {
      final src = pcmBytes.buffer.asInt16List(pcmBytes.offsetInBytes, samples);
      pcmPtr.asTypedList(samples).setAll(0, src);
      final rc = _encode(pcmPtr, samples, outPtr, cap, lenPtr, framesPtr);
      if (rc != 0) throw StateError('speex 编码失败（code=$rc）');
      final len = lenPtr.value;
      return Uint8List.fromList(outPtr.asTypedList(len));
    } finally {
      calloc.free(pcmPtr);
      calloc.free(outPtr);
      calloc.free(lenPtr);
      calloc.free(framesPtr);
    }
  }
}
