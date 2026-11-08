import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// 全局 Liquid Glass 开关。
///
/// 由设置页写入，由 [Panel]/侧边栏/顶栏等表面读取；关闭时走实色 M3E 表面，
/// 保证低端 GPU 与远程桌面也稳定。
class EtsGlass {
  EtsGlass._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static final ValueNotifier<double> strength = ValueNotifier<double>(0.6);
  static bool available = true;

  static bool get on => enabled.value && available;

  static LiquidGlassSettings settingsFor(Brightness brightness, {Color? tint}) {
    return LiquidGlassSettings(
      thickness: 10 + 26 * strength.value,
      blur: 5 + 20 * strength.value,
      chromaticAberration: 0.01 + 0.06 * strength.value,
      lightAngle: 35,
      lightIntensity: 0.42 + 0.35 * strength.value,
      saturation: 1.2 + 0.5 * strength.value,
      glassColor: (tint ?? (brightness == Brightness.dark ? Colors.white : Colors.white))
          .withValues(alpha: 0.04 + 0.12 * strength.value),
    );
  }

  /// 统一入口：glass 开启时返回液态玻璃表面，否则返回普通圆角容器。
  static Widget surface({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double radius = 32,
    Color? color,
    Border? border,
  }) {
    final brightness = Theme.of(context).brightness;
    if (!on) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: border,
        ),
        child: child,
      );
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: GlassContainer(
        useOwnLayer: true,
        settings: settingsFor(brightness, tint: Theme.of(context).colorScheme.primary),
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        padding: padding,
        clipBehavior: Clip.antiAlias,
        color: color ?? Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.32),
        child: child,
      ),
    );
  }
}
