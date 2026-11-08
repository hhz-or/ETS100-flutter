import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'constants.dart';

/// 全局状态：登录态、账号/学习卡、主题与本地设置。
class AppStore extends ChangeNotifier {
  AppStore();

  final EtsApi api = EtsApi();
  SharedPreferences? _prefs;

  bool initialized = false;
  bool loading = false;
  String? lastError;

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> ecards = [];
  String activeEcardId = '';
  Map<String, dynamic>? systemConfig;
  List<dynamic> announcements = const [];

  ThemeMode themeMode = ThemeMode.light;
  Color seedColor = const Color(0xFF5852D6);
  bool expressive = true;

  String ffmpegPath = 'ffmpeg';
  String deviceName = 'PC';
  String deviceCode = '0000000000000000';
  String localIp = '127.0.0.1';

  static const _kToken = 'ets_token';
  static const _kEcard = 'ets_ecard_id';
  static const _kProfile = 'ets_profile';
  static const _kThemeMode = 'ets_theme_mode';
  static const _kSeed = 'ets_seed_color';
  static const _kExpressive = 'ets_expressive';
  static const _kFfmpeg = 'ets_ffmpeg';
  static const _kDeviceName = 'ets_device_name';
  static const _kDeviceCode = 'ets_device_code';
  static const _kLocalIp = 'ets_local_ip';

  bool get isLoggedIn => (api.token ?? '').isNotEmpty;
  Map<String, dynamic>? get activeEcard {
    for (final e in ecards) {
      if ('${e['id']}' == activeEcardId) return e;
    }
    return ecards.isEmpty ? null : ecards.first;
  }

  String get parentAccountId => '${activeEcard?['parent_id'] ?? ''}';
  String get resourceId {
    final r = activeEcard?['resource_id'];
    return r == null ? '${EtsConstants.defaultResourceId}' : '$r';
  }

  /// 截图/演示模式：只改 UI 展示，不改网络请求。
  static bool get demoMode => Platform.environment['ETS_DEMO'] == '1';
  String get displayName => demoMode ? '演示同学' : '${profile?['name'] ?? profile?['phone'] ?? '同学'}';
  String get gradeName => '${profile?['grade_name'] ?? activeEcard?['class_grade'] ?? ''}';
  String get schoolName => demoMode ? '示例中学' : '${activeEcard?['school_name'] ?? activeEcard?['parent_name'] ?? ''}';
  String get uid => '${profile?['id'] ?? EtsCryptoUid.uidOf(api.token)}';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    themeMode = switch (p.getString(_kThemeMode)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    final seed = p.getInt(_kSeed);
    if (seed != null) seedColor = Color(seed);
    expressive = p.getBool(_kExpressive) ?? true;
    ffmpegPath = p.getString(_kFfmpeg) ?? 'ffmpeg';
    deviceName = p.getString(_kDeviceName) ?? 'PC';
    deviceCode = p.getString(_kDeviceCode) ?? '0000000000000000';
    localIp = p.getString(_kLocalIp) ?? '127.0.0.1';
    api.deviceName = deviceName;
    api.deviceCode = deviceCode;
    api.localIp = localIp;

    // 开发/自动化：ETS_TOKEN 环境变量可直接注入已有 token（不写入仓库）
    final envToken = Platform.environment['ETS_TOKEN'];
    final token = (envToken != null && envToken.isNotEmpty) ? envToken : p.getString(_kToken);
    if (envToken != null && envToken.isNotEmpty) {
      api.token = envToken;
    }
    final savedProfile = p.getString(_kProfile);
    final savedEcard = p.getString(_kEcard) ?? '';
    if (savedProfile != null) {
      try {
        profile = (jsonDecode(savedProfile) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    activeEcardId = savedEcard;
    if (token != null && token.isNotEmpty) {
      api.token = token;
      try {
        await bootstrap();
      } catch (e) {
        if (e is ApiException && e.isAuthError) {
          api.token = null;
          await p.remove(_kToken);
        } else {
          lastError = '$e';
        }
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      api.token = null;
      final body = await api.login(phone, password);
      await _prefs?.setString(_kToken, api.token!);
      if (body['recent_account_id'] != null) {
        profile = {
          ...(profile ?? {}),
          'name': body['name'],
          'phone': body['phone'],
          'recent_account_id': body['recent_account_id'],
        };
        await _persistProfile();
      }
      await bootstrap();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> useToken(String token) async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      api.token = token.trim();
      await api.userInfo();
      await _prefs?.setString(_kToken, api.token!);
      await bootstrap();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    final results = await Future.wait([
      api.userInfo().then<Object?>((v) => v).catchError((_) => null),
      api.ecardList().then<Object?>((v) => v).catchError((_) => null),
      api.systemConfig().catchError((_) => null),
      api.announcements().catchError((_) => null),
    ]);
    final user = results[0];
    final cards = results[1];
    if (user is Map) {
      profile = {...(profile ?? {}), ...user.cast<String, dynamic>()};
      await _persistProfile();
    }
    if (cards is List) {
      ecards = cards.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      final valid = ecards.any((e) => '${e['id']}' == activeEcardId);
      if (!valid) {
        final sameGrade = ecards.where((e) => '${e['grade_id']}' == '${profile?['grade_id']}').toList();
        activeEcardId = '${(sameGrade.isNotEmpty ? sameGrade.first : (ecards.isNotEmpty ? ecards.first : const <String, dynamic>{}))['id'] ?? ''}';
        await _prefs?.setString(_kEcard, activeEcardId);
      }
    }
    if (results[2] is Map) systemConfig = (results[2] as Map).cast<String, dynamic>();
    if (results[3] is List) announcements = results[3] as List;
    notifyListeners();
  }

  Future<void> _persistProfile() async {
    try {
      await _prefs?.setString(_kProfile, jsonEncode(profile ?? {}));
    } catch (_) {}
  }

  Future<void> selectEcard(String id) async {
    activeEcardId = id;
    await _prefs?.setString(_kEcard, id);
    notifyListeners();
  }

  Future<void> setTheme({ThemeMode? mode, Color? seed, bool? expressiveMode}) async {
    if (mode != null) {
      themeMode = mode;
      await _prefs?.setString(_kThemeMode, switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        _ => 'light',
      });
    }
    if (seed != null) {
      seedColor = seed;
      await _prefs?.setInt(_kSeed, seed.toARGB32());
    }
    if (expressiveMode != null) {
      expressive = expressiveMode;
      await _prefs?.setBool(_kExpressive, expressiveMode);
    }
    notifyListeners();
  }

  Future<void> setDevice({String? name, String? code, String? ip}) async {
    if (name != null) {
      deviceName = name;
      api.deviceName = name;
      await _prefs?.setString(_kDeviceName, name);
    }
    if (code != null) {
      deviceCode = code;
      api.deviceCode = code;
      await _prefs?.setString(_kDeviceCode, code);
    }
    if (ip != null) {
      localIp = ip;
      api.localIp = ip;
      await _prefs?.setString(_kLocalIp, ip);
    }
    notifyListeners();
  }

  Future<void> setFfmpeg(String path) async {
    ffmpegPath = path;
    await _prefs?.setString(_kFfmpeg, path);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    profile = null;
    ecards = [];
    activeEcardId = '';
    await _prefs?.remove(_kToken);
    await _prefs?.remove(_kProfile);
    await _prefs?.remove(_kEcard);
    notifyListeners();
  }
}

class EtsCryptoUid {
  static String uidOf(String? token) {
    if (token == null || token.isEmpty) return '';
    try {
      final parts = token.split('.');
      if (parts.length < 2) return '';
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final map = jsonDecode(utf8.decode(base64Decode(payload)));
      return map is Map && map['id'] != null ? '${map['id']}' : '';
    } catch (_) {
      return '';
    }
  }
}
