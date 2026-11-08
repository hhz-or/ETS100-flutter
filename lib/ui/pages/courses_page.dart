import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _books = [];
  Map<String, dynamic>? _book;
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _unit;
  List<Map<String, dynamic>> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await store.api.bookList('274');
      final raw = body is Map ? (body['books'] ?? body['data']) : null;
      final books = (raw is List) ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];
      final preferred = books.where((b) => '${b['resource_id']}' == store.resourceId).toList();
      final list = preferred.isNotEmpty ? preferred : books;
      if (mounted) {
        setState(() {
          _books = list;
          _book = list.isNotEmpty ? list.first : null;
        });
        if (_book != null) await _loadUnits(_book!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnits(Map<String, dynamic> book) async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _units = [];
      _unit = null;
      _modules = [];
    });
    try {
      final body = await store.api.unitList('${book['resource_id'] ?? store.resourceId}', '${book['id']}');
      final raw = body is Map ? body['data'] : null;
      final units = (raw is List) ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _units = units;
          _unit = units.isNotEmpty ? units.first : null;
        });
        if (_unit != null) await _loadModules(book, _unit!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadModules(Map<String, dynamic> book, Map<String, dynamic> unit) async {
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _modules = [];
    });
    try {
      final body = await store.api.moduleList(
          '${book['resource_id'] ?? store.resourceId}', '${book['id']}', '${unit['unit_id']}');
      final raw = body is Map ? body['data'] : null;
      final modules = (raw is List) ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];
      if (mounted) setState(() => _modules = modules);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            title: '同步课程',
            subtitle: '按教材 → 单元 → 模块浏览，听说读写同步训练',
            trailing: IconButton.filledTonal(onPressed: _loading ? null : _loadBooks, icon: const Icon(Icons.refresh_rounded)),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _loadBooks), const SizedBox(height: 14)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                child: Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 10),
                        child: Text('教材', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      ..._books.map((b) {
                        final selected = '${b['id']}' == '${_book?['id']}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() => _book = b);
                              _loadUnits(b);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: selected ? scheme.primaryContainer : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    '${b['display_name']?.toString().isNotEmpty == true ? b['display_name'] : b['name'] ?? '教材'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Text('${b['grade_name'] ?? ''}',
                                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                              ]),
                            ),
                          ),
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
                    if (_loading) const LoadingPanel(label: '正在加载课程…') else ...[
                      Text('${_book?['display_name'] ?? _book?['name'] ?? '教材'}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _units.map((u) {
                          final selected = '${u['unit_id']}' == '${_unit?['unit_id']}';
                          return ChoiceChip(
                            label: Text('${u['unit_name'] ?? u['unit_number'] ?? '单元'}'),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() => _unit = u);
                              if (_book != null) _loadModules(_book!, u);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      if (_modules.isEmpty)
                        const EmptyState(title: '该单元暂无模块', icon: Icons.menu_book_rounded)
                      else
                        LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 540 ? 2 : 1;
                          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _modules.map((m) {
                              final count = (m['module_set_count'] as num?)?.toInt() ?? 0;
                              return SizedBox(
                                width: width,
                                child: Panel(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                              color: scheme.tertiary.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(14)),
                                          child: Icon(Icons.auto_stories_rounded, size: 19, color: scheme.tertiary),
                                        ),
                                        const Spacer(),
                                        if ('${m['module_is_lock']}' == '1')
                                          Icon(Icons.lock_rounded, size: 16, color: scheme.onSurfaceVariant),
                                      ]),
                                      const SizedBox(height: 12),
                                      Text('${m['module_name'] ?? '模块'}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text('$count 套 · 完成 ${m['module_set_complete_count'] ?? 0}',
                                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.tonal(
                                          onPressed: () => _showModule(m),
                                          child: const Text('查看模块'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showModule(Map<String, dynamic> m) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 6, 26, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m['module_name'] ?? '模块'}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${m['module_set_count'] ?? 0} 套练习 · 已锁定 ${'${m['module_is_lock']}' == '1' ? '是' : '否'}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            Text(
              '同步课程模块的套卷由服务端按模块聚合。请在「套卷练习」中按栏目查找同名套卷，'
              '或回到官方客户端查看完整模块内容。',
              style: TextStyle(height: 1.7, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
            ),
          ],
        ),
      ),
    );
  }
}
