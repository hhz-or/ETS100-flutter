import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'homework_detail_page.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, this.initialHomework});
  final Map<String, dynamic>? initialHomework;
  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.initialHomework != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(widget.initialHomework!);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = context.read<AppStore>();
      final items = await store.api.homeworks(store.parentAccountId, limit: 50);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _state(Map<String, dynamic> hw) {
    if ('${hw['overtime']}' == '1') return 'overdue';
    if ('${hw['status']}' == '1' || '${hw['complete']}' == '1') return 'done';
    final end = int.tryParse('${hw['end']}') ?? 0;
    if (end > 0 && DateTime.fromMillisecondsSinceEpoch(end * 1000).isBefore(DateTime.now())) return 'overdue';
    return 'todo';
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all' ? _items : _items.where((h) => _state(h) == _filter).toList();

  void _open(Map<String, dynamic> hw) {
    final store = context.read<AppStore>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HomeworkDetailPage(homeworkId: '${hw['id']}', resourceId: store.resourceId, item: hw),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '我的作业',
            subtitle: '待完成、已完成与已过期合并展示，点击进入详情',
            trailing: IconButton.filledTonal(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              _chip('all', '全部'),
              _chip('todo', '待完成'),
              _chip('done', '已完成'),
              _chip('overdue', '已过期'),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _load), const SizedBox(height: 16)],
          if (_loading)
            const LoadingPanel(label: '正在拉取作业列表…')
          else if (_filtered.isEmpty)
            const EmptyState(title: '暂无作业', subtitle: '该分类下还没有作业', icon: Icons.assignment_rounded)
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 820 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _filtered.map((hw) => SizedBox(width: width, child: _card(scheme, hw))).toList(),
              );
            }),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Theme.of(context).colorScheme.onSecondaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _card(ColorScheme scheme, Map<String, dynamic> hw) {
    final state = _state(hw);
    final color = state == 'done' ? Colors.green : state == 'overdue' ? scheme.error : scheme.primary;
    final struct = hw['struct'] is Map ? (hw['struct'] as Map) : const {};
    final contents = struct['contents'] is List ? (struct['contents'] as List) : const [];
    final name = '${hw['set_name'] ?? struct['set_name'] ?? hw['name'] ?? '作业'}';
    final point = double.tryParse('${hw['point'] ?? 0}') ?? 0;
    final total = double.tryParse('${hw['total_point'] ?? 10}') ?? 10;
    return Panel(
      padding: const EdgeInsets.all(22),
      child: InkWell(
        onTap: () => _open(hw),
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    state == 'done' ? '已完成' : state == 'overdue' ? '已过期' : '待完成',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                const Spacer(),
                Text('${hw['first_column_name'] ?? hw['set_module_name'] ?? '作业'}',
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 16),
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.35)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.quiz_rounded, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('${contents.length} 题', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.stars_rounded, size: 16, color: state == 'done' ? Colors.green : scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('${point.toStringAsFixed(1)} / ${total.toStringAsFixed(0)} 分',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dueText(hw),
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _open(hw),
                  child: Text(state == 'done' ? '查看详情' : '开始练习'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dueText(Map<String, dynamic> hw) {
    final end = int.tryParse('${hw['end']}') ?? 0;
    if (end <= 0) return '无截止时间';
    final d = DateTime.fromMillisecondsSinceEpoch(end * 1000);
    return '截止 ${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
