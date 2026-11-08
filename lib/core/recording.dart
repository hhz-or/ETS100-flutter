import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 麦克风录音：16k / 单声道 / PCM16LE。
class EtsRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _sub;
  bool _recording = false;
  DateTime? _startedAt;

  bool get recording => _recording;
  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Future<void> start() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw Exception('没有麦克风权限（请在 Windows 设置中允许）');
    }
    _buffer.clear();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ));
    _sub = stream.listen(_buffer.add);
    _recording = true;
    _startedAt = DateTime.now();
  }

  /// 停止并返回 16k PCM16LE 字节。
  Future<Uint8List> stop() async {
    if (!_recording) return Uint8List(0);
    _recording = false;
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _startedAt = null;
    return _buffer.toBytes();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _recorder.dispose();
  }
}
