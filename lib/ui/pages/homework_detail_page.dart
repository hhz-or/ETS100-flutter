import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'practice_page.dart';

class HomeworkDetailPage extends StatefulWidget {
  const HomeworkDetailPage({super.key, required this.homeworkId, required this.resourceId, this.item});
  final String homeworkId;
  final String resourceId;
  final Map<String, dynamic>? item;
  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _homework;
  List<Map<String, dynamic>> _contents = [];
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = context.read<AppStore>();
      final results = await Future.wait<Object?>([
        store.api.homeworkInfo(widget.homeworkId, widget.resourceId).catchError((_) => <String, dynamic>{}),
        Future.value(widget.item),
      ]);
      var item = results[1] as Map<String, dynamic>?;
      if (item == null) {
        final list = await store.api.homeworks(store.parentAccountId, limit: 50);
        for (final h in list) {
          if ('${h['id']}' == widget.homeworkId) {
            item = h;
            break;
          }
        }
      }
      final info = results[0] as Map<String, dynamic>? ?? {};
      final struct = item?['struct'] is Map ? (item!['struct'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final contents = (struct['contents'] is List)
          ? (struct['contents'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _baseUrl = '${item?['__base_url'] ?? struct['base_url'] ?? ''}';
          _homework = {
            ...?item,
            ...info,
            'id': widget.homeworkId,
            'set_id': '${item?['set_id'] ?? struct['set_id'] ?? ''}',
            'set_name': '${item?['set_name'] ?? struct['set_name'] ?? '作业'}',
          };
          _contents = contents;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start(int index) {
    if (index < 0 || index >= _contents.length) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PracticePage(
        stid: '${_contents[index]['real_id'] ?? ''}',
        zipUrl: _zipUrl(_contents[index]),
        title: '${_contents[index]['group_name'] ?? _contents[index]['first_type_name'] ?? '练习'}',
        homeworkId: widget.homeworkId,
        setId: '${_homework?['set_id'] ?? ''}',
        resourceId: widget.resourceId,
        contents: _contents,
        initialIndex: index,
      ),
    ));
  }

  String _zipUrl(Map<String, dynamic> content) {
    final name = '${content['url'] ?? ''}';
    if (name.isEmpty) return '';
    if (name.startsWith('http')) return name;
    final base = _baseUrl.isNotEmpty ? _baseUrl : 'https://cdnsubject.ets100.com/made/';
    return '${base.replaceFirst(RegExp(r'/*$'), '')}/${name.replaceFirst(RegExp(r'^/+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hw = _homework ?? const <String, dynamic>{};
    final point = double.tryParse('${hw['point'] ?? 0}') ?? 0;
    final total = double.tryParse('${hw['total_point'] ?? 10}') ?? 10;
    final useTime = int.tryParse('${hw['use_time'] ?? 0}') ?? 0;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: EtsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作业详情', style: Theme.of(context).textTheme.headlineMedium),
                    Text('作业 #${widget.homeworkId}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _load), const SizedBox(height: 16)],
          if (_loading)
            const LoadingPanel(label: '正在加载作业详情…')
          else ...[
            HeroCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${hw['set_name'] ?? '作业'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill('${_statusText(hw)}'),
                            _pill('${hw['first_column_name'] ?? hw['set_module_name'] ?? '听说模拟'}'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _contents.isEmpty ? null : () => _start(0),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('开始练习'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
                            ),
                            const SizedBox(width: 12),
                            Text('${_contents.length} 题',
                                style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Row(
                    children: [
                      _metric('${point.toStringAsFixed(1)}', '得分 / ${total.toStringAsFixed(0)}'),
                      const SizedBox(width: 22),
                      _metric('${(useTime / 60).round()}′', '用时'),
                      const SizedBox(width: 22),
                      _metric('${_contents.length}', '题目'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final list = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: '题目列表', subtitle: '点击任意题目进入练习页（下载并解密 content 包）'),
                  const SizedBox(height: 14),
                  ...List.generate(_contents.length, (i) {
                    final c = _contents[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: InkWell(
                          onTap: () => _start(i),
                          borderRadius: BorderRadius.circular(22),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${c['group_name'] ?? c['first_type_name'] ?? '题目'}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text('${c['first_type_name'] ?? ''} · ${_fmtSize((c['size'] as num?)?.toInt() ?? 0)}',
                                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              FilledButton.tonal(onPressed: () => _start(i), child: const Text('练习')),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
              final info = Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作业要求', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _kv('开始时间', _fmtTime(hw['begin'])),
                    _kv('截止时间', _fmtTime(hw['end'])),
                    _kv('总分', '${total.toStringAsFixed(0)} 分'),
                    _kv('难度系数', '${hw['difficulty_rate'] ?? '—'}'),
                    _kv('允许补做', '${hw['allow_overtime'] ?? hw['overtime'] ?? 0}' == '1' ? '是' : '否'),
                    const SizedBox(height: 12),
                    Text('说明', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${hw['introduction'] ?? '—'}', style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              );
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: list),
                      const SizedBox(width: 18),
                      SizedBox(width: 320, child: info),
                    ])
                  : Column(children: [list, const SizedBox(height: 18), info]);
            }),
          ],
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
      );

  Widget _metric(String value, String label) => Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600)),
        ],
      );

  String _statusText(Map<String, dynamic> hw) {
    if ('${hw['overtime']}' == '1') return '已过期';
    if ('${hw['status']}' == '1' || '${hw['complete']}' == '1' || ('${hw['submit']}' == '1')) return '已完成';
    return '待完成';
  }

  String _fmtTime(dynamic value) {
    final n = int.tryParse('$value') ?? 0;
    if (n <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(n * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(k, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      );
}
