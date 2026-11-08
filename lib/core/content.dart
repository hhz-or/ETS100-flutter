import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'zip_crypto.dart';

class ContentStep {
  ContentStep(this.name, this.ok, [this.detail = '']);
  final String name;
  final bool ok;
  final String detail;
}

class ContentPackage {
  ContentPackage({required this.content, required this.dir, required this.steps, required this.zipPath, required this.cached});
  final Map<String, dynamic> content;
  final Directory dir;
  final List<ContentStep> steps;
  final String zipPath;
  final bool cached;

  String get kind {
    final type = '${content['structure_type'] ?? content['structureType'] ?? ''}';
    return type.replaceFirst('collector.', '');
  }

  Map<String, dynamic> get info {
    final raw = content['info'] ?? content['data'];
    return raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// content 包内相对路径 → 本地绝对路径；优先 material/ 目录。
  File? mediaFile(String? name) {
    if (name == null || name.isEmpty) return null;
    final raw = name.replaceAll('\\', '/');
    if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
    final candidates = [
      '${dir.path}/$raw',
      '${dir.path}/material/$raw',
      '${dir.path}/material/${raw.replaceFirst(RegExp(r'^material/'), '')}',
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) return f;
    }
    return null;
  }
}

class ContentService {
  ContentService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static Future<Directory> _baseDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/practice');
    await dir.create(recursive: true);
    return dir;
  }

  Future<ContentPackage> load({
    required String stid,
    String? zipUrl,
  }) async {
    final steps = <ContentStep>[];
    final safe = stid.replaceAll(RegExp(r'[^\w.-]'), '_');
    final base = await _baseDir();
    final dir = Directory('${base.path}/$safe');
    final zipPath = '${base.path}/$safe.zip';
    final contentFile = File('${dir.path}/content.json');

    if (await contentFile.exists()) {
      steps.add(ContentStep('命中本地缓存', true, dir.path));
      final content = _readContent(contentFile);
      return ContentPackage(content: content, dir: dir, steps: steps, zipPath: zipPath, cached: true);
    }
    if (zipUrl == null || zipUrl.isEmpty) {
      throw Exception('缺少 content 包下载地址');
    }
    steps.add(ContentStep('下载 content 包', true, zipUrl));
    final resp = await _client.get(Uri.parse(zipUrl)).timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) throw Exception('下载失败 HTTP ${resp.statusCode}');
    final bytes = Uint8List.fromList(resp.bodyBytes);
    await File(zipPath).writeAsBytes(bytes);
    final files = await ZipPackage.extractZip(bytes, dir);
    steps.add(ContentStep('解密并解压', true, '${files.length} 个文件'));
    final content = _readContent(contentFile);
    steps.add(ContentStep('读取 content.json', true, contentFile.path));
    return ContentPackage(content: content, dir: dir, steps: steps, zipPath: zipPath, cached: false);
  }

  Map<String, dynamic> _readContent(File file) {
    if (!file.existsSync()) throw Exception('content.json 不存在');
    final decoded = jsonDecode(utf8.decode(file.readAsBytesSync()));
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw Exception('content.json 格式错误');
  }

  static String resolveZipUrl(String? baseUrl, String? name) {
    if (name == null || name.isEmpty) return '';
    if (name.startsWith('http://') || name.startsWith('https://')) return name;
    final base = baseUrl ?? EtsConstants.contentBase;
    return '${base.replaceFirst(RegExp(r'/*$'), '')}/${name.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static String safeRichText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  }
}
