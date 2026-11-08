import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '关于', subtitle: 'E听说 · Flutter Edition'),
          const SizedBox(height: 20),
          HeroCard(
            child: Row(children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text('E',
                      style: TextStyle(fontSize: 52, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('E听说 · Flutter', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text('Material 3 Expressive · Flutter ${_flutterVersion()} · Windows',
                      style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 12)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _pill(context, '真实账号登录'),
                    _pill(context, '录音 + ISE 评测'),
                    _pill(context, 'speex 16k 编码'),
                    _pill(context, 'OSS 上传 / sync 回传'),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            final left = Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('能力清单', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _row(context, Icons.login_rounded, '登录与会话', 'AES-128-ECB 字段加密 + 请求签名 + token 持久化'),
                _row(context, Icons.home_rounded, '首页', '作业统计、错题摘要、快捷入口、公告'),
                _row(context, Icons.assignment_rounded, '作业', '列表 / 详情 / 逐题练习 / 内容包解密'),
                _row(context, Icons.layers_rounded, '套卷', '听说、读写、听力三栏目，按当前学习卡资源库加载'),
                _row(context, Icons.menu_book_rounded, '同步课程', '教材 → 单元 → 模块浏览'),
                _row(context, Icons.auto_stories_rounded, '错题本', '待订正 / 已订正、题型筛选、订正练习'),
                _row(context, Icons.mic_rounded, '录音评测', '16k PCM → speex(106B/帧) → ISE protobuf WebSocket → 分数'),
                _row(context, Icons.cloud_upload_rounded, '成绩回传', 'ffmpeg 生成 mp3 → OSS 三文件 → sync-v2'),
              ]),
            );
            final right = Column(children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('协议研究来源', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    '本项目基于 ETS100-source 逆向资料（docs/03、docs/08、docs/15）实现：请求签名 '
                    'MD5(pid+time+body+key)、AES 字段加密、ISE protobuf、speex 编码参数、OSS 上传与 sync-v2。'
                    '全部协议常量来自公开逆向笔记，不含任何账号凭据。',
                    style: TextStyle(fontSize: 12, height: 1.75, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('免责声明', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    '非官方客户端，仅用于架构学习、互操作性研究与自有账号排障。不得用于绕过付费、考试评分、'
                    '伪造成绩或侵害他人权益的行为。凭据仅保存在本机，不上传、不写入源码。'
                    '登录会与官方客户端互顶（服务端单会话策略）。',
                    style: TextStyle(fontSize: 12, height: 1.75, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Text('当前账号：${store.displayName} · ${store.gradeName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]);
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: right),
                  ])
                : Column(children: [left, const SizedBox(height: 16), right]);
          }),
        ],
      ),
    );
  }

  static String _flutterVersion() {
    return '3.47';
  }

  Widget _pill(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: scheme.onPrimaryContainer.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}
