import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'constants.dart';

class IseResult {
  IseResult({required this.code, required this.msg, required this.traceId, required this.xml, this.scores});
  final String code;
  final String msg;
  final String traceId;
  final String xml;
  final IseScores? scores;

  bool get ok => code.startsWith('00000');
}

class IseWord {
  IseWord(this.content, this.score);
  final String content;
  final double score;
}

class IseScores {
  IseScores({
    required this.accuracy,
    required this.fluency,
    required this.integrity,
    required this.standard,
    required this.total,
    required this.isRejected,
    required this.exceptInfo,
    required this.content,
    required this.words,
  });
  final double accuracy;
  final double fluency;
  final double integrity;
  final double standard;
  final double total;
  final bool isRejected;
  final String exceptInfo;
  final String content;
  final List<IseWord> words;
}

class IseSession {
  IseSession({
    required this.accountId,
    required this.uid,
    required this.classId,
    required this.schoolId,
    required this.gradeId,
    required this.stageId,
    required this.regionId,
    required this.sceneType,
    required this.sceneId,
    required this.category,
    required this.paperId,
    String? requestId,
  }) : requestId = requestId ?? _randomHex(16);

  final String accountId;
  final String uid;
  final String classId;
  final String schoolId;
  final String gradeId;
  final String stageId;
  final String regionId;
  final String sceneType;
  final String sceneId;
  final String category;
  final String paperId;
  final String requestId;

  static String _randomHex(int bytes) {
    final rnd = Random.secure();
    final sb = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      sb.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

/// ISE（口语评测）WebSocket 客户端：protobuf 二进制协议。
class IseService {
  static const int chunkBytes = 212;

  static Uint8List _varint(int value) {
    final out = <int>[];
    var v = value;
    while (v > 0x7f) {
      out.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.add(v);
    return Uint8List.fromList(out);
  }

  static Uint8List _tag(int field, int wire) => _varint((field << 3) | wire);

  static Uint8List _bytesField(int field, List<int> data) {
    final b = Uint8List.fromList(data);
    return Uint8List.fromList([..._tag(field, 2), ..._varint(b.length), ...b]);
  }

  static Uint8List _stringField(int field, String value) => _bytesField(field, utf8.encode(value));
  static Uint8List _varintField(int field, int value) => Uint8List.fromList([..._tag(field, 0), ..._varint(value)]);
  static Uint8List _concat(List<List<int>> parts) {
    final out = BytesBuilder();
    for (final p in parts) {
      out.add(p);
    }
    return out.toBytes();
  }

  static Uint8List buildInit(IseSession session, String token, List<int> firstChunk) {
    final meta = <String, String>{
      'uid': session.uid,
      'regionId': session.regionId,
      'schoolId': session.schoolId,
      'classId': session.classId,
      'gradeId': session.gradeId,
      'stageId': session.stageId,
      'tpl_region': 'shanghai',
      'scene_type': session.sceneType,
      'scene_id': session.sceneId,
      'module': '1',
      'plat_type': 'Web',
      'plat_ver': '5.7.9',
    };
    final info = _concat([
      _stringField(1, 'ksyyyxx-etszx'),
      _stringField(2, session.accountId),
      _stringField(3, '00-00-00-00-00-00'),
      _stringField(4, 'ets_70'),
      _stringField(5, 'SDK_pY1wOPU8'),
      _stringField(6, session.requestId),
      _stringField(7, token),
      _bytesField(8, const []),
      for (final e in meta.entries) _bytesField(9, _concat([_stringField(1, e.key), _stringField(2, e.value)])),
    ]);
    final params = <String, String>{
      'category': session.category,
      'paperId': session.paperId,
      'region': 'shanghai',
      'group': '',
      'parsePaper': 'false',
      'audioStorage': 'true',
      'resultStorage': 'true',
    };
    return _concat([
      _bytesField(1, info),
      _stringField(2, 'en'),
      _bytesField(3, const []),
      _varintField(4, 1),
      _bytesField(5, firstChunk),
      _varintField(6, 16000),
      _stringField(7, 'speex'),
      _varintField(8, 0),
      _varintField(9, 0),
      _varintField(10, 0),
      for (final e in params.entries) _bytesField(11, _concat([_stringField(1, e.key), _stringField(2, e.value)])),
      _bytesField(12, const []),
      _varintField(13, 3),
    ]);
  }

  static Uint8List audioFrame(List<int> chunk) =>
      _concat([_bytesField(5, chunk), _stringField(7, 'speex'), _varintField(8, 0)]);

  static Uint8List endFrame() => _concat([
        _bytesField(5, List<int>.filled(10, 0)),
        _stringField(7, 'speex'),
        _varintField(8, 1),
      ]);

  static Map<String, dynamic> _parseFields(List<int> data) {
    final out = <String, dynamic>{};
    var i = 0;
    int readVarint() {
      var shift = 0, val = 0;
      while (true) {
        final b = data[i++];
        val |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) return val;
        shift += 7;
      }
    }

    while (i < data.length) {
      final key = readVarint();
      final field = key >> 3, wire = key & 7;
      if (wire == 0) {
        out['$field'] = readVarint();
      } else if (wire == 2) {
        final len = readVarint();
        out['$field'] = data.sublist(i, i + len);
        i += len;
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        break;
      }
    }
    return out;
  }

  static IseResult parseResult(Uint8List data) {
    final fields = _parseFields(data);
    String text(String key) {
      final v = fields[key];
      return v is List<int> ? utf8.decode(v, allowMalformed: true) : '';
    }

    var xml = '';
    final f4 = fields['4'];
    if (f4 is List<int>) {
      final inner = _parseFields(f4);
      final head = inner['1'];
      if (head is List<int> && utf8.decode(head) == 'result') {
        final body = inner['2'];
        if (body is List<int>) xml = utf8.decode(body, allowMalformed: true);
      }
    }
    if (xml.isEmpty) {
      final s = utf8.decode(data, allowMalformed: true);
      final m = RegExp(r'<xml_result[\s\S]*</xml_result>').firstMatch(s);
      xml = m?.group(0) ?? '';
    }
    return IseResult(
      code: text('1'),
      msg: text('2'),
      traceId: text('3'),
      xml: xml,
      scores: parseScores(xml),
    );
  }

  static IseScores? parseScores(String xml) {
    if (xml.isEmpty) return null;
    try {
      final doc = XmlDocument.parse(xml);
      final chapter = doc.findAllElements('read_chapter').isNotEmpty
          ? doc.findAllElements('read_chapter').first
          : doc.descendants.whereType<XmlElement>().firstWhere(
                (e) => e.getAttribute('accuracy_score') != null,
                orElse: () => doc.rootElement,
              );
      double d(String name) => double.tryParse(chapter.getAttribute(name) ?? '') ?? 0;
      final words = <IseWord>[];
      for (final w in doc.findAllElements('word')) {
        final c = w.getAttribute('content');
        if (c == null) continue;
        words.add(IseWord(c, double.tryParse(w.getAttribute('total_score') ?? '') ?? 0));
      }
      return IseScores(
        accuracy: d('accuracy_score'),
        fluency: d('fluency_score'),
        integrity: d('integrity_score'),
        standard: d('standard_score'),
        total: d('total_score'),
        isRejected: chapter.getAttribute('is_rejected') == 'true',
        exceptInfo: chapter.getAttribute('except_info') ?? '',
        content: chapter.getAttribute('content') ?? '',
        words: words,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<IseResult> evaluate({
    required List<int> spx,
    required IseSession session,
    required String token,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (spx.length < chunkBytes) throw StateError('音频数据不足');
    final chunks = <Uint8List>[];
    for (var off = 0; off < spx.length; off += chunkBytes) {
      chunks.add(Uint8List.fromList(spx.sublist(off, off + chunkBytes > spx.length ? spx.length : off + chunkBytes)));
    }
    final ws = await WebSocket.connect(
      EtsConstants.iseUrl,
      headers: {
        'Origin': 'https://statics.ets100.com',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/91 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 20));
    final completer = Completer<IseResult>();
    late StreamSubscription sub;
    Timer? timer;
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('ISE 评测超时'));
      }
      ws.close();
    });
    sub = ws.listen((event) {
      if (event is List<int>) {
        final result = parseResult(Uint8List.fromList(event));
        if (!completer.isCompleted) completer.complete(result);
        sub.cancel();
        timer?.cancel();
        ws.close();
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
      timer?.cancel();
    }, onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('ISE 连接已关闭'));
      }
      timer?.cancel();
    });
    ws.add(buildInit(session, token, chunks.first));
    for (var i = 1; i < chunks.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 6));
      ws.add(audioFrame(chunks[i]));
    }
    ws.add(endFrame());
    return completer.future;
  }
}
