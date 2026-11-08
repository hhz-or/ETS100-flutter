import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'homework_detail_page.dart';
import 'homework_page.dart';
import 'sets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _homeworks = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        store.api.homeworks(store.parentAccountId).catchError((_) => <Map<String, dynamic>>[]),
        store.api.mistakeSummary(store.parentAccountId).catchError((_) => <String, dynamic>{}),
        store.api.announcements().catchError((_) => <dynamic>[]),
      ]);
      if (mounted) {
        setState(() {
          _homeworks = _asList(results[0]).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
          _summary = (results[1] is Map) ? (results[1] as Map).cast<String, dynamic>() : <String, dynamic>{};
          _announcements = _asList(results[2]);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    return const [];
  }

  int get _todoCount => _homeworks.where((h) => _state(h) == 'todo').length;
  int get _doneCount => _homeworks.where((h) => _state(h) == 'done').length;
  int get _mistakeCount {
    final c = _summary['to_correct_count'];
    if (c is Map) return ((c['audio'] ?? 0) as num).toInt() + ((c['read_write'] ?? 0) as num).toInt();
    return 0;
  }

  static String _state(Map<String, dynamic> hw) {
    if ('${hw['overtime']}' == '1') return 'overdue';
    if ('${hw['status']}' == '1' || '${hw['complete']}' == '1') return 'done';
    final end = int.tryParse('${hw['end']}') ?? 0;
    if (end > 0 && DateTime.fromMillisecondsSinceEpoch(end * 1000).isBefore(DateTime.now())) return 'overdue';
    return 'todo';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final greeting = DateTime.now().hour < 11 ? '早上好' : DateTime.now().hour < 18 ? '下午好' : '晚上好';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting，${store.displayName}', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                    Text('今天也把每一次开口，变成看得见的进步。',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _load), const SizedBox(height: 18)],
          HeroCard(
            colors: [scheme.primary, scheme.tertiary],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${store.gradeName} · 学习中心',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 18),
                      Text('保持节奏，\n今天完成一份作业。', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: scheme.onPrimary)),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              final todo = _homeworks.where((h) => _state(h) == 'todo').toList();
                              if (todo.isEmpty) {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const HomeworkPage()));
                              } else {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => HomeworkPage(initialHomework: todo.first)));
                              }
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text(_todoCount > 0 ? '继续练习' : '查看作业'),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.onPrimary,
                              foregroundColor: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetsPage())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onPrimary,
                              side: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.5)),
                            ),
                            child: const Text('套卷练习'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                SizedBox(
                  width: 270,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _heroStat('待完成', '$_todoCount'),
                      _heroStat('已完成', '$_doneCount'),
                      _heroStat('待订正', '$_mistakeCount'),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _quickAction(scheme, Icons.assignment_rounded, '我的作业', '$_todoCount 份待完成',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeworkPage())))),
              const SizedBox(width: 14),
              Expanded(child: _quickAction(scheme, Icons.layers_rounded, '套卷练习', '听说 · 读写 · 听力',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetsPage())))),
              const SizedBox(width: 14),
              Expanded(child: _quickAction(scheme, Icons.menu_book_rounded, '同步课程', '教材单元同步',
                  () => _showTip('同步课程', '在左侧「同步课程」中按教材浏览单元。'))),
              const SizedBox(width: 14),
              Expanded(child: _quickAction(scheme, Icons.auto_stories_rounded, '错题本', '$_mistakeCount 道待订正',
                  () => _showTip('错题本', '在左侧「错题本」中查看与订正。'))),
            ],
          ),
          const SizedBox(height: 28),
          SectionTitle(
            title: '最近作业',
            subtitle: '来自 g/homework/list（待完成 / 已完成 / 已过期合并）',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeworkPage())),
              child: const Text('全部'),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const LoadingPanel()
          else if (_homeworks.isEmpty)
            const EmptyState(title: '暂时没有作业', subtitle: '去套卷练习里挑一套吧', icon: Icons.assignment_turned_in_rounded)
          else
            ...(_homeworks.take(4).map((hw) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _homeworkRow(scheme, hw),
                ))),
          if (_announcements.isNotEmpty) ...[
            const SizedBox(height: 22),
            Panel(
              color: scheme.tertiaryContainer.withValues(alpha: 0.55),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_rounded, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('公告', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onTertiaryContainer)),
                        const SizedBox(height: 6),
                        Text('${_announcements.first}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: scheme.onTertiaryContainer.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
      ],
    );
  }

  Widget _quickAction(ColorScheme scheme, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: scheme.primary, size: 22),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _homeworkRow(ColorScheme scheme, Map<String, dynamic> hw) {
    final state = _state(hw);
    final color = state == 'done' ? Colors.green : state == 'overdue' ? scheme.error : scheme.primary;
    final struct = hw['struct'] is Map ? (hw['struct'] as Map) : const {};
    final name = '${hw['set_name'] ?? struct['set_name'] ?? hw['name'] ?? '作业'}';
    final count = (struct['contents'] is List) ? (struct['contents'] as List).length : 0;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HomeworkDetailPage(homeworkId: '${hw['id']}', resourceId: context.read<AppStore>().resourceId, item: hw),
        )),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.assignment_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${hw['first_column_name'] ?? hw['set_module_name'] ?? '作业'} · $count 题',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(
                state == 'done' ? '已完成' : state == 'overdue' ? '已过期' : '待完成',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showTip(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
      ),
    );
  }
}
