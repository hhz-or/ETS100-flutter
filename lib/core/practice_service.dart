import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api.dart';
import 'crypto.dart';
import 'ise.dart';

class UploadResult {
  UploadResult(this.mp3, this.spx, this.xml);
  final String mp3;
  final String spx;
  final String xml;
}

class SyncResult {
  SyncResult(this.point, this.complete, this.submitTime, this.raw);
  final double point;
  final double complete;
  final String submitTime;
  final Map<String, dynamic> raw;
}

/// 练习写链路：mp3 生成 → OSS 三文件上传 → sync-v2 回传。
class PracticeService {
  PracticeService(this.api);
  final EtsApi api;

  /// 调用 ffmpeg 把 16k mono PCM 转 24kbps mp3。
  Future<Uint8List> encodeMp3(Uint8List pcm, String ffmpegPath) async {
    final temp = await Directory.systemTemp.createTemp('ets_flutter_');
    final inFile = File('${temp.path}/in.pcm');
    final outFile = File('${temp.path}/out.mp3');
    try {
      await inFile.writeAsBytes(pcm, flush: true);
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        's16le',
        '-ar',
        '16000',
        '-ac',
        '1',
        '-i',
        inFile.path,
        '-codec:a',
        'libmp3lame',
        '-b:a',
        '24k',
        outFile.path,
      ]).timeout(const Duration(seconds: 120));
      if (result.exitCode != 0 || !await outFile.exists()) {
        throw Exception('ffmpeg 生成 mp3 失败（exit=${result.exitCode}）。'
            '请在设置中选择 ffmpeg.exe，或把 ffmpeg 加入 PATH。');
      }
      return await outFile.readAsBytes();
    } finally {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> fetchSts() async {
    final body = await api.ossSts();
    final upload = body['upload'];
    if (upload is! Map || upload['accessKeyId'] == null || upload['securityToken'] == null) {
      throw Exception('OSS STS 返回异常');
    }
    return body;
  }

  Future<UploadResult> uploadArtifacts({
    required Uint8List pcm,
    required List<int> spx,
    required String xml,
    required String ffmpegPath,
    Map<String, dynamic>? sts,
  }) async {
    final finalSts = sts ?? await fetchSts();
    final base = 'public_${EtsCrypto.randomHex(16)}_${DateTime.now().millisecondsSinceEpoch}';
    final mp3 = await encodeMp3(pcm, ffmpegPath);
    final mp3Url = await _upload(mp3, '$base.mp3', 'mp3', finalSts);
    final spxUrl = await _upload(Uint8List.fromList(spx), '$base.mp3.spx', 'speex', finalSts);
    final xmlUrl = await _upload(Uint8List.fromList(utf8.encode(xml)), '$base.xml', 'xml', finalSts);
    return UploadResult(mp3Url, spxUrl, xmlUrl);
  }

  String _pathFor(Map<String, dynamic> sts, String kind) {
    final key = kind == 'mp3'
        ? 'mp3Path'
        : kind == 'speex'
            ? 'spxPath'
            : 'xmlPath';
    return '${sts[key] ?? ''}';
  }

  Future<String> _upload(Uint8List bytes, String fileName, String kind, Map<String, dynamic> sts) async {
    final upload = sts['upload'] as Map? ?? sts;
    final bucket = '${upload['bucket'] ?? 'ets60'}';
    final endpoint = '${upload['endpoint'] ?? 'oss-cn-hangzhou.aliyuncs.com'}';
    final cname = '${upload['cname'] ?? 'https://$bucket.$endpoint'}'.replaceFirst(RegExp(r'/+$'), '');
    final prefix = _pathFor(sts, kind);
    if (prefix.isEmpty) throw Exception('STS 缺少 $kind 上传目录');
    final key = '$prefix$fileName';
    final expiration = '${upload['expiration'] ?? DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String()}';
    final policyDoc = {
      'expiration': expiration,
      'conditions': [
        ['content-length-range', 0, 524288000],
        ['eq', '\$bucket', bucket],
        ['eq', '\$key', key],
      ]
    };
    final policy = base64Encode(utf8.encode(jsonEncode(policyDoc)));
    final signature = EtsCrypto.hmacSha1B64(utf8.encode(policy), '${upload['accessKeySecret']}');
    final request = http.MultipartRequest('POST', Uri.parse('https://$bucket.$endpoint/'));
    request.fields.addAll({
      'OSSAccessKeyId': '${upload['accessKeyId']}',
      'policy': policy,
      'Signature': signature,
      'x-oss-security-token': '${upload['securityToken']}',
      'x-oss-object-acl': 'public-read',
      'key': key,
      'submit': 'Submit',
      'success_action_status': '200',
    });
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send().timeout(const Duration(seconds: 180));
    if (streamed.statusCode != 200 && streamed.statusCode != 201 && streamed.statusCode != 204) {
      final body = await streamed.stream.bytesToString();
      throw Exception('上传失败 HTTP ${streamed.statusCode}: ${body.substring(0, body.length > 200 ? 200 : body.length)}');
    }
    return '$cname/$key';
  }

  Map<String, Object?> buildSyncParams({
    required IseScores scores,
    required UploadResult urls,
    required String traceId,
    required String homeworkId,
    required String setId,
    required String entityId,
    required String resourceId,
    int order = 1,
    String firstColumnId = '1',
    String questionTypeScore = '0.5',
    String graduation = '0.125',
    String category = 'read_sentence',
  }) {
    final qts = double.tryParse(questionTypeScore) ?? 0.5;
    final total = scores.total;
    final real = double.parse((total * qts).toStringAsFixed(2));
    final detail = {
      'accuracy_score': scores.accuracy,
      'fluency_score': scores.fluency,
      'integrity_score': scores.integrity,
      'standard_score': scores.standard,
      'total_score': total,
      'real_score': real,
      'category': category,
      'rate_scale': 1,
    };
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return {
      'resource_id': resourceId,
      'real_score': real,
      'score': real,
      'set_id': setId,
      'entity_id': entityId,
      'order': '$order',
      'mistake_id': '',
      'upload_file_id': '',
      'upload_file_url': urls.mp3,
      'spx_file_url': urls.spx,
      'mark_trace_id': traceId,
      'detail_file_id': '',
      'detail_file_url': urls.xml,
      'score_detail': jsonEncode(detail),
      'exam_id': null,
      'homework_id': homeworkId,
      'first_column_id': firstColumnId,
      'question_type_score': questionTypeScore,
      'rate_scale': 1,
      'graduation': graduation,
      'client_time': '${now.year}-${two(now.month)}-${two(now.day)} '
          '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
      'mark_service': 1,
      'version': '2',
    };
  }

  Future<SyncResult> sync(Map<String, Object?> params) async {
    final body = await api.syncAudio(params);
    final map = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    return SyncResult(
      double.tryParse('${map['point'] ?? 0}') ?? 0,
      double.tryParse('${map['complete'] ?? 0}') ?? 0,
      '${map['submit_time'] ?? ''}',
      map,
    );
  }

  Future<void> finishHomework({required String homeworkId, required String setId, required String resourceId, required int useTimeSeconds}) async {
    try {
      await api.mistakeUpdate({
        'homework_id': homeworkId,
        'set_id': setId,
        'exam_id': '',
        'mistake_id': '',
        'combination_id': '',
        'composition_id': '',
        'type': '1',
        'resource_id': resourceId,
        'sync': '0',
      });
    } catch (_) {}
    try {
      await api.setUseTime({
        'version': 2,
        'correct': 0,
        'use_time': useTimeSeconds,
        'resource_id': resourceId,
        'homework_id': int.tryParse(homeworkId) ?? 0,
      });
    } catch (_) {}
  }
}
