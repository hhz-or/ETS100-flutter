import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _deviceName;
  late final TextEditingController _deviceCode;
  late final TextEditingController _localIp;
  late final TextEditingController _ffmpeg;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _deviceName = TextEditingController(text: store.deviceName);
    _deviceCode = TextEditingController(text: store.deviceCode);
    _localIp = TextEditingController(text: store.localIp);
    _ffmpeg = TextEditingController(text: store.ffmpegPath);
  }

  @override
  void dispose() {
    _deviceName.dispose();
    _deviceCode.dispose();
    _localIp.dispose();
    _ffmpeg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '设置', subtitle: '外观、设备指纹、录音工具与账号'),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            final left = Column(children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('外观', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text('主题模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('浅色')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('深色')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('跟随系统')),
                      ],
                      selected: {store.themeMode},
                      onSelectionChanged: (v) => store.setTheme(mode: v.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 20),
                    Text('品牌色', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final color in const [
                          Color(0xFF5852D6),
                          Color(0xFFB3261E),
                          Color(0xFF00696D),
                          Color(0xFF7C4DFF),
                          Color(0xFFD97706),
                          Color(0xFF2E7D32),
                        ])
                          InkWell(
                            onTap: () => store.setTheme(seed: color),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: store.seedColor == color
                                    ? Border.all(color: scheme.onSurface, width: 3)
                                    : Border.all(color: scheme.outlineVariant, width: 1),
                              ),
                              child: store.seedColor == color
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('M3 Expressive 配色'),
                      subtitle: const Text('使用 DynamicSchemeVariant.expressive 生成高饱和方案'),
                      value: store.expressive,
                      onChanged: (v) => store.setTheme(expressiveMode: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('录音上传工具', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('“上传并回传成绩”需要 ffmpeg 生成 mp3。可填 ffmpeg 完整路径或 PATH 中的命令名。',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.6)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _ffmpeg,
                          decoration: const InputDecoration(labelText: 'ffmpeg 路径'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final file = await openFile(acceptedTypeGroups: const [
                            XTypeGroup(label: 'ffmpeg', extensions: ['exe'])
                          ]);
                          if (file != null) _ffmpeg.text = file.path;
                        },
                        icon: const Icon(Icons.folder_open_rounded),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      FilledButton.tonal(
                        onPressed: _testing
                            ? null
                            : () async {
                                setState(() {
                                  _testing = true;
                                  _testResult = null;
                                });
                                try {
                                  final result = await Process.run(_ffmpeg.text.trim(), ['-version']);
                                  setState(() => _testResult = result.exitCode == 0
                                      ? '可用：${result.stdout.toString().split('\n').first}'
                                      : '不可用（exit=${result.exitCode}）');
                                } catch (e) {
                                  setState(() => _testResult = '不可用：$e');
                                } finally {
                                  setState(() => _testing = false);
                                }
                              },
                        child: Text(_testing ? '检测中…' : '检测'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () async {
                          await store.setFfmpeg(_ffmpeg.text.trim());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存 ffmpeg 路径')));
                          }
                        },
                        child: const Text('保存'),
                      ),
                    ]),
                    if (_testResult != null) ...[
                      const SizedBox(height: 10),
                      Text(_testResult!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ]);
            final right = Column(children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('设备指纹', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('复用官方客户端设备指纹可免二次验证；值只保存在本机。',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    TextField(controller: _deviceName, decoration: const InputDecoration(labelText: 'device_name')),
                    const SizedBox(height: 10),
                    TextField(controller: _deviceCode, decoration: const InputDecoration(labelText: 'device_code')),
                    const SizedBox(height: 10),
                    TextField(controller: _localIp, decoration: const InputDecoration(labelText: 'local_ip')),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () async {
                          await store.setDevice(
                            name: _deviceName.text.trim(),
                            code: _deviceCode.text.trim(),
                            ip: _localIp.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设备信息已保存')));
                          }
                        },
                        child: const Text('保存设备信息'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('账号', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primary,
                        child: Text(store.displayName.isEmpty ? '?' : store.displayName.characters.first,
                            style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(store.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${store.gradeName} · ${store.schoolName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                        ]),
                      ),
                      Text('token ${store.api.token == null ? '无' : '已保存'}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('退出登录？'),
                              content: const Text('退出后需要重新输入手机号/密码或 token。'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出')),
                              ],
                            ),
                          );
                          if (ok == true) await store.logout();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ]);
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ])
                : Column(children: [left, const SizedBox(height: 16), right]);
          }),
        ],
      ),
    );
  }
}
