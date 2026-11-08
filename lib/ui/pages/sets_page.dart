import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';
import 'practice_page.dart';

class SetsPage extends StatefulWidget {
  const SetsPage({super.key});
  @override
  State<SetsPage> createState() => _SetsPageState();
}

class _SetsPageState extends State<SetsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _columns = [];
  List<Map<String, dynamic>> _sets = [];
  int? _activeColumn;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadColumns();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadColumns() async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cols = await store.api.columns(store.resourceId);
      if (!mounted) return;
      setState(() {
        _columns = cols;
        _activeColumn ??= cols.isNotEmpty ? int.tryParse('${cols.first['column_id']}') : null;
      });
      await _loadSets();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSets() async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final merged = <Map<String, dynamic>>[];
      if (_activeColumn != null) {
        merged.addAll(await store.api.sets(store.resourceId, _activeColumn!));
      } else {
        for (final c in _columns) {
          final id = int.tryParse('${c['column_id']}');
          if (id != null) merged.addAll(await store.api.sets(store.resourceId, id));
        }
      }
      if (mounted) setState(() => _sets = merged);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final kw = _search.text.trim().toLowerCase();
    if (kw.isEmpty) return _sets;
    return _sets.where((s) => '${s['set_name'] ?? ''}'.toLowerCase().contains(kw)).toList();
  }

  void _start(Map<String, dynamic> set) {
    final struct = set['struct'] is Map ? (set['struct'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final contents = (struct['contents'] is List)
        ? (struct['contents'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    if (contents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该套卷暂无可练习的听说内容')));
      return;
    }
    final base = '${set['__base_url'] ?? 'https://cdnsubject.ets100.com/made/'}';
    final first = contents.first;
    final zip = '${first['url'] ?? ''}'.startsWith('http')
        ? '${first['url']}'
        : '${base.replaceFirst(RegExp(r'/*$'), '')}/${'${first['url'] ?? ''}'.replaceFirst(RegExp(r'^/+'), '')}';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PracticePage(
        stid: '${first['real_id'] ?? ''}',
        zipUrl: zip,
        title: '${set['set_name'] ?? '套卷练习'}',
        homeworkId: '',
        setId: '${set['set_id'] ?? struct['set_id'] ?? ''}',
        resourceId: context.read<AppStore>().resourceId,
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
            title: '套卷练习',
            subtitle: '按栏目浏览，听说 / 读写 / 听力全覆盖',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: '搜索套卷名称',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(onPressed: _loading ? null : _loadColumns, icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 250,
                child: Panel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 10),
                        child: Text('栏目', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      _columnTile('全部套卷', _columns.fold<int>(0, (a, c) => a + ((c['column_set_count'] as num?)?.toInt() ?? 0)),
                          _activeColumn == null, () {
                        setState(() => _activeColumn = null);
                        _loadSets();
                      }),
                      ..._columns.map((c) {
                        final id = int.tryParse('${c['column_id']}');
                        return _columnTile(
                          '${c['column_name'] ?? '栏目'}',
                          (c['column_set_count'] as num?)?.toInt() ?? 0,
                          _activeColumn == id,
                          () {
                            setState(() => _activeColumn = id);
                            _loadSets();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        _activeColumn == null
                            ? '全部套卷'
                            : '${_columns.firstWhere((c) => '${c['column_id']}' == '$_activeColumn', orElse: () => const {'column_name': '套卷'})['column_name']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text('${_filtered.length} 套可选', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ]),
                    const SizedBox(height: 14),
                    if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _loadColumns), const SizedBox(height: 14)],
                    if (_loading)
                      const LoadingPanel(label: '正在加载套卷…')
                    else if (_filtered.isEmpty)
                      const EmptyState(title: '该栏目暂无套卷', icon: Icons.layers_clear_rounded)
                    else
                      LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth > 1150 ? 3 : constraints.maxWidth > 760 ? 2 : 1;
                        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: _filtered.map((s) => SizedBox(width: width, child: _setCard(scheme, s))).toList(),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _columnTile(String label, int count, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  )),
            ),
            Text('$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _setCard(ColorScheme scheme, Map<String, dynamic> set) {
    final struct = set['struct'] is Map ? (set['struct'] as Map) : const {};
    final contents = struct['contents'] is List ? (struct['contents'] as List) : const [];
    final difficulty = double.tryParse('${set['difficulty_rate'] ?? 0}') ?? 0;
    final diffText = difficulty <= 0 ? '—' : difficulty < 0.4 ? '简单' : difficulty < 0.7 ? '中等' : '较难';
    return Panel(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: () => _start(set),
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('${set['first_column_name'] ?? '套卷'}',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 10.5)),
              ),
              const Spacer(),
              Text('难度 $diffText', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 14),
            Text('${set['set_name'] ?? struct['set_name'] ?? '套卷'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.35)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.quiz_rounded, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('${contents.length} 题', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 14),
              Icon(Icons.tag_rounded, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${set['set_id'] ?? struct['set_id'] ?? ''}', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _start(set),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('开始练习'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
