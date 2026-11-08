// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'core/store.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/shell_page.dart';
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
  runApp(const EtsApp());
}

class EtsApp extends StatelessWidget {
  const EtsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStore>(
      create: (_) => AppStore()..initialize(),
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          return MaterialApp(
            title: 'E听说 · Flutter',
            debugShowCheckedModeBanner: false,
            themeMode: store.themeMode,
            theme: M3ETheme.build(brightness: Brightness.light, seed: store.seedColor, expressive: store.expressive),
            darkTheme: M3ETheme.build(brightness: Brightness.dark, seed: store.seedColor, expressive: store.expressive),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            locale: const Locale('zh', 'CN'),
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
                gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
              ),
              child: const Center(
                child: Text('E', style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800)),
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
