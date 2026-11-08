import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'about_page.dart';
import 'courses_page.dart';
import 'home_page.dart';
import 'homework_detail_page.dart';
import 'homework_page.dart';
import 'mistakes_page.dart';
import 'practice_page.dart';
import 'sets_page.dart';
import 'settings_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});
  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 开发/自动化：ETS_START_PAGE=homework|sets|courses|mistakes|settings|about
    final start = Platform.environment['ETS_START_PAGE'] ?? '';
    const names = ['home', 'homework', 'sets', 'courses', 'mistakes', 'settings', 'about'];
    final i = names.indexOf(start);
    if (i >= 0) _index = i;

    // 开发/自动化：ETS_START_HOMEWORK=<id> 直接打开作业详情；
    // ETS_START_PRACTICE=1 再自动进入第一题练习页。
    final hw = Platform.environment['ETS_START_HOMEWORK'] ?? '';
    if (hw.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openHomework(hw));
    }
  }

  Future<void> _openHomework(String homeworkId) async {
    final store = context.read<AppStore>();
    try {
      final list = await store.api.homeworks(store.parentAccountId, limit: 50);
      Map<String, dynamic>? item;
      for (final h in list) {
        if ('${h['id']}' == homeworkId) {
          item = h;
          break;
        }
      }
      if (!mounted || item == null) return;
      final hwItem = item;
      final practiceMode = Platform.environment['ETS_START_PRACTICE'] == '1';
      if (practiceMode) {
        final struct = hwItem['struct'] is Map ? (hwItem['struct'] as Map) : const {};
        final contents = (struct['contents'] is List)
            ? (struct['contents'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[];
        if (contents.isEmpty) return;
        final first = contents.first;
        final base = '${hwItem['__base_url'] ?? struct['base_url'] ?? 'https://cdnsubject.ets100.com/made/'}';
        final name = '${first['url'] ?? ''}';
        final zip = name.startsWith('http')
            ? name
            : '${base.replaceFirst(RegExp(r'/*$'), '')}/${name.replaceFirst(RegExp(r'^/+'), '')}';
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PracticePage(
            stid: '${first['real_id'] ?? ''}',
            zipUrl: zip,
            title: '${first['group_name'] ?? '练习'}',
            homeworkId: homeworkId,
            setId: '${hwItem['set_id'] ?? struct['set_id'] ?? ''}',
            resourceId: store.resourceId,
            contents: contents,
          ),
        ));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeworkDetailPage(homeworkId: homeworkId, resourceId: store.resourceId, item: hwItem),
      ));
    } catch (e, st) {
      try {
        File('${Directory.systemTemp.path}/ets_flutter_open.log').writeAsStringSync(
            'open homework $homeworkId failed: $e\n$st\n',
            mode: FileMode.append,
            flush: true);
      } catch (_) {}
    }
  }

  static const _items = [
    _NavItem('首页', Icons.home_rounded),
    _NavItem('我的作业', Icons.assignment_rounded),
    _NavItem('套卷练习', Icons.layers_rounded),
    _NavItem('同步课程', Icons.menu_book_rounded),
    _NavItem('错题本', Icons.auto_stories_rounded),
    _NavItem('设置', Icons.tune_rounded),
    _NavItem('关于', Icons.info_rounded),
  ];

  Widget _page() => switch (_index) {
        0 => const HomePage(),
        1 => const HomeworkPage(),
        2 => const SetsPage(),
        3 => const CoursesPage(),
        4 => const MistakesPage(),
        5 => const SettingsPage(),
        _ => const AboutPage(),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.digit1, control: true): () => setState(() => _index = 0),
        SingleActivator(LogicalKeyboardKey.digit2, control: true): () => setState(() => _index = 1),
        SingleActivator(LogicalKeyboardKey.digit3, control: true): () => setState(() => _index = 2),
        SingleActivator(LogicalKeyboardKey.digit4, control: true): () => setState(() => _index = 3),
        SingleActivator(LogicalKeyboardKey.digit5, control: true): () => setState(() => _index = 4),
        SingleActivator(LogicalKeyboardKey.digit6, control: true): () => setState(() => _index = 5),
        SingleActivator(LogicalKeyboardKey.digit7, control: true): () => setState(() => _index = 6),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      body: EtsBackground(
        child: Row(
          children: [
            Container(
              width: 268,
              margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                          ),
                          child: const Center(
                            child: Text('E',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E听说', style: Theme.of(context).textTheme.titleLarge),
                            Text('FLUTTER · M3E',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ...List.generate(_items.length, (i) {
                    final selected = i == _index;
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _NavButton(
                        label: item.label,
                        icon: item.icon,
                        selected: selected,
                        onTap: () => setState(() => _index = i),
                      ),
                    );
                  }),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: scheme.primary,
                              child: Text(
                                store.displayName.isEmpty ? '?' : store.displayName.characters.first,
                                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(store.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text(store.gradeName,
                                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${store.schoolName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(width: 6),
                          const Text('已连接', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('v1.0', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.015, 0), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_index), child: _page()),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _NavButton extends StatefulWidget {
  const _NavButton({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.selected
        ? scheme.primaryContainer
        : _hover
            ? scheme.surfaceContainerHighest
            : Colors.transparent;
    final fg = widget.selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        color: fg, fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600, fontSize: 14)),
              ),
              if (widget.selected)
                Container(width: 7, height: 7, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}
