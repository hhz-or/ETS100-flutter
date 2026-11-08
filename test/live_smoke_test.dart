import 'dart:io';

import 'package:ets_flutter/core/api.dart';
import 'package:ets_flutter/core/ise.dart';
import 'package:ets_flutter/core/speex_ffi.dart';
import 'package:ets_flutter/core/zip_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// 真实账号/网络冒烟测试，默认跳过。
///
/// 需要先设置环境变量（切勿把真实值写入仓库）：
///   ETS_LIVE_TEST=1
///   ETS_TOKEN=<登录 token>
///   ETS_PCM=<16k mono PCM16LE 文件路径>          # speex 用例
///   ETS_SPX=<抓包得到 .spx 文件路径>              # ISE 用例
///   ETS_CONTENT_URL=<任意 content 包 zip URL>      # ZipCrypto 用例
///   ETS_ACCOUNT_ID / ETS_UID / ETS_CLASS_ID / ETS_SCHOOL_ID
///   ETS_GRADE_ID / ETS_STAGE_ID / ETS_REGION_ID / ETS_PAPER_ID
///
/// 然后运行：flutter test test/live_smoke_test.dart
void main() {
  final env = Platform.environment;
  final live = env['ETS_LIVE_TEST'] == '1';
  final token = env['ETS_TOKEN'] ?? '';
  String? fileIfExists(String key) {
    final path = env[key];
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
  }

  final pcmPath = fileIfExists('ETS_PCM');
  final spxPath = fileIfExists('ETS_SPX');
  final contentUrl = env['ETS_CONTENT_URL'];
  final sessionReady = [
    'ETS_ACCOUNT_ID',
    'ETS_UID',
    'ETS_CLASS_ID',
    'ETS_SCHOOL_ID',
    'ETS_GRADE_ID',
    'ETS_STAGE_ID',
    'ETS_REGION_ID',
    'ETS_PAPER_ID',
  ].every((k) => (env[k] ?? '').isNotEmpty);

  group('live smoke', () {
    test('speex encode produces 20ms frames', () async {
      final encoder = SpeexEncoder.fromPath('${Directory.current.path}/assets/native/ets_speex.dll');
      final spx = encoder.encode(await File(pcmPath!).readAsBytes());
      expect(spx.length, 42930);
    }, skip: !live || pcmPath == null);

    test('api + zipcrypto + ise end-to-end', () async {
      final api = EtsApi()..token = token;
      final user = await api.userInfo();
      expect(user['name'], isNotEmpty);
      final ecards = await api.ecardList();
      expect(ecards, isNotEmpty);
      final homeworks = await api.homeworks('${ecards.first['parent_id']}', limit: 20);
      expect(homeworks, isNotEmpty);

      // content 包：下载 + ZipCrypto 解密 + 安全解压
      final response = await http.get(Uri.parse(contentUrl!));
      final temp = await Directory.systemTemp.createTemp('ets_zip_test_');
      try {
        final files = await ZipPackage.extractZip(response.bodyBytes, temp);
        expect(files, contains('content.json'));
        expect(File('${temp.path}/content.json').readAsStringSync(), contains('structure_type'));
      } finally {
        await temp.delete(recursive: true);
      }

      // ISE：回放抓包 spx，验证会话元数据与结果解析
      final spx = await File(spxPath!).readAsBytes();
      final aiToken = await api.aiToken();
      final session = IseSession(
        accountId: env['ETS_ACCOUNT_ID']!,
        uid: env['ETS_UID']!,
        classId: env['ETS_CLASS_ID']!,
        schoolId: env['ETS_SCHOOL_ID']!,
        gradeId: env['ETS_GRADE_ID']!,
        stageId: env['ETS_STAGE_ID']!,
        regionId: env['ETS_REGION_ID']!,
        sceneType: env['ETS_SCENE_TYPE'] ?? 'homework',
        sceneId: env['ETS_SCENE_ID'] ?? env['ETS_ACCOUNT_ID']!,
        category: env['ETS_CATEGORY'] ?? 'read_sentence',
        paperId: env['ETS_PAPER_ID']!,
      );
      final result = await IseService.evaluate(spx: spx, session: session, token: aiToken);
      expect(result.ok, isTrue);
      expect(result.scores, isNotNull);
      expect(result.scores!.content, isNotEmpty);
    }, skip: !live || !sessionReady || contentUrl == null || spxPath == null,
        timeout: const Timeout(Duration(minutes: 2)));
  });
}
