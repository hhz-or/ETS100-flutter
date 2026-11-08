import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:m3e_buttons/m3e_buttons.dart' as m3eb;
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController();
  final _deviceCode = TextEditingController();
  final _localIp = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  bool _advanced = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _deviceName.text = store.deviceName;
    _deviceCode.text = store.deviceCode;
    _localIp.text = store.localIp;
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _deviceName.dispose();
    _deviceCode.dispose();
    _localIp.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final store = context.read<AppStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.setDevice(name: _deviceName.text.trim(), code: _deviceCode.text.trim(), ip: _localIp.text.trim());
      await store.login(_phone.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tokenLogin() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用现有 token 登录'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '粘贴官方客户端当前 token（JWT，一行）'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('登录')),
        ],
      ),
    );
    if (token == null || token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!mounted) return;
      await context.read<AppStore>().useToken(token);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return Scaffold(
      body: EtsBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 700 ? 20 : 48, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(builder: (context, c) {
                final narrow = c.maxWidth < 880;
                final brand = _brandSide(scheme, store);
                final card = _loginCard(scheme, store);
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [brand, const SizedBox(height: 30), card],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: brand),
                    const SizedBox(width: 56),
                    Expanded(flex: 4, child: card),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandSide(ColorScheme scheme, AppStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: scheme.primary,
              ),
              child: Center(
                child: Text('E',
                    style: TextStyle(color: scheme.onPrimary, fontSize: 30, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('E听说', style: Theme.of(context).textTheme.headlineMedium),
                Text('ETS · FLUTTER EDITION',
                    style: TextStyle(letterSpacing: 2.4, fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic),
        const SizedBox(height: 56),
        Text('让每一次\n开口都有回响。', style: Theme.of(context).textTheme.displayMedium)
            .animate()
            .fadeIn(delay: 120.ms, duration: 600.ms)
            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            'Material 3 Expressive 打造的听说练习客户端：真实登录、作业与套卷、题库朗读、'
            '麦克风录音、speex 编码、即时评测与成绩回传。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.7),
          ),
        ).animate().fadeIn(delay: 220.ms, duration: 600.ms),
        const SizedBox(height: 40),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _featurePill(scheme, Icons.mic_rounded, '实时口语评测'),
            _featurePill(scheme, Icons.auto_awesome_rounded, 'M3 Expressive'),
            _featurePill(scheme, Icons.lock_outline_rounded, '本地凭据'),
            _featurePill(scheme, Icons.bolt_rounded, '秒级回传'),
          ],
        ).animate().fadeIn(delay: 330.ms, duration: 600.ms),
        const SizedBox(height: 46),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '非官方客户端，仅用于互操作性研究与自有账号排障；登录会与官方客户端互顶（服务端单会话）。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _featurePill(ColorScheme scheme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _loginCard(ColorScheme scheme, AppStore store) {
    return HeroCard(
      colors: [scheme.primaryContainer, scheme.secondaryContainer],
      padding: const EdgeInsets.all(34),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onPrimaryContainer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('欢迎回来', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 8),
            Text('登录你的 E 卡账号', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.75))),
            const SizedBox(height: 30),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: scheme.onPrimaryContainer),
              decoration: InputDecoration(
                labelText: '手机号',
                prefixIcon: const Icon(Icons.phone_iphone_rounded),
                fillColor: scheme.surface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              style: TextStyle(color: scheme.onPrimaryContainer),
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                fillColor: scheme.surface.withValues(alpha: 0.55),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text('设备指纹（可选，复用官方设备绑定）',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer.withValues(alpha: 0.8))),
                initiallyExpanded: _advanced,
                onExpansionChanged: (v) => _advanced = v,
                children: [
                  TextField(
                    controller: _deviceName,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                    decoration: InputDecoration(
                      labelText: 'device_name',
                      fillColor: scheme.surface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _deviceCode,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                    decoration: InputDecoration(
                      labelText: 'device_code（16 位十六进制）',
                      fillColor: scheme.surface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _localIp,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                    decoration: InputDecoration(
                      labelText: 'local_ip',
                      fillColor: scheme.surface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _login,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(_busy ? '登录中…' : '登录'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(0, 56),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: m3eb.M3ETextButton(
                onPressed: _busy ? null : _tokenLogin,
                child: Text('已有 token？直接粘贴登录',
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
            ),
            if (store.lastError != null) ...[
              const SizedBox(height: 6),
              Text(store.lastError!, style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 550.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}
