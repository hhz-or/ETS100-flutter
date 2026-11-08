import 'package:flutter/material.dart';

/// Material 3 / M3E（Expressive）主题：高饱和配色、超大圆角、弹性动效。
class M3ETheme {
  static ThemeData build({required Brightness brightness, required Color seed, bool expressive = true}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: expressive ? DynamicSchemeVariant.expressive : DynamicSchemeVariant.tonalSpot,
      contrastLevel: expressive ? 0.1 : 0.0,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Manrope',
    );
    final display = TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: scheme.onSurface,
    );
    return base.copyWith(
      textTheme: base.textTheme
          .apply(fontFamily: 'Manrope', bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
          .copyWith(
            displayLarge: display.copyWith(fontSize: 52, height: 1.02),
            displayMedium: display.copyWith(fontSize: 42, height: 1.05),
            displaySmall: display.copyWith(fontSize: 34, height: 1.08),
            headlineLarge: display.copyWith(fontSize: 30, letterSpacing: -0.8),
            headlineMedium: display.copyWith(fontSize: 26, letterSpacing: -0.6),
            headlineSmall: display.copyWith(fontSize: 22, letterSpacing: -0.4),
            titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
            titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.55),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.55),
            labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onPrimaryContainer),
        unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.4), thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.linux: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.macOS: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.android: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.iOS: M3ESpringPageTransitionsBuilder(),
      }),
    );
  }
}

/// M3E 式“弹性”页面转场：淡入 + 轻微上移 + 弹性缩放。
class M3ESpringPageTransitionsBuilder extends PageTransitionsBuilder {
  const M3ESpringPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }
}
