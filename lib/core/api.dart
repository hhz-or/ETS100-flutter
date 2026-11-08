import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'crypto.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.route, this.status});
  final String message;
  final int? code;
  final String? route;
  final int? status;

  bool get isAuthError => code == 20004 || code == 30001;

  @override
  String toString() => message;
}

class EtsApi {
  EtsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  // 设备指纹（与官方客户端一致时可免二次验证）
  String deviceName = 'PC';
  String deviceCode = '0000000000000000';
  String localIp = '127.0.0.1';

  static const Map<String, Object> _commonBase = {
    'sign_response': 1,
    'sn': EtsConstants.sn,
    'system': EtsConstants.system,
    'global_client_version': EtsConstants.clientVersion,
  };

  Map<String, Object?> _common({bool withToken = true}) {
    final map = <String, Object?>{..._commonBase};
    if (withToken && token != null && token!.isNotEmpty) map['token'] = token;
    return map;
  }

  String normalizeRoute(String route) => route.replaceFirst(RegExp(r'^/+'), '');

  /// 请求信封：body=base64([{r,params}])，head.sign=MD5(pid+time+body+key)。
  Future<Map<String, dynamic>> _post(String url, Map<String, Object?> payload, int timeout) async {
    final body = jsonEncode(payload);
    final resp = await _client
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json;charset=UTF-8'}, body: body)
        .timeout(Duration(milliseconds: timeout));
    if (resp.statusCode != 200) {
      throw ApiException('HTTP ${resp.statusCode}', status: resp.statusCode, route: url);
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    return decoded is List ? (decoded.isNotEmpty ? (decoded.first as Map).cast<String, dynamic>() : {}) : (decoded as Map).cast<String, dynamic>();
  }

  /// 业务 RPC：返回 body；code != 0 抛 ApiException。
  Future<dynamic> call(String route, Map<String, Object?> params,
      {bool withToken = true, int timeoutMs = 30000}) async {
    final r = normalizeRoute(route);
    final fullParams = <String, Object?>{..._common(withToken: withToken), ...params};
    final bodyJson = jsonEncode([
      {'r': r, 'params': fullParams}
    ]);
    final bodyB64 = base64Encode(utf8.encode(bodyJson));
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final sign = EtsCrypto.md5Hex('${EtsConstants.pid}$time$bodyB64${EtsConstants.keyV2}');
    final payload = {
      'body': bodyB64,
      'head': {
        'version': '1.0',
        'sign': sign,
        'pid': EtsConstants.pid,
        'time': time,
        'time_second': int.parse(time),
      }
    };
    final item = await _post('${EtsConstants.apiBase}/$r', payload, timeoutMs);
    final code = int.tryParse('${item['code'] ?? 0}') ?? 0;
    if (code != 0) {
      final msg = '${item['msg'] ?? '接口错误（code=$code）'}';
      throw ApiException(msg, code: code, route: r);
    }
    return item['body'];
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final params = <String, Object?>{
      ..._common(withToken: false),
      'phone': EtsCrypto.aesEcbEncryptB64(phone, key: EtsConstants.kServes),
      'password': EtsCrypto.aesEcbEncryptB64(password, key: EtsConstants.kServes),
      'device_name': deviceName,
      'device_code': deviceCode,
      'local_ip': localIp,
      'version': 4,
    };
    final body = await call('user/login', params, withToken: false);
    if (body is Map && body['token'] is String) {
      token = body['token'] as String;
    } else if (body is Map && body['token'] == null) {
      throw ApiException('登录响应中没有 token', route: 'user/login');
    }
    return (body is Map) ? body.cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> userInfo() async =>
      ((await call('user/info', {})) as Map).cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> ecardList() async {
    final body = await call('m/ecard/list',
        {'school_level_filter': 0, 'version': '2', 'json_type': '1'});
    final raw = body is Map ? body['data'] : null;
    final list = <Map<String, dynamic>>[];
    void push(dynamic value) {
      if (value is Map) list.add(value.cast<String, dynamic>());
    }

    if (raw is List) {
      for (final e in raw) {
        push(e);
      }
    } else if (raw is Map) {
      for (final e in raw.values) {
        push(e);
      }
    }
    if (list.isEmpty && body is Map) {
      for (final e in body.values) {
        if (e is Map && (e['parent_id'] != null || e['number'] != null || e['id'] != null)) push(e);
      }
    }
    return list;
  }

  Future<dynamic> systemConfig({List<String>? keywords}) =>
      call('system/config', {'checkToken': false, if (keywords != null) 'keywork': keywords});
  Future<dynamic> systemTime() => call('system/time', {});
  Future<dynamic> announcements() => call('announcement/list', {'checkToken': false});
  Future<dynamic> advertisementList(String resourceId) =>
      call('m/advertisement/list', {'type': 1, 'resource_id': resourceId});

  Future<dynamic> homeworkList(String parentAccountId,
          {int status = 1, int offset = 0, int limit = 10}) =>
      call('g/homework/list', {
        'version': 11,
        'parent_account_id': parentAccountId,
        'offset': offset,
        'status': status,
        'get_all_count': 1,
        'limit': limit,
        'get_to_do_count': 1,
        'get_to_overtime_count': 1,
        'check_pass': 1,
        'show_old_homework': 1,
        'get_audio_task': 1,
        'use_https': 1,
        'use_homework_privilege': 1,
      });

  Future<List<Map<String, dynamic>>> homeworks(String parentAccountId,
      {List<int> statuses = const [0, 2, 3], int limit = 20}) async {
    final seen = <String>{};
    final items = <Map<String, dynamic>>[];
    Object? lastError;
    for (final status in statuses) {
      try {
        final body = await homeworkList(parentAccountId, status: status, limit: limit);
        final data = body is Map ? body['data'] : null;
        final baseUrl = body is Map ? '${body['base_url'] ?? ''}' : '';
        if (data is List) {
          for (final e in data) {
            if (e is Map) {
              final id = '${e['id'] ?? ''}';
              final item = e.cast<String, dynamic>();
              if (baseUrl.isNotEmpty) item['__base_url'] = baseUrl;
              if (id.isNotEmpty && seen.add(id)) items.add(item);
            }
          }
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (items.isEmpty && lastError != null) throw lastError;
    return items;
  }

  Future<Map<String, dynamic>> homeworkInfo(String homeworkId, String resourceId) async =>
      ((await call('m/homework/info',
              {'homework_id': homeworkId, 'resource_id': resourceId, 'version': 2}))
          as Map)
          .cast<String, dynamic>();

  Future<dynamic> checkStart(String homeworkId) =>
      call('g/homework/checkstart', {'homework_id': homeworkId});

  Future<List<Map<String, dynamic>>> columns(String resourceId) async {
    final body = await call('g/set/column-v2',
        {'resource_id': int.tryParse(resourceId) ?? 363, 'tag_id': 1, 'hide_set_count': 1});
    final data = body is Map ? body['data'] : null;
    return (data is List) ? data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : [];
  }

  /// 套卷列表（听说/听力在 data，读写模拟在 rw_data）。
  Future<List<Map<String, dynamic>>> sets(String resourceId, int columnId) async {
    final body = await call('g/set/list', {
      'resource_id': resourceId,
      'show_empty': 0,
      'use_https': 1,
      'first_column_id': [columnId],
    });
    final out = <Map<String, dynamic>>[];
    if (body is Map) {
      final baseUrl = '${body['base_url'] ?? ''}';
      for (final key in ['data', 'rw_data']) {
        final list = body[key];
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              final item = e.cast<String, dynamic>();
              if (baseUrl.isNotEmpty) item['__base_url'] = baseUrl;
              out.add(item);
            }
          }
        }
      }
    }
    return out;
  }

  Future<dynamic> gradeList(String parentResourceId) =>
      call('g/resource/grade-list', {'parent_resource_id': parentResourceId});
  Future<dynamic> bookList(String parentResourceId) =>
      call('g/resource/book-list', {'parent_resource_id': parentResourceId});
  Future<dynamic> unitList(String resourceId, String bookId) => call('g/set/unit-list',
      {'resource_id': int.tryParse(resourceId) ?? 239, 'book_id': int.tryParse(bookId) ?? 0, 'is_need_score': 0});
  Future<dynamic> unitInfo(String resourceId, String bookId, String unitId) => call('g/set/unit-info', {
        'resource_id': int.tryParse(resourceId) ?? 239,
        'book_id': int.tryParse(bookId) ?? 0,
        'unit_id': int.tryParse(unitId) ?? 0,
        'is_need_score': 1,
      });
  Future<dynamic> moduleList(String resourceId, String bookId, String unitId, {int version = 2}) =>
      call('g/set/module-list', {
        'resource_id': int.tryParse(resourceId) ?? 239,
        'book_id': int.tryParse(bookId) ?? 0,
        'unit_id': int.tryParse(unitId) ?? 0,
        'version': version,
        'support_credential_resource': 1,
      });

  Future<Map<String, dynamic>> mistakeSummary(String parentAccountId) async =>
      ((await call('m/mistake/summary', {'parent_account_id': parentAccountId})) as Map).cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> mistakeList(String parentAccountId,
      {int status = 0, int type = 1, int offset = 0, int limit = 100}) async {
    final body = await call('m/mistake/list', {
      'parent_account_id': parentAccountId,
      'status': status,
      'random': '0',
      'max_id': '0',
      'max_update_time': '',
      'type': type,
      'offset': offset,
      'limit': limit,
    });
    final list = body is Map ? body['mistake'] : null;
    final baseUrl = body is Map ? '${body['base_url'] ?? ''}' : '';
    final items = (list is List) ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];
    if (baseUrl.isNotEmpty) {
      for (final item in items) {
        item['__base_url'] = baseUrl;
      }
    }
    return items;
  }

  /// 练习评测相关：resource_id / ppr-res / mark-txt / mistake-check。
  Future<dynamic> pprRes(String entityId) => call('g/set/ppr-res', {
        'batch': [
          {'entity_id': entityId, 'order': '1'}
        ]
      });
  Future<dynamic> markTxt(String entityId) => call('/g/set/mark-txt', {
        'question': [
          {'key': '${entityId}_1'}
        ],
        'use_https': 1,
      });
  Future<dynamic> mistakeCheck(String parentAccountId, List<String> entityIds) => call('m/mistake/check', {
        'entity_id': entityIds,
        'composition_id': <String>[],
        'question_id': <String>[],
        'parent_account_id': parentAccountId,
      });

  Future<String> aiToken() async {
    final body = await call('ai/aiplat/getaitoken', {});
    final t = body is Map ? body['accessToken'] : null;
    if (t is! String || t.isEmpty) throw ApiException('getaitoken 返回异常', route: 'ai/aiplat/getaitoken');
    return t;
  }

  Future<Map<String, dynamic>> ossSts() async {
    final body = await call('p1/student/config/config/ossEvaluateUploadStsToken', {});
    return (body is Map) ? body.cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<dynamic> syncAudio(Map<String, Object?> params) => call('/m/audio/sync-v2', params, timeoutMs: 60000);

  Future<dynamic> mistakeUpdate(Map<String, Object?> params) => call('/m/mistake/update', params);

  Future<dynamic> setUseTime(Map<String, Object?> params) => call('m/homework/set-use-time', params);
}
