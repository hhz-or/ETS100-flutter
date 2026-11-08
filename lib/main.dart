// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'core/store.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/shell_page.dart';
import 'ui/glass.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1360, 900),
      minimumSize: Size(1120, 720),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'E听说 · Flutter',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  FlutterError.onError = (details) {
    try {
      final f = File('${Directory.systemTemp.path}/ets_flutter_error.log');
      f.writeAsStringSync('${DateTime.now()}\n${details.exception}\n${details.stack}\n\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    FlutterError.presentError(details);
  };
  try {
    await LiquidGlassWidgets.initialize();
  } catch (_) {
    // 某些平台/驱动不支持 fragment shader 时，玻璃模式会退化为半透明表面。
    EtsGlass.available = false;
  }
  runApp(LiquidGlassWidgets.wrap(
    child: const EtsApp(),
    brightnessResolver: Theme.maybeBrightnessOf,
  ));
}

class EtsApp extends StatelessWidget {
  const EtsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStore>(
      create: (_) => AppStore()..initialize(),
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          EtsGlass.enabled.value = store.glassEnabled;
          EtsGlass.strength.value = store.glassStrength;
          return MaterialApp(
            title: 'E听说 · Flutter',
            debugShowCheckedModeBanner: false,
            themeMode: store.themeMode,
            theme: M3ETheme.build(
              brightness: Brightness.light,
              seed: store.seedColor,
              variantName: store.schemeVariantName,
              glass: store.glassEnabled,
            ),
            darkTheme: M3ETheme.build(
              brightness: Brightness.dark,
              seed: store.seedColor,
              variantName: store.schemeVariantName,
              glass: store.glassEnabled,
            ),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            locale: const Locale('zh', 'CN'),
            builder: (context, child) => MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink()),
            home: !store.initialized
                ? const _SplashScreen()
                : (store.isLoggedIn ? const ShellPage() : const LoginPage()),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: scheme.primary,
              ),
              child: Center(
                child: Text('E',
                    style: TextStyle(color: scheme.onPrimary, fontSize: 52, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
            Text('E听说', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 10),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ],
        ),
      ),
    );
  }
}
