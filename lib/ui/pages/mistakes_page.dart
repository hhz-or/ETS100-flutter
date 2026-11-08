import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'practice_page.dart';

class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});
  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _items = [];
  bool _showDone = false;
  String _type = 'all';

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
        store.api.mistakeSummary(store.parentAccountId).catchError((_) => <String, dynamic>{}),
        store.api.mistakeList(store.parentAccountId, status: 0, type: 1).catchError((_) => <Map<String, dynamic>>[]),
        store.api.mistakeList(store.parentAccountId, status: 1, type: 1).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (mounted) {
        setState(() {
          _summary = (results[0] as Map?)?.cast<String, dynamic>() ?? {};
          _items = [
            ...(results[1] as List).whereType<Map<String, dynamic>>().map((e) => {...e, '__done': false}),
            ...(results[2] as List).whereType<Map<String, dynamic>>().map((e) => {...e, '__done': true}),
          ];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _todoAudio => ((_summary['to_correct_count']?['audio'] ?? 0) as num).toInt();
  int get _todoRw => ((_summary['to_correct_count']?['read_write'] ?? 0) as num).toInt();
  int get _corrected {
    final c = _summary['corrected_count'];
    if (c is Map) return ((c['audio'] ?? 0) as num).toInt() + ((c['read_write'] ?? 0) as num).toInt();
    return 0;
  }

  List<Map<String, dynamic>> get _filtered {
    return _items.where((m) {
      if (('${m['__done']}' == 'true') != _showDone) return false;
      if (_type != 'all' && _typeOf(m) != _type) return false;
      return true;
    }).toList();
  }

  String _typeOf(Map<String, dynamic> m) {
    final readType = int.tryParse('${m['read_type']}') ?? 5;
    return readType == 5 ? 'audio' : 'read_write';
  }

  void _practice(Map<String, dynamic> m) {
    final struct = m['struct'] is Map ? (m['struct'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final contents = (struct['contents'] is List)
        ? (struct['contents'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    if (contents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该错题暂无可用 content 包')));
      return;
    }
    final base = '${m['__base_url'] ?? 'https://cdnsubject.ets100.com/made/'}';
    final first = contents.first;
    final name = '${first['url'] ?? ''}';
    final zip = name.startsWith('http')
        ? name
        : '${base.replaceFirst(RegExp(r'/*$'), '')}/${name.replaceFirst(RegExp(r'^/+'), '')}';
    final store = context.read<AppStore>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PracticePage(
        stid: '${first['real_id'] ?? ''}',
        zipUrl: zip,
        title: '${struct['set_name'] ?? '错题订正'}',
        homeworkId: '',
        setId: '${struct['set_id'] ?? ''}',
        resourceId: store.resourceId,
        contents: contents,
        initialIndex: 0,
      ),
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
            title: '错题本',
            subtitle: '按题型沉淀薄弱点，支持反复订正',
            trailing: IconButton.filledTonal(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: StatTile(label: '待订正听说题', value: '$_todoAudio', icon: Icons.headphones_rounded, color: scheme.primary)),
            const SizedBox(width: 14),
            Expanded(child: StatTile(label: '待订正读写题', value: '$_todoRw', icon: Icons.edit_note_rounded, color: scheme.tertiary)),
            const SizedBox(width: 14),
            Expanded(child: StatTile(label: '已订正题目', value: '$_corrected', icon: Icons.task_alt_rounded, color: Colors.green)),
          ]),
          const SizedBox(height: 18),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('待订正')),
                  ButtonSegment(value: true, label: Text('已订正')),
                ],
                selected: {_showDone},
                onSelectionChanged: (v) => setState(() => _showDone = v.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(const StadiumBorder()),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _type,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部题型')),
                  DropdownMenuItem(value: 'audio', child: Text('听说')),
                  DropdownMenuItem(value: 'read_write', child: Text('读写')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'all'),
              ),
              const Spacer(),
              Text('数据来自 m/mistake/summary + m/mistake/list',
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _load), const SizedBox(height: 14)],
          if (_loading)
            const LoadingPanel(label: '正在加载错题…')
          else if (_filtered.isEmpty)
            const EmptyState(title: '该分类下暂无错题', icon: Icons.auto_stories_rounded)
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth > 1180 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _filtered.map((m) => SizedBox(width: width, child: _card(scheme, m))).toList(),
              );
            }),
        ],
      ),
    );
  }

  Widget _card(ColorScheme scheme, Map<String, dynamic> m) {
    final struct = m['struct'] is Map ? (m['struct'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final contents = (struct['contents'] is List) ? (struct['contents'] as List) : const [];
    final first = contents.isNotEmpty && contents.first is Map ? (contents.first as Map) : const {};
    final readType = int.tryParse('${m['read_type']}') ?? 5;
    final done = '${m['__done']}' == 'true';
    final score = double.tryParse('${m['total_point'] ?? 0}') ?? 0;
    final name = '${first['group_name'] ?? first['first_type_name'] ?? m['question_type'] ?? '错题'}';
    final setName = '${struct['set_name'] ?? ''}';
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: scheme.tertiary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Text(readType == 5 ? '听说' : '读写',
                  style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: done ? Colors.green.withValues(alpha: 0.12) : scheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(done ? '已订正' : '待订正',
                  style: TextStyle(
                      color: done ? Colors.green : scheme.error, fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(setName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(children: [
            ScoreRing(score: score, max: 5, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最近一次 ${m['update_time'] ?? ''}', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('点击去订正会重新下载 content 包并朗读评测',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _practice(m),
              child: Text(done ? '再做一次' : '去订正'),
            ),
          ]),
        ],
      ),
    );
  }
}
