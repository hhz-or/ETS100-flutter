import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../glass.dart';
import '../palette_picker.dart';
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

  static const _items = [
    _NavItem('首页', Icons.space_dashboard_rounded),
    _NavItem('我的作业', Icons.assignment_rounded),
    _NavItem('套卷练习', Icons.layers_rounded),
    _NavItem('同步课程', Icons.menu_book_rounded),
    _NavItem('错题本', Icons.auto_stories_rounded),
    _NavItem('设置', Icons.tune_rounded),
    _NavItem('关于', Icons.info_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final start = Platform.environment['ETS_START_PAGE'] ?? '';
    const names = ['home', 'homework', 'sets', 'courses', 'mistakes', 'settings', 'about'];
    final i = names.indexOf(start);
    if (i >= 0) _index = i;

    if (Platform.environment['ETS_OPEN_PALETTE'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPalette(context, context.read<AppStore>());
      });
    }

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
    final store = context.watch<AppStore>();
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < 7; i++)
          SingleActivator(
            const [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
              LogicalKeyboardKey.digit5,
              LogicalKeyboardKey.digit6,
              LogicalKeyboardKey.digit7,
            ][i],
            control: true,
          ): () => setState(() => _index = i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: EtsBackground(
            child: SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final mobile = constraints.maxWidth < 940;
                return Column(
                  children: [
                    _TopBar(
                      store: store,
                      compact: mobile,
                      onPalette: () => _openPalette(context, store),
                      onGlass: () => store.setGlass(!store.glassEnabled),
                      onTheme: _cycleTheme,
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          if (!mobile) _Sidebar(store: store, index: _index, onSelect: (i) => setState(() => _index = i)),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 340),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0.012, 0), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: KeyedSubtree(key: ValueKey(_index), child: _page()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width < 940
              ? _BottomNav(
                  index: _index,
                  onSelect: (i) {
                    if (i == 4) {
                      _openMore(context, store);
                    } else {
                      setState(() => _index = i);
                    }
                  },
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _cycleTheme() async {
    final store = context.read<AppStore>();
    final next = switch (store.themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await store.setTheme(mode: next);
  }

  Future<void> _openPalette(BuildContext context, AppStore store) async {
    await showPalettePickerSheet(
      context,
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
    );
  }

  void _openMore(BuildContext context, AppStore store) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('更多', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _moreTile(Icons.menu_book_rounded, '同步课程', '教材 · 单元 · 模块', () {
              Navigator.pop(context);
              setState(() => _index = 3);
            }),
            _moreTile(Icons.auto_stories_rounded, '错题本', '待订正与已订正', () {
              Navigator.pop(context);
              setState(() => _index = 4);
            }),
            _moreTile(Icons.tune_rounded, '设置', '外观 · 设备 · 工具', () {
              Navigator.pop(context);
              setState(() => _index = 5);
            }),
            _moreTile(Icons.info_rounded, '关于', '协议与免责声明', () {
              Navigator.pop(context);
              setState(() => _index = 6);
            }),
            _moreTile(Icons.palette_rounded, 'M3E 调色盘', '三色圆盘 + 动态方案', () {
              Navigator.pop(context);
              _openPalette(context, store);
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.store, required this.index, required this.onSelect});
  final AppStore store;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EtsGlass.surface(
      context: context,
      margin: const EdgeInsets.fromLTRB(18, 0, 0, 18),
      radius: 36,
      color: EtsGlass.on ? scheme.surface.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
      child: SizedBox(
        width: 264,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: BrandMark(size: 46, showSubtitle: true),
              ),
              const SizedBox(height: 26),
              ...List.generate(_ShellPageState._items.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _NavButton(
                    label: _ShellPageState._items[i].label,
                    icon: _ShellPageState._items[i].icon,
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                );
              }),
              const Spacer(),
              _UserCard(store: store),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final mapped = index >= 4 ? 4 : index;
    final bar = NavigationBar(
      selectedIndex: mapped,
      onDestinationSelected: onSelect,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: '首页'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: '作业'),
        NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers_rounded), label: '套卷'),
        NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: '错题'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: '更多'),
      ],
    );
    if (!EtsGlass.on) return bar;
    return EtsGlass.surface(context: context, radius: 0, child: bar);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.store,
    required this.compact,
    required this.onPalette,
    required this.onGlass,
    required this.onTheme,
  });
  final AppStore store;
  final bool compact;
  final VoidCallback onPalette;
  final VoidCallback onGlass;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeIcon = switch (store.themeMode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 8, compact ? 12 : 24, 4),
      child: Row(
        children: [
          if (compact) const BrandMark(size: 38, showSubtitle: false),
          if (compact) const Spacer(),
          if (!compact) ...[
            Text(store.gradeName, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const Spacer(),
          ],
          _PaletteButton(seed: store.seedColor, onTap: onPalette),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onGlass,
            tooltip: store.glassEnabled ? '关闭液态玻璃' : '开启液态玻璃',
            isSelected: store.glassEnabled,
            icon: const Icon(Icons.blur_on_rounded),
            selectedIcon: Icon(Icons.blur_on_rounded, color: scheme.primary),
          ),
          IconButton(onPressed: onTheme, tooltip: '切换主题', icon: Icon(themeIcon)),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary,
            child: Text(
              store.displayName.isEmpty ? '?' : store.displayName.characters.first,
              style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.seed, required this.onTap});
  final Color seed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '壁纸颜色',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: QuadrantSwatch(seed: seed, size: 28),
          ),
        ),
      ),
    );
  }
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
        ? scheme.secondaryContainer
        : _hover
            ? scheme.surfaceContainerHighest
            : Colors.transparent;
    final fg = widget.selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: null,
          ),
          child: Row(children: [
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(color: fg, fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w600, fontSize: 14)),
            ),

          ]),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary,
            child: Text(store.displayName.isEmpty ? '?' : store.displayName.characters.first,
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Text(store.gradeName, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(store.schoolName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          const Text('已连接', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('v1.1', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
