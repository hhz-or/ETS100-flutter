import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:m3e_core/m3e_core.dart' as m3ecore;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../glass.dart';
import '../palette_picker.dart';
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

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '设置', subtitle: '壁纸颜色、Liquid Glass、设备指纹与录音工具'),
          const SizedBox(height: 20),
          Panel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.palette_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('壁纸颜色', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('实时应用',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 6),
                Text('Android / Material You 基础颜色：选择一套配色，立即应用到全部界面。',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                PalettePickerPanel(
                  seed: store.seedColor,
                  selectedName: store.paletteName,
                  variant: store.schemeVariantName,
                  onPreset: (preset) async {
                    await store.setPalettePreset(
                      name: preset.name,
                      seed: preset.seed,
                      variant: store.schemeVariantName,
                    );
                  },
                  onVariant: (variant) async {
                    await store.setSchemeVariant(variant);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 1000;
            final left = Column(children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      Text('外观与动效', style: Theme.of(context).textTheme.titleLarge),
                    ]),
                    const SizedBox(height: 18),
                    Text('主题模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('浅色')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('深色')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('系统')),
                      ],
                      selected: {store.themeMode},
                      onSelectionChanged: (v) => store.setTheme(mode: v.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.blur_on_rounded, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Liquid Glass 全局开关',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('仅对侧栏 / 底部导航等 chrome 生效，内容保持 MD3 实色',
                                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                          ]),
                        ),
                        M3ESwitch(
                          value: store.glassEnabled,
                          onChanged: (v) async {
                            await store.setGlass(v);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(v ? 'Liquid Glass 已开启' : '已切换为实色 M3E 表面'),
                              ));
                            }
                          },
                        ),
                      ]),
                    ),
                    if (!EtsGlass.available)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text('当前平台/驱动不支持 fragment shader，玻璃模式会退化为半透明表面。',
                            style: TextStyle(fontSize: 11, color: scheme.error)),
                      ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.opacity_rounded, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('玻璃强度', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text('${(store.glassStrength * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ]),
                    m3ecore.M3ESlider(
                      value: store.glassStrength,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(store.glassStrength * 100).round()}%',
                      icon: const Icon(Icons.blur_on_rounded, size: 18),
                      onChanged: (v) {
                        EtsGlass.strength.value = v;
                        store.setGlassStrength(v);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text('玻璃只用于导航 chrome；内容卡片保持实色以保证可读性。',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (_isDesktop) ...[
                const SizedBox(height: 16),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text('录音上传工具', style: Theme.of(context).textTheme.titleLarge),
                      ]),
                      const SizedBox(height: 8),
                      Text('“上传并回传成绩”需要 ffmpeg 生成 mp3。可填完整路径或 PATH 中的命令名。',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.6)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: M3ETextField(
                            controller: _ffmpeg,
                            label: 'ffmpeg 路径',
                            supportingText: '例如 C:\\ffmpeg\\bin\\ffmpeg.exe',
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      const SizedBox(height: 14),
                      Row(children: [
                        M3EButton.tonal(
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
                        M3EButton.filled(
                          onPressed: () async {
                            await store.setFfmpeg(_ffmpeg.text.trim());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('已保存 ffmpeg 路径')));
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
              ],
            ]);
            final right = Column(children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.fingerprint_rounded, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      Text('设备指纹', style: Theme.of(context).textTheme.titleLarge),
                    ]),
                    const SizedBox(height: 8),
                    Text('复用官方客户端设备指纹可免二次验证；值只保存在本机。',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    M3ETextField(controller: _deviceName, label: 'device_name'),
                    const SizedBox(height: 12),
                    M3ETextField(controller: _deviceCode, label: 'device_code'),
                    const SizedBox(height: 12),
                    M3ETextField(controller: _localIp, label: 'local_ip'),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: M3EButton.tonal(
                        onPressed: () async {
                          await store.setDevice(
                            name: _deviceName.text.trim(),
                            code: _deviceCode.text.trim(),
                            ip: _localIp.text.trim(),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('设备信息已保存')));
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
                    Row(children: [
                      Icon(Icons.person_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('账号', style: Theme.of(context).textTheme.titleLarge),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primary,
                        child: Text(store.displayName.isEmpty ? '?' : store.displayName.characters.first,
                            style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(store.displayName, style: const TextStyle(fontWeight: FontWeight.w900)),
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
                      child: M3EButton.outlined(
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
                        child: const Text('退出登录'),
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
