import 'package:material_ui/material_ui.dart';

/// Material 3 / M3E 主题：标准 M3 色板 + 可选的动态方案变体。
///
/// 不再手工合成三色、不再提高对比度；所有颜色均来自 [ColorScheme.fromSeed]
/// 生成的 M3 token，保证与 Android / Material You 一致。
class M3ETheme {
  static DynamicSchemeVariant variantOf(String name) {
    return switch (name) {
      'expressive' => DynamicSchemeVariant.expressive,
      'vibrant' => DynamicSchemeVariant.vibrant,
      'fidelity' => DynamicSchemeVariant.fidelity,
      'content' => DynamicSchemeVariant.content,
      'rainbow' => DynamicSchemeVariant.rainbow,
      'fruitSalad' => DynamicSchemeVariant.fruitSalad,
      'monochrome' => DynamicSchemeVariant.monochrome,
      'neutral' => DynamicSchemeVariant.neutral,
      _ => DynamicSchemeVariant.tonalSpot,
    };
  }

  static ThemeData build({
    required Brightness brightness,
    required Color seed,
    String variantName = 'tonalSpot',
    bool glass = false,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variantOf(variantName),
      contrastLevel: 0.0,
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
      color: scheme.onSurface,
    );
    final text = base.textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      displayLarge: display.copyWith(fontSize: 57, height: 1.12, letterSpacing: -0.25),
      displayMedium: display.copyWith(fontSize: 45, height: 1.16),
      displaySmall: display.copyWith(fontSize: 36, height: 1.22),
      headlineLarge: display.copyWith(fontSize: 32, height: 1.25),
      headlineMedium: display.copyWith(fontSize: 28, height: 1.29),
      headlineSmall: display.copyWith(fontSize: 24, height: 1.33),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    return base.copyWith(
      textTheme: text,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              color: states.contains(WidgetState.selected) ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onSecondaryContainer),
        unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.linux: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.macOS: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.android: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.iOS: M3ESpringPageTransitionsBuilder(),
        TargetPlatform.fuchsia: M3ESpringPageTransitionsBuilder(),
      }),
    );
  }
}

/// M3E 弹性转场：短距离淡入 + 轻微上移，不使用夸张缩放。
class M3ESpringPageTransitionsBuilder extends PageTransitionsBuilder {
  const M3ESpringPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
