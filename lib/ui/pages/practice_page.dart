import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/content.dart';
import '../../core/crypto.dart';
import '../../core/ise.dart';
import '../../core/practice_service.dart';
import '../../core/recording.dart';
import '../../core/speex_ffi.dart';
import '../../core/store.dart';
import '../widgets.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.stid,
    required this.zipUrl,
    required this.title,
    required this.homeworkId,
    required this.setId,
    required this.resourceId,
    required this.contents,
    this.initialIndex = 0,
  });
  final String stid;
  final String zipUrl;
  final String title;
  final String homeworkId;
  final String setId;
  final String resourceId;
  final List<Map<String, dynamic>> contents;
  final int initialIndex;
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final ContentService _contentService = ContentService();
  late final int _index = widget.initialIndex;
  late final String _stid = widget.stid;
  late final String _zipUrl = widget.zipUrl;

  bool _loading = true;
  String? _error;
  List<ContentStep> _steps = [];
  ContentPackage? _package;
  File? _audioFile;
  File? _imageFile;
  List<File?> _askAudio = [];
  bool _showAnswer = true;

  // 评测状态
  final EtsRecorder _recorder = EtsRecorder();
  bool _recording = false;
  bool _evaluating = false;
  bool _uploading = false;
  String? _evalError;
  IseResult? _result;
  List<int>? _spx;
  dynamic _pcm;
  String? _uploadMsg;
  Timer? _timer;
  int _recordSeconds = 0;
  DateTime? _recordStart;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _steps = [];
      _package = null;
      _audioFile = null;
      _imageFile = null;
      _askAudio = [];
      _result = null;
      _spx = null;
      _pcm = null;
      _uploadMsg = null;
      _evalError = null;
      _showAnswer = true;
    });
    try {
      final package = await _contentService.load(stid: _stid, zipUrl: _zipUrl);
      final info = package.info;
      final kind = package.kind;
      final audio = info['audio'] == null ? null : package.mediaFile('${info['audio']}');
      final image = info['image'] == null ? null : package.mediaFile('${info['image']}');
      final questions = info['question'] is List ? (info['question'] as List) : const [];
      final asks = <File?>[];
      if (kind == 'dialogue') {
        for (final q in questions) {
          if (q is Map && q['askaudio'] != null) {
            asks.add(package.mediaFile('${q['askaudio']}'));
          } else {
            asks.add(null);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _package = package;
        _steps = package.steps;
        _audioFile = audio;
        _imageFile = image;
        _askAudio = asks;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(File file) async {
    await _player.stop();
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> _startRecord() async {
    setState(() {
      _evalError = null;
      _result = null;
      _uploadMsg = null;
    });
    try {
      await _recorder.start();
      _recordStart = DateTime.now();
      _recordSeconds = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) {
          setState(() => _recordSeconds = DateTime.now().difference(_recordStart!).inSeconds);
        }
      });
      setState(() => _recording = true);
    } catch (e) {
      setState(() => _evalError = '$e');
    }
  }

  Future<void> _stopAndEvaluate() async {
    _timer?.cancel();
    setState(() {
      _recording = false;
      _evaluating = true;
      _evalError = null;
    });
    try {
      final pcm = await _recorder.stop();
      if (pcm.length < 16000) throw Exception('录音太短（至少约 0.6 秒）');
      final encoder = await SpeexEncoder.instance();
      final spx = encoder.encode(pcm);
      if (!mounted) return;
      final store = context.read<AppStore>();
      final token = await store.api.aiToken();
      final ppr = await _resolvePaperInfo();
      final session = _buildSession(store, ppr);
      final result = await IseService.evaluate(spx: spx, session: session, token: token);
      if (!mounted) return;
      setState(() {
        _pcm = pcm;
        _spx = spx;
        _result = result;
      });
    } catch (e) {
      if (mounted) setState(() => _evalError = '$e');
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  Future<Map<String, dynamic>> _resolvePaperInfo() async {
    final store = context.read<AppStore>();
    try {
      final body = await store.api.pprRes(_stid);
      final batch = body is Map ? body['batch'] : null;
      final item = (batch is List && batch.isNotEmpty && batch.first is Map) ? (batch.first as Map) : const {};
      return {
        'resId': '${item['res_id'] ?? ''}',
        'entityId': '${item['entity_id'] ?? _stid}',
        'order': int.tryParse('${item['order'] ?? 1}') ?? 1,
      };
    } catch (_) {
      return {'resId': '', 'entityId': _stid, 'order': 1};
    }
  }

  IseSession _buildSession(AppStore store, Map<String, dynamic> ppr) {
    final profile = store.profile ?? const <String, dynamic>{};
    final ecard = store.activeEcard ?? const <String, dynamic>{};
    final kind = _package?.kind ?? 'read';
    final category = kind == 'read'
        ? 'read_sentence'
        : kind == 'dialogue'
            ? 'simple_expression_ufi'
            : kind == 'picture'
                ? 'topic'
                : 'read_sentence';
    final regions = [
      profile['province_id'] ?? '',
      profile['city_id'] ?? '',
      0,
    ].where((e) => '$e'.isNotEmpty).join(',');
    return IseSession(
      accountId: '${profile['recent_account_id'] ?? ''}',
      uid: '${EtsCrypto.tokenUid(store.api.token)}',
      classId: '${ecard['class_id'] ?? ''}',
      schoolId: '${ecard['school_id'] ?? ''}',
      gradeId: '${profile['grade_id'] ?? ''}',
      stageId: '${profile['school_year_id'] ?? ''}',
      regionId: regions.isEmpty ? '5269,5270,0' : regions,
      sceneType: widget.homeworkId.isNotEmpty ? 'homework' : 'practice',
      sceneId: widget.homeworkId.isNotEmpty ? widget.homeworkId : widget.setId,
      category: category,
      paperId: '${ppr['resId'] ?? ''}',
    );
  }

  Future<void> _upload() async {
    final result = _result;
    final spx = _spx;
    final pcm = _pcm;
    if (result == null || spx == null || pcm == null) return;
    if (result.scores == null || result.scores!.isRejected) {
      setState(() => _uploadMsg = '评测被拒绝，不能回传成绩');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadMsg = null;
    });
    try {
      final store = context.read<AppStore>();
      final service = PracticeService(store.api);
      final ppr = await _resolvePaperInfo();
      final upload = await service.uploadArtifacts(
        pcm: pcm is List<int> ? _asUint8(pcm) : _asUint8([]),
        spx: spx,
        xml: result.xml,
        ffmpegPath: store.ffmpegPath,
      );
      final category = (_package?.kind ?? 'read') == 'read'
          ? 'read_sentence'
          : (_package?.kind == 'dialogue' ? 'simple_expression_ufi' : 'topic');
      final params = service.buildSyncParams(
        scores: result.scores!,
        urls: upload,
        traceId: result.traceId,
        homeworkId: widget.homeworkId,
        setId: widget.setId,
        entityId: '${ppr['entityId'] ?? _stid}',
        order: ppr['order'] ?? 1,
        resourceId: widget.resourceId,
        category: category,
      );
      final sync = await service.sync(params);
      if (mounted) {
        setState(() {
          _uploadMsg = '回传成功：本题得分 ${sync.point.toStringAsFixed(2)} · 完成度 ${sync.complete.toStringAsFixed(0)}';
        });
      }
      if (widget.homeworkId.isNotEmpty) {
        final complete = '${sync.raw['is_complete_and_udpated'] ?? 0}' == '1';
        if (complete) {
          await service.finishHomework(
            homeworkId: widget.homeworkId,
            setId: widget.setId,
            resourceId: widget.resourceId,
            useTimeSeconds: 0,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _uploadMsg = '回传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static Uint8List _asUint8(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) return Uint8List.fromList(value.whereType<int>().toList());
    return Uint8List(0);
  }

  void _next(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.contents.length) return;
    final item = widget.contents[next];
    final base = '${item['__base_url'] ?? 'https://cdnsubject.ets100.com/made/'}';
    final name = '${item['url'] ?? ''}';
    final zip = name.startsWith('http')
        ? name
        : '${base.replaceFirst(RegExp(r'/*$'), '')}/${name.replaceFirst(RegExp(r'^/+'), '')}';
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PracticePage(
        stid: '${item['real_id'] ?? ''}',
        zipUrl: zip,
        title: widget.title,
        homeworkId: widget.homeworkId,
        setId: widget.setId,
        resourceId: widget.resourceId,
        contents: widget.contents,
        initialIndex: next,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surface, scheme.surfaceContainerLow, scheme.surface],
          ),
        ),
        child: EtsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(scheme),
                const SizedBox(height: 18),
                if (_error != null) ...[ErrorPanel(message: _error!, onRetry: _load), const SizedBox(height: 14)],
                if (_loading)
                  const LoadingPanel(label: '正在下载并解密 content 包…')
                else if (_package != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _contentPanel(scheme)),
                      const SizedBox(width: 18),
                      SizedBox(width: 380, child: _evalPanel(scheme)),
                    ],
                  ),
                if (_steps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _stepsPanel(scheme),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    final kindText = _package?.kind == 'read'
        ? '朗读'
        : _package?.kind == 'dialogue'
            ? '交际应答'
            : _package?.kind == 'picture'
                ? '复述 · 表达'
                : '练习';
    return Row(
      children: [
        IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(kindText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: scheme.primary)),
                ),
                const SizedBox(width: 8),
                Text('stid $_stid · 第 ${_index + 1}/${widget.contents.length} 题',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ]),
            ],
          ),
        ),
        IconButton.filledTonal(onPressed: _index > 0 ? () => _next(-1) : null, icon: const Icon(Icons.chevron_left_rounded)),
        const SizedBox(width: 6),
        IconButton.filledTonal(
            onPressed: _index + 1 < widget.contents.length ? () => _next(1) : null,
            icon: const Icon(Icons.chevron_right_rounded)),
        const SizedBox(width: 6),
        IconButton.filledTonal(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    );
  }

  Widget _contentPanel(ColorScheme scheme) {
    final package = _package!;
    final info = package.info;
    final kind = package.kind;
    final questions = info['question'] is List ? (info['question'] as List) : const [];
    return Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_audioFile != null) ...[
            _audioBar(scheme, '示范音频', _audioFile!),
            const SizedBox(height: 16),
          ],
          if (kind == 'read') ...[
            Text('参考原文', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SelectableText(ContentService.safeRichText('${info['value'] ?? ''}'),
                style: const TextStyle(fontSize: 20, height: 1.65, fontWeight: FontWeight.w700)),
          ] else if (kind == 'dialogue') ...[
            ...List.generate(questions.length, (i) {
              final q = questions[i] is Map ? (questions[i] as Map) : const {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: scheme.tertiary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                        child: Text('问句 ${i + 1}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: scheme.tertiary)),
                      ),
                      const Spacer(),
                      if (i < _askAudio.length && _askAudio[i] != null)
                        IconButton.filledTonal(
                          onPressed: () => _play(_askAudio[i]!),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    SelectableText('${q['ask'] ?? q['value'] ?? ''}',
                        style: const TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w600)),
                    if (_showAnswer && q['std'] is List) ...[
                      const SizedBox(height: 8),
                      ...(q['std'] as List).map((s) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('· ${s is Map ? s['value'] ?? '' : s}',
                                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.5)),
                          )),
                    ],
                  ],
                ),
              );
            }),
          ] else if (kind == 'picture') ...[
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(_imageFile!, fit: BoxFit.contain),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                child: const Center(child: Text('本题未提供图片资源')),
              ),
            if (info['topic'] != null) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                Chip(label: Text('话题：${info['topic']}')),
                if (info['keypoint'] != null) Chip(label: Text('${info['keypoint']}')),
              ]),
            ],
            if (_showAnswer && info['std'] is List) ...[
              const SizedBox(height: 14),
              Text('参考范文', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...(info['std'] as List).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${s is Map ? s['value'] ?? '' : s}',
                        style: const TextStyle(fontSize: 14, height: 1.7)),
                  )),
            ],
          ] else ...[
            Text('暂不支持的题型：${package.content['structure_type'] ?? '未知'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SelectableText('${package.content}', style: const TextStyle(fontSize: 11, height: 1.5)),
          ],
          const SizedBox(height: 18),
          Row(children: [
            FilterChip(
              label: const Text('显示答案'),
              selected: _showAnswer,
              onSelected: (v) => setState(() => _showAnswer = v),
              showCheckmark: false,
            ),
            const Spacer(),
            Text('content: ${package.dir.path.split(Platform.pathSeparator).last}',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ]),
        ],
      ),
    );
  }

  Widget _evalPanel(ColorScheme scheme) {
    final scores = _result?.scores;
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mic_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Text('录音评测', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (_recording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: scheme.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('${_recordSeconds}s', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 6),
          Text('16kHz · speex 106B/帧 · ISE WebSocket',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          if (_recording) ...[
            RecordingWave(active: _recording),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: _recording
                ? FilledButton.icon(
                    onPressed: _evaluating ? null : _stopAndEvaluate,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('停止并评测'),
                    style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                  )
                : FilledButton.icon(
                    onPressed: _evaluating ? null : _startRecord,
                    icon: _evaluating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.mic_rounded),
                    label: Text(_evaluating ? '评测中…' : (_result == null ? '开始录音' : '重新录音')),
                  ),
          ),
          if (_evalError != null) ...[
            const SizedBox(height: 12),
            Text(_evalError!, style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
          if (scores != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _scoreMetric('准确度', scores.accuracy, scheme.primary),
                _scoreMetric('流利度', scores.fluency, scheme.tertiary),
                _scoreMetric('完整度', scores.integrity, Colors.orange),
                _scoreMetric('总分', scores.total, Colors.green),
              ],
            ),
            if (scores.isRejected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                child: Text('评测被拒绝（except_info=${scores.exceptInfo}），请重新录音朗读。',
                    style: TextStyle(fontSize: 12, color: scheme.onErrorContainer)),
              ),
            ],
            if (scores.words.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scores.words
                    .map((w) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _wordColor(scheme, w.score).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(w.content,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _wordColor(scheme, w.score))),
                        ))
                    .toList(),
              ),
            ],
            if (!scores.isRejected) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _uploading ? null : _upload,
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_uploading ? '上传并回传中…' : '上传并回传成绩'),
                ),
              ),
              if (_uploadMsg != null) ...[
                const SizedBox(height: 8),
                Text(_uploadMsg!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03);
  }

  Color _wordColor(ColorScheme scheme, double score) {
    if (score >= 4) return Colors.green;
    if (score >= 2.5) return Colors.orange;
    return scheme.error;
  }

  Widget _scoreMetric(String label, double value, Color color) {
    return Column(
      children: [
        Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _audioBar(ColorScheme scheme, String label, File file) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(Icons.graphic_eq_rounded, color: scheme.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: () => _play(file),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('播放'),
        ),
      ]),
    );
  }

  Widget _stepsPanel(ColorScheme scheme) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('加载过程', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ..._steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(s.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 16, color: s.ok ? Colors.green : scheme.error),
                  const SizedBox(width: 8),
                  Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}
