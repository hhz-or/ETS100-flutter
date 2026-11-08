import 'dart:ui' as ui;

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// 全页 Liquid Glass 模式。
///
/// 开启后：
/// - 整个应用衬一张由当前 M3 色板生成的抽象壁纸（几何色块，不做线性渐变）；
/// - 所有内容表面（Hero、Panel、导航、顶栏、弹层）使用液态玻璃；
/// - 通过 tint + frost 保证文字可读性，而不是纯透明玻璃。
class EtsGlass {
  EtsGlass._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static final ValueNotifier<double> strength = ValueNotifier<double>(0.6);
  static bool available = true;

  static bool get on => enabled.value && available;

  static LiquidGlassSettings settingsFor(Brightness brightness, ColorScheme scheme) {
    final s = strength.value;
    return LiquidGlassSettings(
      thickness: 8 + 24 * s,
      blur: 10 + 24 * s,
      frost: 0.5 + 0.5 * s,
      frostOpacity: 1,
      chromaticAberration: 0.01 + 0.04 * s,
      lightAngle: 35,
      lightIntensity: 0.35 + 0.35 * s,
      saturation: 1.0 + 0.3 * s,
      glassColor: scheme.surface.withValues(alpha: 0.16 + 0.16 * s),
    );
  }

  /// 所有“表面”的统一入口。
  static Widget surface({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double radius = 24,
    Color? color,
    Border? border,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (!on) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius),
          border: border,
        ),
        child: child,
      );
    }
    final tint = color ?? scheme.surface.withValues(alpha: 0.68);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Stack(
        children: [
          GlassContainer(
            useOwnLayer: true,
            settings: settingsFor(Theme.of(context).brightness, scheme),
            shape: LiquidRoundedSuperellipse(borderRadius: radius),
            clipBehavior: Clip.antiAlias,
            color: tint,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? scheme.surfaceContainerHigh
                        : scheme.surface)
                    .withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(radius - 2),
              ),
              child: child,
            ),
          ),
          if (border != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: border,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 玻璃模式下的全页壁纸：由当前 M3 色板生成的几何色块，经软模糊。
class GlassWallpaper extends StatelessWidget {
  const GlassWallpaper({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: CustomPaint(
          painter: _WallpaperPainter(scheme),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.scheme);
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = scheme.surface;
    canvas.drawRect(Offset.zero & size, base);
    final shapes = <(Color, Offset, double)>[
      (scheme.surfaceContainerHighest, const Offset(0.18, 0.18), 0.46),
      (scheme.surfaceContainerHigh, const Offset(0.86, 0.24), 0.38),
      (scheme.surfaceContainer, const Offset(0.72, 0.86), 0.48),
      (scheme.primaryContainer.withValues(alpha: 0.35), const Offset(0.24, 0.82), 0.24),
      (scheme.secondaryContainer.withValues(alpha: 0.28), const Offset(0.52, 0.46), 0.30),
    ];
    for (final (color, pos, scale) in shapes) {
      canvas.drawCircle(
        Offset(size.width * pos.dx, size.height * pos.dy),
        size.shortestSide * scale,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter old) => old.scheme != scheme;
}
